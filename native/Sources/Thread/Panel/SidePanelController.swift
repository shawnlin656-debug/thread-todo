import AppKit
import SwiftUI

/// Places the side panel against the right edge of the screen and swaps its frame
/// between the full panel and the collapsed rail.
final class SidePanelController {
    private enum Metrics {
        static let panelWidth: CGFloat = 384
        static let railSize = CGSize(width: 48, height: 154)
        /// Gap between the panel and the screen edges.
        static let margin: CGFloat = 12
        /// Transparent border inside the window so the glass shadow is not clipped.
        static let shadowInset: CGFloat = 24
    }

    private let store: TaskStore
    private let panel: FloatingPanel

    init(store: TaskStore) {
        self.store = store
        panel = FloatingPanel(
            level: .floating,
            content: SidePanelView()
                .padding(Metrics.shadowInset)
                .environment(store)
        )
        panel.orderFrontRegardless()

        observe { [weak self] in self?.layout(animated: true) }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout(animated: false) }
        }
    }

    /// Fit the window to the current mode within the screen's usable area (below the
    /// menu bar, clear of the Dock).
    private func layout(animated: Bool) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let area = screen.visibleFrame.insetBy(dx: Metrics.margin, dy: Metrics.margin)

        let content: NSRect
        if store.isCollapsed {
            let size = Metrics.railSize
            content = NSRect(x: area.maxX - size.width, y: area.midY - size.height / 2, width: size.width, height: size.height)
        } else {
            content = NSRect(x: area.maxX - Metrics.panelWidth, y: area.minY, width: Metrics.panelWidth, height: area.height)
        }

        let frame = content.insetBy(dx: -Metrics.shadowInset, dy: -Metrics.shadowInset)
        panel.setFrame(frame, display: true, animate: animated && panel.frame != .zero)
    }
}
