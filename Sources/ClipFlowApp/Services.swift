import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

private struct CapturedImagePayload {
    let data: Data
    let size: CGSize
}

private extension NSImage {
    func clipFlowPNGPayload() -> CapturedImagePayload? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let size = CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        return CapturedImagePayload(data: pngData, size: size)
    }
}

private enum QuickPastePanelLayout {
    static let panelWidth: CGFloat = 368
    static let panelHeight: CGFloat = 560
}

@MainActor
final class ClipFlowRuntime: NSObject {
    static let shared = ClipFlowRuntime()

    let store = ClipFlowStore.shared

    private let clipboardMonitor: ClipboardMonitor
    private let pasteService: PasteService
    private lazy var hudController = QuickPastePanelController(store: store) { [weak self] item in
        self?.paste(item)
    } onOpenLibrary: { [weak self] in
        self?.openLibrary()
    }
    private lazy var hotKeyController = HotKeyController { [weak self] in
        self?.toggleHUD()
    }

    private var appActivationObserver: NSObjectProtocol?
    private var started = false
    private var lastExternalApp: NSRunningApplication?

    override private init() {
        clipboardMonitor = ClipboardMonitor(store: store)
        pasteService = PasteService(store: store)
        super.init()
        pasteService.monitor = clipboardMonitor
    }

    func start() {
        guard !started else { return }
        started = true

        observeFrontmostApp()
        clipboardMonitor.start()
        hotKeyController.start()
        store.purgeExpired()
        store.lastCaptureStatus = store.capturePaused ? "已暂停剪贴监听" : "正在监听系统剪贴板"
    }

    func toggleHUD() {
        hudController.toggle(anchorAt: NSEvent.mouseLocation, preferredTarget: lastExternalApp)
    }

    func showHUD() {
        hudController.show(anchorAt: NSEvent.mouseLocation, preferredTarget: lastExternalApp)
    }

    func hideHUD() {
        hudController.hide()
    }

    func paste(_ item: ClipboardItem) {
        hudController.hide()
        pasteService.paste(item, preferredTarget: lastExternalApp)
    }

    func openLibrary() {
        NSApp.activate(ignoringOtherApps: true)

        if let libraryWindow = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            libraryWindow.makeKeyAndOrderFront(nil)
        }
    }

    func restartApplication() {
        guard let appURL = relaunchBundleURL() else {
            store.lastCaptureStatus = "无法定位应用包，暂时不能重启"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appURL.path]

        do {
            try process.run()
            store.lastCaptureStatus = "正在重启 ClipFlow"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NSApp.terminate(nil)
            }
        } catch {
            store.lastCaptureStatus = "重启失败，请稍后再试"
        }
    }

    private func observeFrontmostApp() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else {
                return
            }

            Task { @MainActor [weak self] in
                if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    self?.lastExternalApp = app
                }
            }
        }
    }

    private func relaunchBundleURL() -> URL? {
        let candidates = [Bundle.main.bundleURL, Bundle.main.executableURL].compactMap { $0 }

        for candidate in candidates {
            let path = candidate.path

            if path.hasSuffix(".app") {
                return candidate
            }

            if let range = path.range(of: ".app/") {
                return URL(fileURLWithPath: "\(path[..<range.lowerBound]).app")
            }
        }

        return nil
    }
}

@MainActor
final class ClipboardMonitor {
    private let store: ClipFlowStore
    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressNextCapture = false

    init(store: ClipFlowStore) {
        self.store = store
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func ignoreNextPasteboardUpdate() {
        suppressNextCapture = true
    }

    private func poll() {
        if store.capturePaused {
            lastChangeCount = pasteboard.changeCount
            return
        }

        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if suppressNextCapture {
            suppressNextCapture = false
            return
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let sourceBundleID = frontmostApp?.bundleIdentifier

        if sourceBundleID == Bundle.main.bundleIdentifier || store.isExcluded(bundleID: sourceBundleID) {
            return
        }

        if let imagePayload = imagePayloadFromPasteboard() {
            store.ingestCopiedImage(
                imagePayload.data,
                size: imagePayload.size,
                sourceApp: frontmostApp?.localizedName ?? "未知应用",
                sourceBundleID: sourceBundleID
            )
            return
        }

        guard let text = pasteboard.string(forType: .string) else { return }

        store.ingestCopiedText(
            text,
            sourceApp: frontmostApp?.localizedName ?? "未知应用",
            sourceBundleID: sourceBundleID
        )
    }

    private func imagePayloadFromPasteboard() -> CapturedImagePayload? {
        if let image = NSImage(pasteboard: pasteboard),
           let payload = image.clipFlowPNGPayload() {
            return payload
        }

        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL],
           fileURLs.count == 1,
           let fileURL = fileURLs.first,
           let type = UTType(filenameExtension: fileURL.pathExtension),
           type.conforms(to: .image),
           let image = NSImage(contentsOf: fileURL),
           let payload = image.clipFlowPNGPayload() {
            return payload
        }

        return nil
    }
}

@MainActor
final class PasteService {
    private let store: ClipFlowStore
    weak var monitor: ClipboardMonitor?

    init(store: ClipFlowStore) {
        self.store = store
    }

    func paste(_ item: ClipboardItem, preferredTarget: NSRunningApplication?) {
        monitor?.ignoreNextPasteboardUpdate()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard restore(item, to: pasteboard) else {
            store.lastCaptureStatus = item.isImage ? "图片资源不可用，请重新复制一次" : "恢复剪贴内容失败"
            return
        }

        let targetApp = preferredTarget ?? NSWorkspace.shared.frontmostApplication
        targetApp?.activate(options: [.activateAllWindows])

        guard requestAccessibilityIfNeeded() else {
            store.lastCaptureStatus = "已复制回剪贴板。请在系统设置中允许 ClipFlow 使用辅助功能后再试。"
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.sendPasteShortcut()
        }

        store.lastCaptureStatus = "已粘贴到 \(targetApp?.localizedName ?? "前台应用")"
    }

    private func restore(_ item: ClipboardItem, to pasteboard: NSPasteboard) -> Bool {
        if item.isImage {
            guard let imageData = store.imageData(for: item),
                  let image = NSImage(data: imageData) else {
                return false
            }

            if pasteboard.writeObjects([image]) {
                return true
            }

            return pasteboard.setData(imageData, forType: .png)
        }

        return pasteboard.setString(item.fullText, forType: .string)
    }

    private func requestAccessibilityIfNeeded() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func sendPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeV: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

final class HotKeyController {
    private let action: @MainActor () -> Void
    private let hotKeySignature: OSType = 0x434C4657
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func start() {
        guard hotKeyRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()

        let handler: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }

            let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr, hotKeyID.signature == controller.hotKeySignature {
                let action = controller.action
                Task { @MainActor in
                    action()
                }
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            userData,
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

@MainActor
final class QuickPastePanelController {
    private let store: ClipFlowStore
    private let onPaste: (ClipboardItem) -> Void
    private let onOpenLibrary: () -> Void
    private var panel: QuickPastePanel?

    init(store: ClipFlowStore, onPaste: @escaping (ClipboardItem) -> Void, onOpenLibrary: @escaping () -> Void) {
        self.store = store
        self.onPaste = onPaste
        self.onOpenLibrary = onOpenLibrary
    }

    func toggle(anchorAt mouseLocation: CGPoint, preferredTarget: NSRunningApplication?) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(anchorAt: mouseLocation, preferredTarget: preferredTarget)
        }
    }

    func show(anchorAt mouseLocation: CGPoint, preferredTarget: NSRunningApplication?) {
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(
            rootView: QuickPastePanelView(
                store: store,
                preferredTargetName: preferredTarget?.localizedName,
                onPaste: onPaste,
                onOpenLibrary: onOpenLibrary,
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        )

        position(panel: panel, near: mouseLocation)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> QuickPastePanel {
        let panel = QuickPastePanel(
            contentRect: NSRect(x: 0, y: 0, width: QuickPastePanelLayout.panelWidth, height: QuickPastePanelLayout.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func position(panel: NSPanel, near mouseLocation: CGPoint) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 120, y: 120, width: 1200, height: 800)
        let panelSize = panel.frame.size

        var origin = CGPoint(
            x: mouseLocation.x + 18,
            y: mouseLocation.y - panelSize.height - 18
        )

        if origin.x + panelSize.width > visibleFrame.maxX - 12 {
            origin.x = mouseLocation.x - panelSize.width - 18
        }

        if origin.y < visibleFrame.minY + 12 {
            origin.y = mouseLocation.y + 18
        }

        panel.setFrameOrigin(origin)
    }
}

final class QuickPastePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct QuickPastePanelView: View {
    @ObservedObject var store: ClipFlowStore
    let preferredTargetName: String?
    let onPaste: (ClipboardItem) -> Void
    let onOpenLibrary: () -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selectedItemID: UUID?

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: .light)
        let clips = store.hudItems(matching: query)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("快速粘贴", systemImage: "cursorarrow.rays")
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                Spacer()

                Button("关闭", action: onClose)
                    .buttonStyle(ClipButtonStyle(fill: palette.secondaryButtonFill))
            }

            Text(preferredTargetName.map { "准备粘贴到 \($0)" } ?? "将内容粘贴回你刚才使用的应用")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)

            Text("最多显示最近 10 条可粘贴内容")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.82))

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)

                TextField("搜索最近内容", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.inputFill)
            )

            if clips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有捕获到内容")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("先去其他应用复制文字或图片，然后按下 Option + V，就能在指针附近把它调出来。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(clips) { item in
                            HUDRow(
                                item: item,
                                store: store,
                                isSelected: selectedItemID == item.id
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture {
                                selectedItemID = item.id
                            }
                            .onTapGesture(count: 2) {
                                selectedItemID = item.id
                                onPaste(item)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("打开主窗口", action: onOpenLibrary)
                    .buttonStyle(ClipButtonStyle(fill: palette.secondaryButtonFill))

                Button("粘贴选中项") {
                    if let selected = clips.first(where: { $0.id == selectedItemID }) ?? clips.first {
                        selectedItemID = selected.id
                        onPaste(selected)
                    }
                }
                .buttonStyle(ClipButtonStyle(fill: palette.primaryButtonFill, foreground: .white))
            }
        }
        .padding(18)
        .frame(width: QuickPastePanelLayout.panelWidth, height: QuickPastePanelLayout.panelHeight, alignment: .topLeading)
        .onAppear {
            if selectedItemID == nil {
                selectedItemID = clips.first?.id
            }
        }
        .onChange(of: query) { _, _ in
            selectedItemID = clips.first?.id
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 28, x: 0, y: 20)
    }
}

struct HUDRow: View {
    let item: ClipboardItem
    let store: ClipFlowStore
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.isImage {
                ClipThumbnailView(store: store, item: item, height: 64, cornerRadius: 14, showsDimensionLabel: false)
                    .frame(width: 64, height: 64)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Spacer()

                    Text(item.timeLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                Text(store.displaySnippet(for: item))
                    .font(.system(size: item.kind == .code ? 11 : 12, weight: .medium, design: item.kind == .code ? .monospaced : .rounded))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(item.sourceApp)
                    if item.pinned {
                        Text("已置顶")
                    }
                    if item.privacy != .standard {
                        Text(item.privacy.label)
                    }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? tint.opacity(0.18) : Color.white.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.42) : Color.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch item.kind {
        case .text: ClipCategory.all.tint
        case .code: ClipCategory.code.tint
        case .link: ClipCategory.links.tint
        case .secret: ClipCategory.protected.tint
        case .image: ClipCategory.smartStacks.tint
        }
    }

    private var iconName: String {
        switch item.kind {
        case .text: "text.alignleft"
        case .code: "terminal"
        case .link: "link"
        case .secret: "lock.fill"
        case .image: "photo"
        }
    }
}
