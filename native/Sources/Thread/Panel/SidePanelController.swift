import AppKit
import SwiftUI

/// Hosts the side panel in a transparent window along the right edge of the screen and
/// watches for the pointer touching that edge.
///
/// The window always covers the panel's open footprint; the panel slides in and out
/// inside it, so there is no window resizing to fight the animation.
final class SidePanelController {
    private let panel: FloatingPanel
    private let presentation: PanelPresentation
    private var monitors: [Any] = []

    init(store: TaskStore) {
        presentation = PanelPresentation(store: store)
        panel = FloatingPanel(
            level: .floating,
            content: SidePanelView()
                .environment(store)
                .environment(presentation)
        )
        layout()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }

        for (name, isKey) in [(NSWindow.didBecomeKeyNotification, true), (NSWindow.didResignKeyNotification, false)] {
            NotificationCenter.default.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.presentation.isWindowKey = isKey }
            }
        }

        // Pointer position is needed even while other apps are active, hence the global monitor;
        // the local one covers the moments when this panel is the key window.
        let track: (NSEvent) -> Void = { [weak self] _ in self?.trackPointer() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: track) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { event in track(event); return event }) {
            monitors.append(local)
        }
    }

    /// Pin the window to the right edge, spanning the usable height (below the menu bar, above the Dock).
    private func layout() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let width = SidePanelView.Metrics.windowWidth
        panel.setFrame(NSRect(x: area.maxX - width, y: area.minY, width: width, height: area.height), display: true)
    }

    /// Report whether the pointer is resting against the panel's screen edge.
    private func trackPointer() {
        guard let screen = panel.screen else { return }
        let pointer = NSEvent.mouseLocation
        let area = screen.visibleFrame
        presentation.pointerAtEdge(pointer.x >= screen.frame.maxX - 2 && pointer.y >= area.minY && pointer.y <= area.maxY)
    }
}
