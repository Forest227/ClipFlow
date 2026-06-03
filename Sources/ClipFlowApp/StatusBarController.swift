import AppKit
import Combine
import CoreText
import SwiftUI

@MainActor
final class AppNavigationCenter {
    static let shared = AppNavigationCenter()

    var openLibraryWindow: (() -> Void)?
    var openSettingsWindow: (() -> Void)?
    var toggleStatusBarMenu: (() -> Void)?
    var openLibraryKeepingPopover: (() -> Void)?
    var openSettingsKeepingPopover: (() -> Void)?

    private init() {}

    func openLibrary() {
        ClipFlowRuntime.shared.openLibrary()
    }

    func openSettings() {
        if let openSettingsWindow {
            openSettingsWindow()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            return
        }

        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let store: ClipFlowStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    init(store: ClipFlowStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusItem()
        configurePopover()
        bindStore()
        AppNavigationCenter.shared.toggleStatusBarMenu = { [weak self] in
            self?.togglePopoverViaHotKey()
        }
        AppNavigationCenter.shared.openLibraryKeepingPopover = { [weak self] in
            (self as StatusBarController?)?.openLibraryKeepingPopover()
        }
        AppNavigationCenter.shared.openSettingsKeepingPopover = { [weak self] in
            (self as StatusBarController?)?.openSettingsKeepingPopover()
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseDown, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.appearsDisabled = false
        updateButtonImage()
    }

    private func configurePopover() {
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.delegate = self
        popover.contentSize = NSSize(width: 348, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: PopoverRoot(store: store)
        )
    }

    private func bindStore() {
        store.$capturePaused
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateButtonImage()
            }
            .store(in: &cancellables)
    }

    private func updateButtonImage() {
        guard let button = statusItem.button else { return }

        button.image = ClipFlowStatusBarIcon.make(paused: store.capturePaused)
    }

    func applyAppearance(_ appearance: NSAppearance?) {
        popover.appearance = appearance
        popover.contentViewController?.view.window?.appearance = appearance
        popover.contentViewController?.view.needsDisplay = true
        popover.contentViewController?.view.window?.displayIfNeeded()
    }

    @objc
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            sender.isHighlighted = true
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            startPopoverEventMonitors()
        }
    }

    func togglePopoverViaHotKey() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            button.isHighlighted = true
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startPopoverEventMonitors()
        }
    }

    func openLibraryKeepingPopover() {
        stopPopoverEventMonitors()
        AppNavigationCenter.shared.openLibraryWindow?()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.startPopoverEventMonitors()
        }
    }

    func openSettingsKeepingPopover() {
        stopPopoverEventMonitors()
        AppNavigationCenter.shared.openSettingsWindow?()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.startPopoverEventMonitors()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.isHighlighted = false
        stopPopoverEventMonitors()
    }

    private func startPopoverEventMonitors() {
        stopPopoverEventMonitors()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            guard self.popover.isShown else { return event }

            if self.eventTargetsPopoverOrStatusButton(event) {
                return event
            }

            self.popover.performClose(nil)
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            guard self.popover.isShown else { return }
            self.popover.performClose(nil)
        }
    }

    private func stopPopoverEventMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func eventTargetsPopoverOrStatusButton(_ event: NSEvent) -> Bool {
        if let popoverWindow = popover.contentViewController?.view.window,
           event.window === popoverWindow {
            return true
        }

        if let button = statusItem.button,
           let buttonWindow = button.window,
           event.window === buttonWindow {
            let pointInButton = button.convert(event.locationInWindow, from: nil)
            return button.bounds.contains(pointInButton)
        }

        return false
    }
}

private struct PopoverRoot: View {
    @ObservedObject var store: ClipFlowStore
    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color {
        colorScheme == .light
            ? Color(red: 0.94, green: 0.94, blue: 0.95)
            : Color(red: 0.11, green: 0.12, blue: 0.16)
    }

    var body: some View {
        MenuBarView(store: store)
            .frame(width: 320)
            .preferredColorScheme(store.appearanceMode.preferredColorScheme)
            .background(bgColor)
    }
}

private enum ClipFlowStatusBarIcon {
    static func make(paused: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            image.isTemplate = true
            return image
        }

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setFillColor(NSColor.white.cgColor)

        if let path = makeCPath(in: CGRect(origin: .zero, size: size), paused: paused) {
            context.addPath(path)
            context.fillPath()
        }

        if paused {
            drawPauseBars(in: context)
        }

        image.unlockFocus()
        image.isTemplate = false
        image.size = size
        return image
    }

    private static func makeCPath(in rect: CGRect, paused: Bool) -> CGPath? {
        guard let basePath = glyphPath() else { return nil }

        let targetWidth: CGFloat = paused ? 12.4 : 13.2
        let targetHeight: CGFloat = 13.8
        let bounds = basePath.boundingBox
        let scale = min(targetWidth / bounds.width, targetHeight / bounds.height)

        var transform = CGAffineTransform(scaleX: scale, y: scale)
        guard let scaledPath = basePath.copy(using: &transform) else { return nil }

        let scaledBounds = scaledPath.boundingBox
        let center = CGPoint(x: rect.midX - 0.15, y: rect.midY + 0.05)
        transform = CGAffineTransform(
            translationX: center.x - scaledBounds.midX - (paused ? 0.45 : 0.0),
            y: center.y - scaledBounds.midY
        )

        return scaledPath.copy(using: &transform)
    }

    private static func drawPauseBars(in context: CGContext) {
        let barColor = NSColor.black.cgColor
        let leftBar = CGPath(
            roundedRect: CGRect(x: 10.35, y: 5.0, width: 1.55, height: 7.9),
            cornerWidth: 0.78,
            cornerHeight: 0.78,
            transform: nil
        )
        let rightBar = CGPath(
            roundedRect: CGRect(x: 12.55, y: 5.0, width: 1.55, height: 7.9),
            cornerWidth: 0.78,
            cornerHeight: 0.78,
            transform: nil
        )

        context.saveGState()
        context.setFillColor(barColor)
        context.addPath(leftBar)
        context.addPath(rightBar)
        context.fillPath()
        context.restoreGState()
    }

    private static func glyphPath() -> CGPath? {
        let font = preferredFont(size: 17)
        let ctFont = font as CTFont

        guard let scalar = Character("C").unicodeScalars.first else { return nil }
        var character = UniChar(scalar.value)
        var glyph = CGGlyph()

        guard CTFontGetGlyphsForCharacters(ctFont, &character, &glyph, 1) else {
            return nil
        }

        return CTFontCreatePathForGlyph(ctFont, glyph, nil)
    }

    private static func preferredFont(size: CGFloat) -> NSFont {
        let names = [
            "Avenir-Heavy",
            "AvenirNext-Heavy",
            "Avenir-Black"
        ]

        for name in names {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }

        return NSFont.systemFont(ofSize: size, weight: .heavy)
    }
}
