import AppKit
import SwiftUI

@main
struct ClipFlowApp: App {
    @NSApplicationDelegateAdaptor(ClipFlowAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: ClipFlowStore.shared)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipFlowRuntime.shared.start()
        statusBarController = StatusBarController(store: ClipFlowStore.shared)
        AppNavigationCenter.shared.openLibraryWindow = { [weak self] in
            self?.showLibraryWindow()
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
}

@MainActor
final class LibraryWindowController: NSWindowController, NSWindowDelegate {
    init(store: ClipFlowStore, locale: Locale) {
        let rootView = LibrarySceneRoot(store: store, locale: locale)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "ClipFlow 剪流"
        window.setContentSize(NSSize(width: 1220, height: 820))
        window.minSize = NSSize(width: 900, height: 620)
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

private struct LibrarySceneRoot: View {
    @ObservedObject var store: ClipFlowStore
    let locale: Locale

    var body: some View {
        ContentView(store: store)
            .frame(minWidth: 900, minHeight: 620)
            .environment(\.locale, locale)
    }
}
