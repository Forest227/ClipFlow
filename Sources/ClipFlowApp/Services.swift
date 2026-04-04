import AppKit
import Carbon
import Combine
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
    private let hotKeyController = HotKeyController()
    private var cancellables = Set<AnyCancellable>()

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
        registerHotKeys()
        observeHotKeyChanges()
        store.purgeExpired()
        store.lastCaptureStatus = store.capturePaused ? "已暂停剪贴监听" : "正在监听系统剪贴板"
    }

    private func registerHotKeys() {
        hotKeyController.start(configs: [
            .init(id: 1, config: store.hotKeyQuickPaste, action: { [weak self] in self?.toggleHUD() }),
            .init(id: 2, config: store.hotKeyStatusBar,  action: { [weak self] in self?.toggleStatusBarMenu() }),
            .init(id: 3, config: store.hotKeyLibrary,    action: { [weak self] in self?.openLibrary() }),
            .init(id: 4, config: store.hotKeySettings,   action: { [weak self] in self?.openSettings() })
        ])
    }

    private func observeHotKeyChanges() {
        Publishers.MergeMany(
            store.$hotKeyQuickPaste.map { _ in () },
            store.$hotKeyStatusBar.map  { _ in () },
            store.$hotKeyLibrary.map    { _ in () },
            store.$hotKeySettings.map   { _ in () }
        )
        .dropFirst(4)
        .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
        .sink { [weak self] in self?.registerHotKeys() }
        .store(in: &cancellables)
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

    func applyAppearance(_ appearance: NSAppearance?) {
        hudController.applyAppearance(appearance)
    }

    func paste(_ item: ClipboardItem) {
        hudController.hide()
        pasteService.paste(item, preferredTarget: lastExternalApp)
    }

    func copyToClipboard(_ item: ClipboardItem) {
        pasteService.copyToClipboard(item)
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

    func toggleStatusBarMenu() {
        AppNavigationCenter.shared.toggleStatusBarMenu?()
    }

    func openSettings() {
        hudController.hide()
        AppNavigationCenter.shared.openSettingsWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func restartApplication() {
        let execURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let appURL = relaunchBundleURL()

        let process = Process()
        if let appURL {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", appURL.path]
        } else {
            process.executableURL = execURL
        }

        do {
            try process.run()
            store.lastCaptureStatus = "正在重启 ClipFlow"
            DispatchQueue.main.asyncAfter(deadline: .now() + ClipFlowMotion.relaunchDelay) {
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

        timer = Timer.scheduledTimer(withTimeInterval: ClipFlowMotion.clipboardPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        timer?.tolerance = ClipFlowMotion.clipboardPollTolerance
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

        DispatchQueue.main.asyncAfter(deadline: .now() + ClipFlowMotion.pasteActivationDelay) {
            self.sendPasteShortcut()
        }

        store.lastCaptureStatus = "已粘贴到 \(targetApp?.localizedName ?? "前台应用")"
    }

    func copyToClipboard(_ item: ClipboardItem) {
        monitor?.ignoreNextPasteboardUpdate()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard restore(item, to: pasteboard) else {
            store.lastCaptureStatus = item.isImage ? "图片资源不可用，请重新复制一次" : "复制到剪贴板失败"
            return
        }

        store.lastCaptureStatus = "已复制到剪贴板，可在目标输入框中手动粘贴"
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
    struct Entry {
        let id: UInt32
        let config: HotKeyConfig
        let action: @MainActor @Sendable () -> Void
    }

    private let hotKeySignature: OSType = 0x434C4657
    private var registrations: [(ref: EventHotKeyRef, id: UInt32)] = []
    private var eventHandler: EventHandlerRef?
    private var actions: [UInt32: @MainActor @Sendable () -> Void] = [:]

    // id mapping: 1=quickPaste, 2=statusBar, 3=library, 4=settings
    func start(configs: [Entry]) {
        stop()

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
                nil, MemoryLayout<EventHotKeyID>.size, nil,
                &hotKeyID
            )
            if status == noErr, hotKeyID.signature == controller.hotKeySignature,
               let action = controller.actions[hotKeyID.id] {
                Task { @MainActor in action() }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, userData, &eventHandler)

        for entry in configs {
            actions[entry.id] = entry.action
            let hkID = EventHotKeyID(signature: hotKeySignature, id: entry.id)
            var ref: EventHotKeyRef?
            RegisterEventHotKey(
                entry.config.keyCode,
                entry.config.modifiers,
                hkID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if let ref { registrations.append((ref: ref, id: entry.id)) }
        }
    }

    func stop() {
        for reg in registrations { UnregisterEventHotKey(reg.ref) }
        registrations.removeAll()
        actions.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit { stop() }
}

@MainActor
final class QuickPastePanelController: NSObject, NSWindowDelegate {
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
        let panel = makePanel()
        panel.appearance = store.appearanceMode.nsAppearance
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
            .preferredColorScheme(store.appearanceMode.preferredColorScheme)
        )

        configurePanelMask(panel)
        position(panel: panel, near: mouseLocation)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        guard let panel else { return }
        panel.delegate = nil
        panel.contentView = nil
        panel.orderOut(nil)
        panel.close()
        self.panel = nil
    }

    private func makePanel() -> QuickPastePanel {
        if let existing = panel {
            existing.delegate = nil
            existing.contentView = nil
            existing.orderOut(nil)
            existing.close()
            self.panel = nil
        }

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
        panel.delegate = self
        self.panel = panel
        return panel
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? QuickPastePanel === panel else { return }
        hide()
    }

    func applyAppearance(_ appearance: NSAppearance?) {
        panel?.appearance = appearance
        panel?.contentView?.needsDisplay = true
        panel?.displayIfNeeded()
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

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: colorScheme)
        let isDark = colorScheme == .dark
        let clips = store.hudItems(matching: query)

        ZStack {
            VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                HStack {
                    Label("快速粘贴", systemImage: "cursorarrow.rays")
                        .font(ClipFlowTypography.bodyBold)

                    Spacer()

                    Button("关闭", action: onClose)
                        .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill, size: .compact))
                }

                HStack(spacing: ClipFlowSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    TextField("搜索最近内容", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, ClipFlowSpacing.inputPaddingH)
                .padding(.vertical, ClipFlowSpacing.inputPaddingV)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                        .fill(palette.inputFill)
                )

                if clips.isEmpty {
                    VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
                        Text("还没有捕获到内容")
                            .font(ClipFlowTypography.sectionTitle)
                        Text("先去其他应用复制文字或图片，然后按下 Option + V，就能在指针附近把它调出来。")
                            .font(ClipFlowTypography.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, ClipFlowSpacing.sm)
                } else {
                    ScrollView {
                        LazyVStack(spacing: ClipFlowSpacing.sm) {
                            ForEach(clips) { item in
                                InteractiveCard(
                                    rootView: AnyView(
                                        HUDRow(item: item, store: store, isSelected: selectedItemID == item.id)
                                    ),
                                    onPrimary: {
                                        selectedItemID = item.id
                                    },
                                    onDoubleTap: {
                                        selectedItemID = item.id
                                        onClose()
                                        onPaste(item)
                                    },
                                    onSecondary: {
                                        selectedItemID = item.id
                                        withAnimation(ClipFlowMotion.overlay) {
                                            inspectingItemID = inspectingItemID == item.id ? nil : item.id
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                HStack(spacing: ClipFlowSpacing.sm) {
                    Button("打开主窗口") {
                        onClose()
                        onOpenLibrary()
                    }
                    .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill, size: .compact))

                    Button("粘贴选中项") {
                        if let selected = clips.first(where: { $0.id == selectedItemID }) ?? clips.first {
                            selectedItemID = selected.id
                            onClose()
                            onPaste(selected)
                        }
                    }
                    .buttonStyle(ClipFlowButtonStyle(fill: palette.primaryButtonFill, foreground: .white, size: .compact))
                }
            }
            .blur(radius: inspectingItem == nil ? 0 : ClipFlowMotion.backgroundDefocusRadius)

            if let inspectingItem {
                HUDInspectorOverlay(
                    item: inspectingItem,
                    store: store,
                    onClose: {
                        withAnimation(ClipFlowMotion.overlay) {
                            inspectingItemID = nil
                        }
                    },
                    onPaste: {
                        withAnimation(ClipFlowMotion.overlay) {
                            inspectingItemID = nil
                        }
                        onClose()
                        onPaste(inspectingItem)
                    }
                )
                .transition(ClipFlowMotion.overlayTransition)
            }
        }
        .padding(ClipFlowSpacing.cardPadding)
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
                .fill(isDark ? Color(red: 0.11, green: 0.12, blue: 0.16) : Color(red: 1.0, green: 1.0, blue: 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: QuickPastePanelLayout.cornerRadius, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.35 : 0.15), radius: 24, x: 0, y: 18)
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
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: ClipFlowRadius.badge, style: .continuous)
                    .fill(item.kind.tint.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: item.kind.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.kind.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.isImage ? item.title : store.displaySnippet(for: item))
                        .font(ClipFlowTypography.bodyBold)
                        .lineLimit(item.isImage ? 1 : 2)

                    Spacer()

                    Text(item.timeLabel)
                        .font(ClipFlowTypography.badge)
                        .foregroundStyle(Color.secondary)
                }

                if !item.isImage {
                    Text(item.title)
                        .font(ClipFlowTypography.badge)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                if item.isImage {
                    ClipThumbnailView(
                        store: store,
                        item: item,
                        height: 88,
                        cornerRadius: ClipFlowRadius.badge,
                        showsDimensionLabel: false,
                        contentMode: .fit,
                        insetPreview: true
                    )
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
                .font(ClipFlowTypography.smallCaptionBold)
                .foregroundStyle(item.kind.tint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow, style: .continuous)
                .fill(isSelected
                    ? item.kind.tint.opacity(0.18)
                    : Color.white.opacity(isDark ? 0.06 : 0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow, style: .continuous)
                .stroke(isSelected
                    ? item.kind.tint.opacity(0.42)
                    : Color.white.opacity(isDark ? 0.10 : 0.28), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 0.995 : 1)
        .animation(ClipFlowMotion.selection, value: isSelected)
    }
}

struct HUDInspectorOverlay: View {
    let item: ClipboardItem
    @ObservedObject var store: ClipFlowStore
    let onClose: () -> Void
    let onPaste: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(304, max(280, proxy.size.width - 24))

            ZStack {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                hudCard(cardWidth: cardWidth, proxyHeight: proxy.size.height)
                    .padding(ClipFlowSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func hudCard(cardWidth: CGFloat, proxyHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
            hudHeader

            hudContent(cardWidth: cardWidth, proxyHeight: proxyHeight)

            hudActions
        }
        .padding(ClipFlowSpacing.cardPadding)
        .frame(width: cardWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.hudPanel, style: .continuous)
                .fill(isDark ? Color(red: 0.11, green: 0.12, blue: 0.16) : Color(red: 0.97, green: 0.97, blue: 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClipFlowRadius.hudPanel, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.35 : 0.18), radius: 24, x: 0, y: 16)
    }

    private var hudHeader: some View {
        HStack(alignment: .top, spacing: ClipFlowSpacing.md) {
            VStack(alignment: .leading, spacing: ClipFlowSpacing.xs) {
                Text(item.title)
                    .font(ClipFlowTypography.overlayTitle)
                Text("\(item.sourceApp) · \(item.timeLabel)")
                    .font(ClipFlowTypography.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button("关闭", action: onClose)
                .buttonStyle(ClipFlowButtonStyle(fill: Color.white.opacity(isDark ? 0.10 : 0.68)))
        }
    }

    @ViewBuilder
    private func hudContent(cardWidth: CGFloat, proxyHeight: CGFloat) -> some View {
        if item.isImage {
            let imageHeight = min(196, max(156, proxyHeight * 0.24))
            VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
                ClipThumbnailView(
                    store: store,
                    item: item,
                    height: imageHeight,
                    cornerRadius: ClipFlowRadius.innerCard,
                    showsDimensionLabel: false,
                    contentMode: .fit,
                    insetPreview: true
                )
                FlexiblePillRow(items: item.labels, tint: item.kind.tint)
            }
        } else {
            hudTextContent(cardWidth: cardWidth, proxyHeight: proxyHeight)
        }
    }

    @ViewBuilder
    private func hudTextContent(cardWidth: CGFloat, proxyHeight: CGFloat) -> some View {
        let textContentMaxHeight = min(220, max(110, proxyHeight * 0.34))
        let textValue = store.displayFullText(for: item)
        let textBoxWidth = max(220, cardWidth - 28)
        let estimatedHeight = estimatedTextBoxHeight(for: textValue, width: textBoxWidth)
        let shouldScroll = estimatedHeight > textContentMaxHeight
        let textFont: Font = item.kind == .code ? ClipFlowTypography.captionCode : ClipFlowTypography.body

        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
            if shouldScroll {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(textValue)
                        .font(textFont)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: textContentMaxHeight)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                        .fill(Color.white.opacity(isDark ? 0.06 : 0.68))
                )
            } else {
                Text(textValue)
                    .font(textFont)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                            .fill(Color.white.opacity(isDark ? 0.06 : 0.68))
                    )
            }
            FlexiblePillRow(items: item.labels, tint: item.kind.tint)
        }
    }

    @ViewBuilder
    private var hudActions: some View {
        HStack(spacing: 10) {
            if item.privacy != .standard {
                Button(store.isRevealed(item) ? "隐藏内容" : "显示内容") {
                    store.toggleReveal(item.id)
                }
                .buttonStyle(ClipFlowButtonStyle(fill: item.kind.tint.opacity(0.14), foreground: item.kind.tint))
            }

            if let linkURL = item.primaryURL {
                Button("访问链接") {
                    NSWorkspace.shared.open(linkURL)
                }
                .buttonStyle(ClipFlowButtonStyle(fill: ClipCategory.links.tint.opacity(0.14), foreground: ClipCategory.links.tint))
            }

            Button("粘贴这项", action: onPaste)
                .buttonStyle(ClipFlowButtonStyle(fill: Color(red: 0.30, green: 0.59, blue: 0.92), foreground: .white))
        }
    }

    private func estimatedTextBoxHeight(for text: String, width: CGFloat) -> CGFloat {
        let font: NSFont = item.kind == .code
            ? .monospacedSystemFont(ofSize: 12, weight: .medium)
            : .systemFont(ofSize: 13, weight: .medium)

        let rect = (text as NSString).boundingRect(
            with: CGSize(width: max(160, width - 20), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )

        return ceil(rect.height) + 20
    }
}
