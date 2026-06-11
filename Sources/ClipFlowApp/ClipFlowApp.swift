import AppKit
import Combine
import SwiftUI

@main
struct ClipFlowApp: App {
    @NSApplicationDelegateAdaptor(ClipFlowAppDelegate.self) private var appDelegate
    @StateObject private var store = ClipFlowStore.shared

    var body: some Scene {
        Settings {
            SettingsView(store: store)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .preferredColorScheme(store.appearanceMode.preferredColorScheme)
        }
    }
}

@MainActor
final class ClipFlowAppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var cancellables = Set<AnyCancellable>()
    private lazy var settingsWindowController = SettingsWindowController(
        store: ClipFlowStore.shared,
        locale: Locale(identifier: "zh-Hans")
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipFlowRuntime.shared.start()
        statusBarController = StatusBarController(store: ClipFlowStore.shared)
        bindAppearanceMode()
        bindActivationPolicy()
        AppNavigationCenter.shared.openSettingsWindow = { [weak self] in
            self?.showSettingsWindow()
        }
    }

    @MainActor
    private func showSettingsWindow() {
        settingsWindowController.showAndActivate()
    }

    private func bindAppearanceMode() {
        applyAppearance(ClipFlowStore.shared.appearanceMode)

        ClipFlowStore.shared.$appearanceMode
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.applyAppearance(mode)
            }
            .store(in: &cancellables)
    }

    private func bindActivationPolicy() {
        applyActivationPolicy(hideDockIcon: ClipFlowStore.shared.hideDockIcon)

        ClipFlowStore.shared.$hideDockIcon
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] hideDockIcon in
                self?.applyActivationPolicy(hideDockIcon: hideDockIcon)
            }
            .store(in: &cancellables)
    }

    private func applyActivationPolicy(hideDockIcon: Bool) {
        let policy: NSApplication.ActivationPolicy = hideDockIcon ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        let appearance = mode.nsAppearance
        NSApp.appearance = appearance
        settingsWindowController.applyAppearance(appearance)
        statusBarController?.applyAppearance(appearance)
        ClipFlowRuntime.shared.applyAppearance(appearance)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(store: ClipFlowStore, locale: Locale) {
        let rootView = SettingsSceneRoot(store: store, locale: locale)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "ClipFlow 剪流"
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 380, height: 600))
        window.minSize = NSSize(width: 380, height: 600)
        window.maxSize = NSSize(width: 380, height: 9999)
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    func applyAppearance(_ appearance: NSAppearance?) {
        guard let window else { return }
        window.appearance = appearance
        window.displayIfNeeded()
    }

    func windowWillClose(_ notification: Notification) {
        window?.orderOut(nil)
    }
}

private struct SettingsSceneRoot: View {
    @ObservedObject var store: ClipFlowStore
    let locale: Locale

    var body: some View {
        SettingsView(store: store)
            .ignoresSafeArea()
            .frame(width: 380, height: 600)
            .environment(\.locale, locale)
            .preferredColorScheme(store.appearanceMode.preferredColorScheme)
    }
}
