import AppKit

/// Where the camera housing sits on a screen, read from the system at run time so the
/// island fits whichever MacBook it is on instead of relying on per-model tables.
struct NotchGeometry: Equatable {
    /// The housing in screen coordinates. On a display without a notch this is a
    /// zero-width strip, as tall as the menu bar, at the top centre.
    let rect: CGRect
    let hasNotch: Bool

    /// Geometry for the built-in notched display if there is one, else the main screen.
    static func current() -> (screen: NSScreen, geometry: NotchGeometry)? {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return nil }
        return (screen, NotchGeometry(screen: screen))
    }

    init(screen: NSScreen) {
        let frame = screen.frame
        let height = screen.safeAreaInsets.top

        // The auxiliary areas are the usable menu bar strips on either side of the housing;
        // whatever lies between them is the notch.
        if height > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            rect = CGRect(x: left.maxX, y: frame.maxY - height, width: right.minX - left.maxX, height: height)
            hasNotch = true
        } else {
            let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, 24)
            rect = CGRect(x: frame.midX, y: frame.maxY - menuBarHeight, width: 0, height: menuBarHeight)
            hasNotch = false
        }
    }
}
