import AppKit
import SwiftUI

/// Hosts the Live Focus island in a transparent window pinned over the camera housing.
///
/// The window is sized for the island's expanded state and never resizes; the island
/// animates inside it. Its transparent areas let clicks through to whatever is below.
final class NotchController {
    private enum Metrics {
        /// Room below the housing for the expanded peek.
        static let height: CGFloat = 260
        /// Transparent margin on each side so the drop shadow is not clipped.
        static let sideInset: CGFloat = 40
    }

    private let store: TaskStore
    private var panel: FloatingPanel?
    private var geometry: NotchGeometry?

    init(store: TaskStore) {
        self.store = store
        rebuild()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
    }

    /// Recreate the window when displays change, since the notch may have moved or gone.
    private func rebuild() {
        guard let (screen, geometry) = NotchGeometry.current(), geometry != self.geometry else { return }
        self.geometry = geometry
        panel?.close()

        let panel = FloatingPanel(
            // Above the menu bar, so the wings can sit beside the housing.
            level: .mainMenu + 3,
            content: NotchIslandView(notchSize: geometry.rect.size)
                .padding(.horizontal, Metrics.sideInset)
                .environment(store)
        )
        let width = geometry.rect.width + 2 * (NotchIslandView.wingWidth + Metrics.sideInset)
        panel.setFrame(
            NSRect(x: geometry.rect.midX - width / 2, y: screen.frame.maxY - Metrics.height, width: width, height: Metrics.height),
            display: true
        )
        panel.orderFrontRegardless()
        self.panel = panel
    }
}
