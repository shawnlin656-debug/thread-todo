import AppKit
import SwiftUI

/// What one direction of a swipeable row does.
struct SwipeAction {
    let title: String
    let systemImage: String
    let tint: Color
    let perform: () -> Void
}

// Spelled out instead of `@Entry`: the macro needs Xcode's plugins, and this builds with the
// Command Line Tools alone.
private struct SwipeRowHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while the pointer is over the enclosing swipeable row, so the row can show its hint.
    var isSwipeRowHovered: Bool {
        get { self[SwipeRowHoveredKey.self] }
        set { self[SwipeRowHoveredKey.self] = newValue }
    }
}

extension View {
    /// Mail-style actions driven by a two-finger horizontal swipe on the trackpad while the
    /// pointer rests on the view. The view follows the fingers; releasing past the threshold
    /// runs the action for that direction, anything shorter springs back.
    ///
    /// - Parameters:
    ///   - right: Runs when the fingers move right. `nil` makes that direction inert.
    ///   - left: Runs when the fingers move left.
    func swipeActions(right: SwipeAction?, left: SwipeAction?) -> some View {
        modifier(SwipeActionsModifier(right: right, left: left))
    }
}

private struct SwipeActionsModifier: ViewModifier {
    let right: SwipeAction?
    let left: SwipeAction?

    /// Travel at which releasing commits the action.
    private static let threshold: CGFloat = 72
    /// Travel beyond which the row resists, like a rubber band.
    private static let stretchLimit: CGFloat = 110
    /// Rows draw their hover highlight this far past their frame (see `RowHover`); the clip leaves room for it.
    private static let bleed: CGFloat = 8

    @State private var offset: CGFloat = 0
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .environment(\.isSwipeRowHovered, isHovered && offset == 0)
            .offset(x: offset)
            .padding(.horizontal, Self.bleed)
            .overlay(alignment: offset >= 0 ? .leading : .trailing) {
                if let action = offset > 0 ? right : (offset < 0 ? left : nil) {
                    reveal(action)
                }
            }
            .clipShape(.rect(cornerRadius: 8))
            .background { SwipeTracker(onChange: track, onEnd: release) }
            .padding(.horizontal, -Self.bleed)
            .onHover { isHovered = $0 }
    }

    /// The action's badge, filling the gap the row leaves behind; solid once releasing would commit.
    private func reveal(_ action: SwipeAction) -> some View {
        let isArmed = abs(offset) >= Self.threshold
        return Label(action.title, systemImage: action.systemImage)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isArmed ? AnyShapeStyle(.white) : AnyShapeStyle(action.tint))
            .frame(width: max(abs(offset) - 4, 0))
            .frame(maxHeight: .infinity)
            .background(action.tint.opacity(isArmed ? 1 : 0.16), in: .rect(cornerRadius: 8))
            .clipped()
            .animation(.easeOut(duration: 0.12), value: isArmed)
    }

    /// Follow the fingers. A direction without an action barely moves, which says "nothing here".
    private func track(_ distance: CGFloat) {
        let hasAction = distance > 0 ? right != nil : left != nil
        let travel = hasAction ? distance : distance * 0.15
        let magnitude = abs(travel) <= Self.stretchLimit
            ? abs(travel)
            : Self.stretchLimit + (abs(travel) - Self.stretchLimit) * 0.3

        let wasArmed = abs(offset) >= Self.threshold
        offset = travel < 0 ? -magnitude : magnitude
        // A tap from the trackpad when crossing the threshold in either direction, as in Mail.
        if (abs(offset) >= Self.threshold) != wasArmed {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func release() {
        let action = offset >= Self.threshold ? right : (offset <= -Self.threshold ? left : nil)
        withAnimation(.smooth(duration: 0.25)) {
            offset = 0
            action?.perform()
        }
    }
}

/// A small "→ 继续　← 完成" legend a row shows while hovered, so the swipes can be discovered.
struct SwipeHint: View {
    @Environment(\.isSwipeRowHovered) private var isHovered
    let right: String
    let left: String

    var body: some View {
        if isHovered {
            Text("\(Image(systemName: "arrow.right")) \(right)　\(Image(systemName: "arrow.left")) \(left)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }
}

/// Reports horizontal trackpad scrolling that starts over this view.
private struct SwipeTracker: NSViewRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> SwipeTrackingView { SwipeTrackingView() }

    func updateNSView(_ view: SwipeTrackingView, context: Context) {
        view.onChange = onChange
        view.onEnd = onEnd
    }
}

/// Watches the window's scroll events instead of receiving them, so clicks, hover and the
/// enclosing scroll view behave exactly as before; only gestures that turn out horizontal
/// are taken.
private final class SwipeTrackingView: NSView {
    var onChange: (CGFloat) -> Void = { _ in }
    var onEnd: () -> Void = {}

    private enum Axis { case undecided, horizontal, vertical }
    /// `nil` while no gesture that began over this view is in progress.
    private var axis: Axis?
    private var distanceX: CGFloat = 0
    private var distanceY: CGFloat = 0
    /// True between the end of a swipe and the end of its momentum, which would otherwise scroll the list.
    private var isSwallowingMomentum = false
    private var monitor: Any?

    // Invisible to clicks: they go to the row's own controls.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    /// - Returns: The event to pass on, or `nil` once it belongs to a horizontal swipe.
    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }

        if !event.momentumPhase.isEmpty {
            guard isSwallowingMomentum else { return event }
            if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) { isSwallowingMomentum = false }
            return nil
        }

        // Only trackpad gestures carry a phase; a mouse wheel never swipes.
        if event.phase.contains(.began) {
            axis = bounds.contains(convert(event.locationInWindow, from: nil)) ? .undecided : nil
            (distanceX, distanceY) = (0, 0)
            isSwallowingMomentum = false
        }
        guard let current = axis else { return event }

        if event.phase.contains(.began) || event.phase.contains(.changed) {
            // Natural scrolling reports the content's motion, which matches the fingers; otherwise flip it.
            distanceX += event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
            distanceY += event.scrollingDeltaY
            if current == .undecided, hypot(distanceX, distanceY) > 6 {
                axis = abs(distanceX) > abs(distanceY) * 1.5 ? .horizontal : .vertical
            }
            guard axis == .horizontal else { return event }
            onChange(distanceX)
            return nil
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            axis = nil
            guard current == .horizontal else { return event }
            isSwallowingMomentum = true
            onEnd()
            return nil
        }
        return event
    }
}
