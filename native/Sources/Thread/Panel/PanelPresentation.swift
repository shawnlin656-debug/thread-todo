import Foundation
import Observation

/// Whether the side panel is slid out or tucked into the screen edge, and the rules
/// that move it between the two. It behaves like an auto-hiding Dock: touching the
/// edge reveals it, and it retreats shortly after the pointer leaves.
@Observable
final class PanelPresentation {
    private(set) var isOpen = false

    /// How long the pointer must rest on the screen edge before the panel opens,
    /// so reaching for a scroll bar does not trigger it.
    private static let openDwell: Duration = .milliseconds(180)
    /// Grace period after the pointer leaves before the panel closes.
    private static let closeDelay: Duration = .milliseconds(600)

    private let store: TaskStore
    private var isPointerInside = false
    private var isPointerAtEdge = false
    private var pending: Task<Void, Never>?

    /// True while the quick-add field has focus.
    var isEditing = false { didSet { reconsider() } }
    /// True while the panel's window receives keystrokes. Focus alone is not enough to hold the
    /// panel open: the field stays focused after the user has clicked away into another app.
    var isWindowKey = false { didSet { reconsider() } }

    init(store: TaskStore) {
        self.store = store
        isOpen = store.isPinned
        observe { [weak self] in
            _ = store.isPinned
            self?.reconsider()
        }
    }

    /// The pointer entered or left the open panel.
    func pointerInside(_ inside: Bool) {
        isPointerInside = inside
        reconsider()
    }

    /// The pointer reached or left the screen edge the panel hides behind.
    func pointerAtEdge(_ atEdge: Bool) {
        guard atEdge != isPointerAtEdge else { return }
        isPointerAtEdge = atEdge
        reconsider()
    }

    /// Reveal the panel immediately, e.g. when its handle is hovered.
    func open() {
        pending?.cancel()
        isOpen = true
    }

    /// Decide whether the panel should be open and move toward that state after the right delay.
    private func reconsider() {
        pending?.cancel()
        // The panel never closes under the user's typing.
        let isTyping = isEditing && isWindowKey
        let shouldBeOpen = store.isPinned || isTyping || isPointerInside || isPointerAtEdge
        guard shouldBeOpen != isOpen else { return }

        // Pinning and typing act at once; pointer movement is debounced in both directions.
        let delay: Duration = store.isPinned || isTyping ? .zero : (shouldBeOpen ? Self.openDwell : Self.closeDelay)
        pending = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            isOpen = shouldBeOpen
        }
    }
}
