import AppKit
import Carbon
import Combine
import SwiftUI
import UniformTypeIdentifiers

private struct CapturedImagePayload {
    let data: Data
    let size: CGSize
    /// File extension for the stored image ("png" or "jpg")
    let fileExtension: String
    /// A thumbnail-sized NSImage created during capture, used for cache insertion.
    /// This avoids re-loading the full image from disk and creating a second NSImage later.
    let previewThumbnail: NSImage?
}

private extension NSImage {
    /// Maximum pixel dimension for stored images — larger images are downsampled before encoding
    static let maxStoreDimension: CGFloat = 4096

    /// Convert pasteboard image to a compressed payload while also producing a lightweight thumbnail for caching.
    /// Uses JPEG (quality 0.8) for opaque photos to reduce file size, PNG for images with alpha.
    /// Using autoreleasepool ensures intermediate representations (tiff, bitmap) are released promptly.
    func clipFlowCompressedPayload() -> CapturedImagePayload? {
        let payload: CapturedImagePayload? = autoreleasepool { () -> CapturedImagePayload? in
            guard let tiffRepresentation,
                  let originalBitmap = NSBitmapImageRep(data: tiffRepresentation) else {
                return nil
            }

            let originalPixelSize = CGSize(width: originalBitmap.pixelsWide, height: originalBitmap.pixelsHigh)
            // Capture alpha state from the original bitmap BEFORE scaling,
            // because scaled bitmaps always have hasAlpha=true regardless of source
            let originalHasAlpha = originalBitmap.hasAlpha

            // Downsample if the image exceeds the storage dimension cap
            let bitmap: NSBitmapImageRep
            let pixelSize: CGSize
            if max(originalPixelSize.width, originalPixelSize.height) > Self.maxStoreDimension {
                let scale = Self.maxStoreDimension / max(originalPixelSize.width, originalPixelSize.height)
                let targetW = Int(ceil(originalPixelSize.width * scale))
                let targetH = Int(ceil(originalPixelSize.height * scale))
                guard let scaled = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: targetW,
                    pixelsHigh: targetH,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .calibratedRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                ) else {
                    // Fallback to original if scaling fails
                    return encodeBitmap(originalBitmap, pixelSize: originalPixelSize, hasAlpha: originalHasAlpha, sourceImage: self)
                }
                scaled.size = NSSize(width: targetW, height: targetH)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaled)
                self.draw(
                    in: NSRect(origin: .zero, size: NSSize(width: targetW, height: targetH)),
                    from: NSRect(origin: .zero, size: self.size),
                    operation: .copy,
                    fraction: 1.0
                )
                NSGraphicsContext.restoreGraphicsState()
                bitmap = scaled
                pixelSize = CGSize(width: targetW, height: targetH)
            } else {
                bitmap = originalBitmap
                pixelSize = originalPixelSize
            }

            return encodeBitmap(bitmap, pixelSize: pixelSize, hasAlpha: originalHasAlpha, sourceImage: self)
        }
        return payload
    }

    /// Encode a bitmap to JPEG (if opaque) or PNG (if has alpha).
    /// Uses the original image's alpha state rather than the scaled bitmap's format,
    /// since scaled bitmaps always report hasAlpha=true regardless of source.
    private func encodeBitmap(_ bitmap: NSBitmapImageRep, pixelSize: CGSize, hasAlpha: Bool, sourceImage: NSImage) -> CapturedImagePayload? {
        // Create thumbnail at display size so the cache only holds lightweight images
        let thumbnail: NSImage
        if max(pixelSize.width, pixelSize.height) > ClipFlowThumbnail.maxDimension {
            thumbnail = ClipFlowThumbnail.downsample(sourceImage)
        } else {
            thumbnail = sourceImage
        }

        // JPEG for opaque images — typically 3-10x smaller than PNG for photos
        if !hasAlpha {
            if let jpgData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                return CapturedImagePayload(data: jpgData, size: pixelSize, fileExtension: "jpg", previewThumbnail: thumbnail)
            }
        }

        // PNG for images with alpha, or as fallback
        if let pngData = bitmap.representation(using: .png, properties: [:]) {
            return CapturedImagePayload(data: pngData, size: pixelSize, fileExtension: "png", previewThumbnail: thumbnail)
        }

        // Alpha image where PNG encoding failed — try JPEG as last resort (loses alpha)
        if let jpgData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            return CapturedImagePayload(data: jpgData, size: pixelSize, fileExtension: "jpg", previewThumbnail: thumbnail)
        }

        return nil
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
            .init(id: 4, config: store.hotKeySettings,   action: { [weak self] in self?.openSettings() })
        ])
    }

    private func observeHotKeyChanges() {
        Publishers.MergeMany(
            store.$hotKeyQuickPaste.map { _ in () },
            store.$hotKeyStatusBar.map  { _ in () },
            store.$hotKeySettings.map   { _ in () }
        )
        .dropFirst(3)
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
                fileExtension: imagePayload.fileExtension,
                sourceApp: frontmostApp?.localizedName ?? "未知应用",
                sourceBundleID: sourceBundleID,
                previewThumbnail: imagePayload.previewThumbnail
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
           let payload = image.clipFlowCompressedPayload() {
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
           let payload = image.clipFlowCompressedPayload() {
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
    private var panel: QuickPastePanel?

    init(store: ClipFlowStore, onPaste: @escaping (ClipboardItem) -> Void) {
        self.store = store
        self.onPaste = onPaste
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
        panel.hasShadow = true
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

private enum PanelTab {
    case recent
    case pinned
}

struct QuickPastePanelView: View {
    @ObservedObject var store: ClipFlowStore
    let preferredTargetName: String?
    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selectedItemID: UUID?
    @State private var inspectingItemID: UUID?
    @State private var activeTab: PanelTab = .recent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ClipFlowPalette.resolve(for: colorScheme)
        let isDark = colorScheme == .dark
        let clips = activeTab == .recent ? store.hudItems(matching: query) : store.items.filter(\.pinned)

        ZStack {
            mainContent(palette: palette, isDark: isDark, clips: clips)
                .overlay(
                    Color.black.opacity(inspectingItem == nil ? 0 : 0.35)
                )

            inspectorOverlay
        }
        .padding(ClipFlowSpacing.cardPadding)
        .frame(width: QuickPastePanelLayout.panelWidth, height: QuickPastePanelLayout.panelHeight, alignment: .topLeading)
        .onAppear {
            if selectedItemID == nil {
                selectedItemID = clips.first?.id
            }
        }
        .onChangeBackward(of: query) {
            selectedItemID = clips.first?.id
        }
        .onChangeBackward(of: activeTab) {
            query = ""
            selectedItemID = clips.first?.id
        }
        .background(
            QuickPastePanelKeyHandler(
                clips: clips,
                selectedItemID: $selectedItemID,
                onConfirm: { item in
                    onClose()
                    onPaste(item)
                }
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: QuickPastePanelLayout.cornerRadius, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: QuickPastePanelLayout.cornerRadius, style: .continuous)
                .fill(isDark ? Color(red: 0.11, green: 0.12, blue: 0.16) : Color(red: 1.0, green: 1.0, blue: 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: QuickPastePanelLayout.cornerRadius, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func mainContent(palette: ClipFlowPalette, isDark: Bool, clips: [ClipboardItem]) -> some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.md) {
            headerRow(palette: palette)

            // Tab bar
            HStack(spacing: ClipFlowSpacing.xs) {
                tabButton(title: "最近", icon: "clock", tab: .recent, palette: palette, isActive: activeTab == .recent) { activeTab = .recent }
                tabButton(title: "置顶", icon: "pin", tab: .pinned, palette: palette, isActive: activeTab == .pinned) { activeTab = .pinned }
            }

            if activeTab == .recent {
                searchBar(palette: palette, text: $query)
            }

            if clips.isEmpty {
                emptyState
            } else {
                clipList(clips: clips, isDark: isDark)
            }

            pasteButton(palette: palette, clips: clips)
        }
    }

    @ViewBuilder
    private func headerRow(palette: ClipFlowPalette) -> some View {
        HStack {
            Label("快速粘贴", systemImage: "cursorarrow.rays")
                .font(ClipFlowTypography.bodyBold)

            Spacer()

            Text("↑↓ 导航 · Enter 粘贴")
                .font(ClipFlowTypography.tinyBadge)
                .foregroundStyle(Color.secondary)

            Button("关闭", action: onClose)
                .buttonStyle(ClipFlowButtonStyle(fill: palette.secondaryButtonFill, size: .compact))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ClipFlowSpacing.sm) {
            Text(activeTab == .recent ? "还没有捕获到内容" : "还没有置顶条目")
                .font(ClipFlowTypography.sectionTitle)
            Text(activeTab == .recent
                ? "先去其他应用复制文字或图片，然后按下 Option + V，就能在指针附近把它调出来。"
                : "在最近内容中右键选择条目，点击「加入快贴」即可置顶。置顶内容不会被自动清除。")
                .font(ClipFlowTypography.caption)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, ClipFlowSpacing.sm)
    }

    @ViewBuilder
    private func clipList(clips: [ClipboardItem], isDark: Bool) -> some View {
        ScrollView {
            LazyVStack(spacing: ClipFlowSpacing.sm) {
                ForEach(clips) { item in
                    InteractiveCard(
                        content: hudRowCard(item: item, isDark: isDark),
                        onPrimary: {
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
        .scrollIndicatorsHiddenCompat()
    }

    @ViewBuilder
    private func pasteButton(palette: ClipFlowPalette, clips: [ClipboardItem]) -> some View {
        HStack(spacing: ClipFlowSpacing.sm) {
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

    @ViewBuilder
    private var inspectorOverlay: some View {
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

    private var inspectingItem: ClipboardItem? {
        guard let inspectingItemID else { return nil }
        return store.item(withID: inspectingItemID)
    }

    @ViewBuilder
    private func hudRowCard(item: ClipboardItem, isDark: Bool) -> some View {
        let innerFill: Color = isDark ? Color.white.opacity(0.045) : Color.black.opacity(0.04)
        let innerStroke: Color = isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        let outerFill: Color = isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.03)
        let innerCard = RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow, style: .continuous)
        let outerCard = RoundedRectangle(cornerRadius: ClipFlowRadius.menuRow + 2, style: .continuous)
        let row = HUDRow(item: item, store: store, isSelected: selectedItemID == item.id)

        row.padding(2)
            .background(innerCard.fill(innerFill))
            .overlay(innerCard.stroke(innerStroke, lineWidth: 1))
            .clipShape(innerCard)
            .padding(2)
            .background(outerCard.fill(outerFill))
    }

    @ViewBuilder
    private func tabButton(title: String, icon: String, tab: PanelTab, palette: ClipFlowPalette, isActive: Bool, onSelect: @escaping () -> Void) -> some View {
        Button {
            withAnimation(ClipFlowMotion.selection) {
                onSelect()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(ClipFlowTypography.smallCaptionBold)
            }
            .foregroundStyle(isActive ? .white : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? ClipCategory.quickPaste.tint : palette.inputFill)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func searchBar(palette: ClipFlowPalette, text: Binding<String>) -> some View {
        HStack(spacing: ClipFlowSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondary)

            TextField("搜索最近内容", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, ClipFlowSpacing.inputPaddingH)
        .padding(.vertical, ClipFlowSpacing.inputPaddingV)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.menuButton, style: .continuous)
                .fill(palette.inputFill)
        )
    }
}

private struct QuickPastePanelKeyHandler: NSViewRepresentable {
    let clips: [ClipboardItem]
    @Binding var selectedItemID: UUID?
    let onConfirm: (ClipboardItem) -> Void

    func makeNSView(context: Context) -> KeyCatcher {
        let view = KeyCatcher()
        view.onKeyDown = { event in
            context.coordinator.handleKey(event)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCatcher, context: Context) {
        context.coordinator.clips = clips
        context.coordinator.selectedItemID = selectedItemID
        context.coordinator.onConfirm = onConfirm
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(clips: clips, selectedItemID: $selectedItemID, onConfirm: onConfirm)
    }

    final class Coordinator {
        var clips: [ClipboardItem]
        @Binding var selectedItemID: UUID?
        var onConfirm: (ClipboardItem) -> Void

        init(clips: [ClipboardItem], selectedItemID: Binding<UUID?>, onConfirm: @escaping (ClipboardItem) -> Void) {
            self.clips = clips
            self._selectedItemID = selectedItemID
            self.onConfirm = onConfirm
        }

        func handleKey(_ event: NSEvent) {
            guard !clips.isEmpty else { return }
            let currentIndex = clips.firstIndex(where: { $0.id == selectedItemID }) ?? 0

            switch event.keyCode {
            case 126: // Up arrow
                let newIndex = max(0, currentIndex - 1)
                selectedItemID = clips[newIndex].id
            case 125: // Down arrow
                let newIndex = min(clips.count - 1, currentIndex + 1)
                selectedItemID = clips[newIndex].id
            case 36: // Enter
                if let selected = clips.first(where: { $0.id == selectedItemID }) {
                    onConfirm(selected)
                }
            default:
                break
            }
        }
    }

    final class KeyCatcher: NSView {
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
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
                    let displayText = item.isImage ? item.title : store.displaySnippet(for: item)
                    Text(displayText)
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
                        image: store.imagePreview(for: item),
                        isRevealed: store.isRevealed(item),
                        privacyColor: item.privacy.color,
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
            ClipThumbnailView(
                image: store.imagePreview(for: item),
                isRevealed: store.isRevealed(item),
                privacyColor: item.privacy.color,
                item: item,
                height: imageHeight,
                cornerRadius: ClipFlowRadius.innerCard,
                showsDimensionLabel: false,
                contentMode: .fit,
                insetPreview: true
            )
        } else {
            hudTextContent(cardWidth: cardWidth, proxyHeight: proxyHeight)
        }
    }

    @ViewBuilder
    private func hudTextContent(cardWidth: CGFloat, proxyHeight: CGFloat) -> some View {
        let textValue = store.displayFullText(for: item)
        let textFont: Font = item.kind == .code ? ClipFlowTypography.captionCode : ClipFlowTypography.body
        let lineHeight: CGFloat = item.kind == .code ? 16 : 18
        let lineCount: CGFloat = item.kind == .code ? 7 : 3
        let fixedHeight = lineHeight * lineCount

        ScrollView(.vertical, showsIndicators: false) {
            Text(textValue)
                .font(textFont)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(height: fixedHeight)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClipFlowRadius.innerCard, style: .continuous)
                .fill(Color.white.opacity(isDark ? 0.06 : 0.68))
        )
    }

    @ViewBuilder
    private var hudActions: some View {
        HStack(spacing: 10) {
            Button(item.pinned ? "取消置顶" : "置顶") {
                store.togglePin(item.id)
            }
            .buttonStyle(ClipFlowButtonStyle(fill: Color.purple.opacity(0.14), foreground: Color.purple))

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
