import AppKit
import SwiftUI

@main
struct ClipFlowApp: App {
    @NSApplicationDelegateAdaptor(ClipFlowAppDelegate.self) private var appDelegate
    @StateObject private var store = ClipFlowStore.shared
    private let appLocale = Locale(identifier: "zh-Hans")

    var body: some Scene {
        WindowGroup("ClipFlow 剪流", id: "library") {
            ContentView(store: store)
                .frame(minWidth: 1120, minHeight: 780)
                .environment(\.locale, appLocale)
        }
        .defaultSize(width: 1280, height: 860)
        .windowResizability(.contentMinSize)

        MenuBarExtra(
            "剪流",
            systemImage: store.capturePaused ? "pause.circle" : "paperclip.circle.fill"
        ) {
            MenuBarView(store: store)
                .environment(\.locale, appLocale)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
                .environment(\.locale, appLocale)
        }
    }
}

final class ClipFlowAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipFlowRuntime.shared.start()
    }
}
