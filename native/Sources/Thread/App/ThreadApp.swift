import AppKit
import SwiftUI

/// Thread runs as a menu bar accessory: no Dock icon and no main window, only the
/// floating side panel, the notch island, and a menu bar item to control them.
@main
struct ThreadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Thread", systemImage: "arrow.uturn.backward.circle") {
            Button(delegate.store.isCollapsed ? "展开面板" : "收起面板") {
                delegate.store.isCollapsed.toggle()
            }
            Divider()
            Button("退出 Thread") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

/// Owns the store and the two floating windows for the lifetime of the app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TaskStore()
    private var sidePanel: SidePanelController?
    private var notch: NotchController?
    private var autosave: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        sidePanel = SidePanelController(store: store)
        notch = NotchController(store: store)

        // Focus time lives in memory between actions; bank it regularly so a crash loses little.
        autosave = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [store] _ in
            MainActor.assumeIsolated { store.save() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }
}
