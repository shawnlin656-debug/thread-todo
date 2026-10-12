import AppKit
import SwiftUI

/// Thread runs as a menu bar accessory: no Dock icon and no main window, only the
/// floating side panel, the notch island, and a menu bar item to control them.
@main
struct ThreadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(PanelBackground.liquidGlassKey) private var useLiquidGlass = false

    var body: some Scene {
        MenuBarExtra("Thread", systemImage: "arrow.uturn.backward.circle") {
            Button("添加任务…　⌃⌥空格") { delegate.quickEntry?.toggle() }
            Divider()
            Toggle("固定面板", isOn: Bindable(delegate.store).isPinned)
            // The two materials look different depending on what is behind the panel; let the user pick.
            Toggle("Liquid Glass 材质（实验）", isOn: $useLiquidGlass)
            Divider()
            Button("退出 Thread") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

/// Owns the store and the floating windows for the lifetime of the app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TaskStore()
    private var sidePanel: SidePanelController?
    private var notch: NotchController?
    private(set) var quickEntry: QuickEntryController?
    private var autosave: Timer?
    private var ticker: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        sidePanel = SidePanelController(store: store)
        notch = NotchController(store: store)
        quickEntry = QuickEntryController(store: store)

        // Focus time lives in memory between actions; bank it regularly so a crash loses little.
        // Scheduled tasks are checked every second; missed ones start as soon as the app is running.
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [store] _ in
            MainActor.assumeIsolated { store.startDueTasks() }
        }
        store.startDueTasks()

        autosave = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [store] _ in
            MainActor.assumeIsolated { store.save() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }
}
