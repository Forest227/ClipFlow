import AppKit
import SwiftUI

@main
struct ClipFlowApp: App {
    @NSApplicationDelegateAdaptor(ClipFlowAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: ClipFlowStore.shared)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .preferredColorScheme(ClipFlowStore.shared.appearanceMode.preferredColorScheme)
        }
    }
}

@MainActor
final class ClipFlowAppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private lazy var libraryWindowController = LibraryWindowController(
        store: ClipFlowStore.shared,
        locale: Locale(identifier: "zh-Hans")
    )
    private lazy var settingsWindowController = SettingsWindowController(
        store: ClipFlowStore.shared,
        locale: Locale(identifier: "zh-Hans")
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipFlowRuntime.shared.start()
        statusBarController = StatusBarController(store: ClipFlowStore.shared)
        AppNavigationCenter.shared.openLibraryWindow = { [weak self] in
            self?.showLibraryWindow()
        }
        AppNavigationCenter.shared.openSettingsWindow = { [weak self] in
            self?.showSettingsWindow()
        }

        if !ClipFlowStore.shared.launchToStatusBar {
            showLibraryWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showLibraryWindow()
        }
        return true
    }

    @MainActor
    private func showLibraryWindow() {
        libraryWindowController.showAndActivate()
    }

    @MainActor
    private func showSettingsWindow() {
        settingsWindowController.showAndActivate()
    }
}

@MainActor
final class LibraryWindowController: NSWindowController, NSWindowDelegate {
    init(store: ClipFlowStore, locale: Locale) {
        let rootView = LibrarySceneRoot(store: store, locale: locale)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "ClipFlow 剪流"
        window.setContentSize(NSSize(width: 500, height: 780))
        window.minSize = NSSize(width: 500, height: 600)
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ClipFlowLibraryWindow")

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
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.orderOut(nil)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(store: ClipFlowStore, locale: Locale) {
        let rootView = SettingsSceneRoot(store: store, locale: locale)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "ClipFlow 剪流设置"
        window.setContentSize(NSSize(width: 540, height: 600))
        window.minSize = NSSize(width: 540, height: 600)
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ClipFlowSettingsWindow")

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
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.orderOut(nil)
    }
}

private struct LibrarySceneRoot: View {
    @ObservedObject var store: ClipFlowStore
    let locale: Locale

    var body: some View {
        ContentView(store: store)
            .frame(minWidth: 500, minHeight: 600)
            .environment(\.locale, locale)
            .preferredColorScheme(store.appearanceMode.preferredColorScheme)
    }
}

private struct SettingsSceneRoot: View {
    @ObservedObject var store: ClipFlowStore
    let locale: Locale

    var body: some View {
        SettingsView(store: store)
            .frame(minWidth: 540, minHeight: 600)
            .environment(\.locale, locale)
            .preferredColorScheme(store.appearanceMode.preferredColorScheme)
    }
}
