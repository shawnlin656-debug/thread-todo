import AppKit
import SwiftUI

/// Shared between the quick-entry window's controller and its view.
@Observable
final class QuickEntryState {
    /// Increments each time the window is shown, so the view can start from a blank field.
    var presentations = 0
    /// Closes the window. Set by the controller.
    @ObservationIgnored var close: () -> Void = {}
}

/// A Spotlight-style bar for adding a task from anywhere: one large field, and a line
/// underneath that says what Return will do with the text typed so far.
struct QuickEntryView: View {
    enum Metrics {
        static let barWidth: CGFloat = 640
        static let barHeight: CGFloat = 104
        static let cornerRadius: CGFloat = 22
        /// Transparent margin around the bar so its shadow is not clipped by the window.
        static let shadowMargin: CGFloat = 44
        static let windowSize = CGSize(width: barWidth + shadowMargin * 2, height: barHeight + shadowMargin * 2)
    }

    @Environment(TaskStore.self) private var store
    @Environment(QuickEntryState.self) private var state
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                // `onSubmit` only fires after an input method has committed its text,
                // so confirming a Chinese candidate never submits.
                TextField("添加任务，例如：3pm 写周报", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24))
                    .focused($isFocused)
                    .onSubmit(submit)
                    .onExitCommand { state.close() }
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)

            Divider()

            HStack {
                // Re-evaluated every half minute so the countdown in the preview stays honest.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    preview(now: context.date)
                }
                Spacer()
                Text("⇧↩ 排到接下来　esc 取消")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 20)
            .frame(height: 38)
        }
        .frame(width: Metrics.barWidth, height: Metrics.barHeight)
        .background { PanelBackground(cornerRadius: Metrics.cornerRadius) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: state.presentations) {
            text = ""
            isFocused = true
        }
    }

    /// What Return will do with the current text; a recognized time is spelled out with am/pm.
    @ViewBuilder
    private func preview(now: Date) -> some View {
        switch TaskStore.entry(for: text, queued: false, now: now) {
        case .schedule(_, let date):
            Label("\(Formatting.startTime(date, now: now)) 开始 · \(Formatting.until(date, now: now))", systemImage: "clock")
                .foregroundStyle(.tint)
        case .interrupt, .enqueue:
            Text("↩ 立即开始，当前任务保留在返回路径").foregroundStyle(.secondary)
        case nil:
            Text("写上时间可定时开始：3pm、3:30pm、9am").foregroundStyle(.secondary)
        }
    }

    private func submit() {
        guard let entry = TaskStore.entry(for: text, queued: NSEvent.modifierFlags.contains(.shift)) else { return }
        store.add(entry)
        state.close()
    }
}
