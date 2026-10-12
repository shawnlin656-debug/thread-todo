import AppKit
import SwiftUI

/// Shows the quick-entry bar over whatever the user is doing when they press ⌃⌥Space,
/// the way Spotlight appears, and puts it away again without disturbing the app underneath.
final class QuickEntryController {
    private let panel: FloatingPanel
    private let state = QuickEntryState()
    private var hotKey: GlobalHotKey?

    /// How far down the screen the top of the bar sits, as a fraction of the screen height.
    private static let topInset: CGFloat = 0.24

    init(store: TaskStore) {
        panel = FloatingPanel(
            level: .modalPanel,
            content: QuickEntryView()
                .environment(store)
                .environment(state)
        )
        state.close = { [weak self] in self?.hide() }

        // Clicking anywhere else dismisses the bar, as it does for Spotlight.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }

        hotKey = GlobalHotKey(key: .space, modifiers: [.control, .option]) { [weak self] in self?.toggle() }
        if hotKey == nil { NSLog("Thread: could not register the ⌃⌥Space shortcut; another app may own it.") }
    }

    /// Show the bar, or put it away if it is already up.
    func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func show() {
        // Appear on the screen the user is looking at, taken to be the one holding the pointer.
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let size = QuickEntryView.Metrics.windowSize
        let barTop = screen.frame.maxY - screen.frame.height * Self.topInset
        panel.setFrame(
            NSRect(
                x: screen.frame.midX - size.width / 2,
                y: barTop + QuickEntryView.Metrics.shadowMargin - size.height,
                width: size.width,
                height: size.height
            ),
            display: true
        )

        state.presentations += 1
        panel.alphaValue = 0
        // The panel is non-activating: it takes the keyboard while the user's app stays active.
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        focusField()
    }

    /// Ordering the panel out hands the keyboard straight back to the app underneath.
    private func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    /// Put the cursor in the text field. SwiftUI's focus state usually manages this on its own,
    /// but it can miss the first presentation, before the window has ever been key.
    private func focusField() {
        DispatchQueue.main.async { [panel] in
            guard panel.isVisible, !(panel.firstResponder is NSText),
                  let field = panel.contentView?.firstDescendant(ofType: NSTextField.self) else { return }
            panel.makeFirstResponder(field)
        }
    }
}

private extension NSView {
    /// Depth-first search of the view tree for the first view of a given class.
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstDescendant(ofType: type) { return match }
        }
        return nil
    }
}
