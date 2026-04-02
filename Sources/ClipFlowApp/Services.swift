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
    static let panelWidth: CGFloat = 352
    static let panelHeight: CGFloat = 520
    static let cornerRadius: CGFloat = 24
    static let anchorOffset: CGFloat = 18
    static let screenInset: CGFloat = 12
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
        hudController.hide()
        AppNavigationCenter.shared.openLibraryWindow?()
        NSApp.activate(ignoringOtherApps: true)

        if let libraryWindow = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            libraryWindow.makeKeyAndOrderFront(nil)
        } else {
            DispatchQueue.main.async {
                NSApp.windows
                    .first(where: { !($0 is NSPanel) })?
                    .makeKeyAndOrderFront(nil)
            }
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

        configurePanelMask(panel)
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
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func configurePanelMask(_ panel: QuickPastePanel) {
        let radius = QuickPastePanelLayout.cornerRadius
        let views: [NSView] = [panel.contentView, panel.contentView?.superview].compactMap { $0 }

        for view in views {
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
            view.layer?.cornerRadius = radius
            view.layer?.masksToBounds = true
            if #available(macOS 10.15, *) {
                view.layer?.cornerCurve = .continuous
            }
        }
    }

    private func position(panel: NSPanel, near mouseLocation: CGPoint) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 120, y: 120, width: 1200, height: 800)
        let panelSize = panel.frame.size
        let offset = QuickPastePanelLayout.anchorOffset
        let inset = QuickPastePanelLayout.screenInset

        let candidateOrigins: [CGPoint] = [
            CGPoint(x: mouseLocation.x + offset, y: mouseLocation.y - panelSize.height - offset),
            CGPoint(x: mouseLocation.x - panelSize.width - offset, y: mouseLocation.y - panelSize.height - offset),
            CGPoint(x: mouseLocation.x + offset, y: mouseLocation.y + offset),
            CGPoint(x: mouseLocation.x - panelSize.width - offset, y: mouseLocation.y + offset)
        ]

        let bestOrigin = candidateOrigins.min { lhs, rhs in
            placementScore(for: lhs, panelSize: panelSize, mouseLocation: mouseLocation, visibleFrame: visibleFrame, inset: inset)
                < placementScore(for: rhs, panelSize: panelSize, mouseLocation: mouseLocation, visibleFrame: visibleFrame, inset: inset)
        } ?? candidateOrigins[0]

        let clampedOrigin = clamp(
            origin: bestOrigin,
            panelSize: panelSize,
            to: visibleFrame.insetBy(dx: inset, dy: inset)
        )

        panel.setFrameOrigin(clampedOrigin)
    }

    private func placementScore(
        for origin: CGPoint,
        panelSize: CGSize,
        mouseLocation: CGPoint,
        visibleFrame: CGRect,
        inset: CGFloat
    ) -> CGFloat {
        let safeFrame = visibleFrame.insetBy(dx: inset, dy: inset)
        let clampedOrigin = clamp(origin: origin, panelSize: panelSize, to: safeFrame)

        let overflowX = abs(origin.x - clampedOrigin.x)
        let overflowY = abs(origin.y - clampedOrigin.y)
        let overflowPenalty = (overflowX + overflowY) * 20

        let panelCenter = CGPoint(
            x: clampedOrigin.x + panelSize.width / 2,
            y: clampedOrigin.y + panelSize.height / 2
        )
        let distancePenalty = hypot(panelCenter.x - mouseLocation.x, panelCenter.y - mouseLocation.y)

        return overflowPenalty + distancePenalty
    }

    private func clamp(origin: CGPoint, panelSize: CGSize, to frame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, frame.minX), max(frame.minX, frame.maxX - panelSize.width)),
            y: min(max(origin.y, frame.minY), max(frame.minY, frame.maxY - panelSize.height))
        )
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
    @State private var inspectingItemID: UUID?

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: .light)
        let clips = store.hudItems(matching: query)

        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("快速粘贴", systemImage: "cursorarrow.rays")
                        .font(.system(size: 13, weight: .bold, design: .rounded))

                    Spacer()

                    Button("关闭", action: onClose)
                        .buttonStyle(HUDCompactButtonStyle(fill: palette.secondaryButtonFill))
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    TextField("搜索最近内容", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.inputFill)
                )

                if clips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("还没有捕获到内容")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("先去其他应用复制文字或图片，然后按下 Option + V，就能在指针附近把它调出来。")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(clips) { item in
                                HUDInteractiveRow(
                                    item: item,
                                    store: store,
                                    isSelected: selectedItemID == item.id,
                                    onSelect: {
                                        selectedItemID = item.id
                                    },
                                    onPaste: {
                                        selectedItemID = item.id
                                        onClose()
                                        onPaste(item)
                                    },
                                    onInspect: {
                                        selectedItemID = item.id
                                        inspectingItemID = inspectingItemID == item.id ? nil : item.id
                                    }
                                )
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                HStack(spacing: 8) {
                    Button("打开主窗口") {
                        onClose()
                        onOpenLibrary()
                    }
                    .buttonStyle(HUDCompactButtonStyle(fill: palette.secondaryButtonFill))

                    Button("粘贴选中项") {
                        if let selected = clips.first(where: { $0.id == selectedItemID }) ?? clips.first {
                            selectedItemID = selected.id
                            onClose()
                            onPaste(selected)
                        }
                    }
                    .buttonStyle(HUDCompactButtonStyle(fill: palette.primaryButtonFill, foreground: .white))
                }
            }
            .blur(radius: inspectingItem == nil ? 0 : 2)

            if let inspectingItem {
                HUDInspectorOverlay(
                    item: inspectingItem,
                    store: store,
                    onClose: { inspectingItemID = nil },
                    onPaste: {
                        inspectingItemID = nil
                        onClose()
                        onPaste(inspectingItem)
                    }
                )
            }
        }
        .padding(14)
        .frame(width: QuickPastePanelLayout.panelWidth, height: QuickPastePanelLayout.panelHeight, alignment: .topLeading)
        .onAppear {
            if selectedItemID == nil {
                selectedItemID = clips.first?.id
            }
        }
        .onChange(of: query) { _, _ in
            selectedItemID = clips.first?.id
        }
        .clipShape(RoundedRectangle(cornerRadius: QuickPastePanelLayout.cornerRadius, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: QuickPastePanelLayout.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: QuickPastePanelLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 18)
    }

    private var inspectingItem: ClipboardItem? {
        guard let inspectingItemID else { return nil }
        return store.item(withID: inspectingItemID)
    }
}

struct HUDRow: View {
    let item: ClipboardItem
    let store: ClipFlowStore
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Spacer()

                    Text(item.timeLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                if item.isImage {
                    ClipThumbnailView(
                        store: store,
                        item: item,
                        height: 88,
                        cornerRadius: 12,
                        showsDimensionLabel: false,
                        contentMode: .fit,
                        insetPreview: true
                    )
                } else {
                    Text(store.displaySnippet(for: item))
                        .font(.system(size: item.kind == .code ? 10 : 11, weight: .medium, design: item.kind == .code ? .monospaced : .rounded))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 5) {
                    Text(item.sourceApp)
                    if item.pinned {
                        Text("已置顶")
                    }
                    if item.privacy != .standard {
                        Text(item.privacy.label)
                    }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? tint.opacity(0.18) : Color.white.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
        case .image: "photo.stack.fill"
        }
    }
}

struct HUDCompactButtonStyle: ButtonStyle {
    let fill: Color
    var foreground: Color = Color.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.75 : 1))
            )
    }
}

struct HUDInteractiveRow: NSViewRepresentable {
    let item: ClipboardItem
    let store: ClipFlowStore
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onInspect: () -> Void

    func makeNSView(context: Context) -> HUDInteractiveHostingView {
        let view = HUDInteractiveHostingView()
        view.update(
            rootView: AnyView(
                HUDRow(
                    item: item,
                    store: store,
                    isSelected: isSelected
                )
            ),
            onSelect: onSelect,
            onPaste: onPaste,
            onInspect: onInspect
        )
        return view
    }

    func updateNSView(_ nsView: HUDInteractiveHostingView, context: Context) {
        nsView.update(
            rootView: AnyView(
                HUDRow(
                    item: item,
                    store: store,
                    isSelected: isSelected
                )
            ),
            onSelect: onSelect,
            onPaste: onPaste,
            onInspect: onInspect
        )
    }
}

final class HUDInteractiveHostingView: NSView {
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var onSelect: () -> Void = {}
    private var onPaste: () -> Void = {}
    private var onInspect: () -> Void = {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        rootView: AnyView,
        onSelect: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onInspect: @escaping () -> Void
    ) {
        hostingView.rootView = rootView
        self.onSelect = onSelect
        self.onPaste = onPaste
        self.onInspect = onInspect
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            onPaste()
        } else {
            onSelect()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onInspect()
    }

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 {
            onInspect()
        } else {
            super.otherMouseDown(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        onInspect()
        return nil
    }
}

struct HUDInspectorOverlay: View {
    let item: ClipboardItem
    @ObservedObject var store: ClipFlowStore
    let onClose: () -> Void
    let onPaste: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("\(item.sourceApp) · \(item.timeLabel)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Button("关闭", action: onClose)
                        .buttonStyle(ClipButtonStyle(fill: Color.white.opacity(0.68)))
                }

                if item.isImage, let imageData = store.imageData(for: item), let image = NSImage(data: imageData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                ScrollView {
                    Text(store.displayFullText(for: item))
                        .font(.system(size: item.kind == .code ? 12 : 13, weight: .medium, design: item.kind == .code ? .monospaced : .rounded))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.68))
                )

                FlexiblePillRow(items: item.labels, tint: tint)

                HStack(spacing: 10) {
                    if item.privacy != .standard {
                        Button(store.isRevealed(item) ? "隐藏内容" : "显示内容") {
                            store.toggleReveal(item.id)
                        }
                        .buttonStyle(ClipButtonStyle(fill: tint.opacity(0.14), foreground: tint))
                    }

                    if let linkURL = item.primaryURL {
                        Button("访问链接") {
                            NSWorkspace.shared.open(linkURL)
                        }
                        .buttonStyle(ClipButtonStyle(fill: ClipCategory.links.tint.opacity(0.14), foreground: ClipCategory.links.tint))
                    }

                    Button("粘贴这项", action: onPaste)
                        .buttonStyle(ClipButtonStyle(fill: Color(red: 0.30, green: 0.59, blue: 0.92), foreground: .white))
                }
            }
            .padding(16)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 16)
            .padding(12)
        }
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
}
