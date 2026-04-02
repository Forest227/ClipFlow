import AppKit
import Combine
import SwiftUI

@MainActor
final class AppNavigationCenter {
    static let shared = AppNavigationCenter()

    var openLibraryWindow: (() -> Void)?

    private init() {}

    func openLibrary() {
        ClipFlowRuntime.shared.openLibrary()
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            return
        }

        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let store: ClipFlowStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(store: ClipFlowStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configurePopover()
        bindStore()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.appearsDisabled = false
        updateButtonImage()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 348, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(store: store)
                .frame(width: 320)
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

        let systemName = store.capturePaused ? "pause.circle" : "paperclip.circle.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: "剪流")
            ?? NSImage(systemSymbolName: "paperclip.circle.fill", accessibilityDescription: "剪流")
        image?.isTemplate = true
        button.image = image?.withSymbolConfiguration(config)
    }

    @objc
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
