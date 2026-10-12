import AppKit
import SwiftUI

/// A borderless, transparent panel that floats above other apps on every Space and
/// accepts clicks and typing without activating Thread or stealing the user's focus.
final class FloatingPanel: NSPanel {
    init(level: NSWindow.Level, content: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let host = NSHostingView(rootView: content)
        // The controllers set the window frame explicitly; SwiftUI must not resize it.
        host.sizingOptions = []
        contentView = host
    }

    // Needed for the quick-add text field to receive keystrokes.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// AppKit normally pushes windows below the menu bar. The notch island has to sit
    /// inside it, so frames are used exactly as given.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Re-runs `apply` whenever any observable value it reads changes.
///
/// `withObservationTracking` fires once per registration, so the tracking re-arms itself.
func observe(_ apply: @escaping @MainActor () -> Void) {
    withObservationTracking {
        apply()
    } onChange: {
        Task { @MainActor in observe(apply) }
    }
}
