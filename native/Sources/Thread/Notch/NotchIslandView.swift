import SwiftUI

/// Live Focus: the current task and its clock on wings either side of the camera housing.
///
/// The island is the same black as the hardware, so the notch simply reads as wider and,
/// on hover, taller. Nothing is ever laid out in the column the housing occupies.
struct NotchIslandView: View {
    /// Width of each wing beside the housing.
    static let wingWidth: CGFloat = 170
    private static let flipInterval: Duration = .seconds(20)
    private static let flipHold: Duration = .seconds(4.5)

    @Environment(TaskStore.self) private var store
    /// Size of the camera housing; zero width on displays without one.
    let notchSize: CGSize

    @State private var isExpanded = false
    /// While true the left wing shows the upcoming task instead of the current one.
    @State private var isFlipped = false
    @State private var flipTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            wings
            if isExpanded { peek }
        }
        .frame(width: notchSize.width + 2 * Self.wingWidth)
        .background(.black, in: shape)
        .compositingGroup()
        .shadow(color: .black.opacity(isExpanded ? 0.3 : 0), radius: 18, y: 10)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .contentShape(shape)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.28)) {
                isExpanded = hovering
                // Never move the text under the pointer once the peek is open.
                if hovering { isFlipped = false }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            // Periodic reminder of what comes next.
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.flipInterval)
                flash()
            }
        }
        // An interruption just parked a task: show straight away where the user will return to.
        .onChange(of: store.interruptionCount) { flash() }
    }

    /// Square against the top of the screen, rounded below; rounder once the peek is open.
    private var shape: UnevenRoundedRectangle {
        let radius: CGFloat = isExpanded ? 20 : 12
        return UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
    }

    // MARK: - Wings

    private var wings: some View {
        HStack(spacing: 0) {
            Group {
                if isFlipped, let upcoming = upcomingLine {
                    Text(upcoming).foregroundStyle(.white.opacity(0.78)).transition(.push(from: .bottom))
                } else {
                    Text(store.current?.title ?? "空闲").transition(.push(from: .top))
                }
            }
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(width: Self.wingWidth, alignment: .leading)
            .clipped()

            // The camera housing: reserved, always empty.
            Color.clear.frame(width: notchSize.width)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = store.elapsed(at: context.date)
                HStack(spacing: 7) {
                    // Sweeps once a minute, like a second hand.
                    Circle()
                        .trim(from: 0, to: store.current == nil ? 0 : elapsed.truncatingRemainder(dividingBy: 60) / 60)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .background { Circle().stroke(.white.opacity(0.2), lineWidth: 2.2) }
                        .frame(width: 11, height: 11)
                    Text(store.current == nil ? "--:--" : Formatting.clock(elapsed))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
            }
            .padding(.trailing, 16)
            .frame(width: Self.wingWidth, alignment: .trailing)
        }
        .frame(height: notchSize.height)
        .accessibilityElement(children: .combine)
    }

    /// Left-wing preview text. The task to return to always outranks the queue.
    private var upcomingLine: String? {
        if let returning = store.returnTarget { return "返回 · \(returning.title)" }
        if let queued = store.queue.first { return "下一个 · \(queued.title)" }
        return nil
    }

    // MARK: - Peek

    private var peek: some View {
        VStack(spacing: 0) {
            if let returning = store.returnTarget {
                PeekRow(
                    label: store.current == nil ? "待继续" : "完成后返回",
                    title: returning.title,
                    detail: "\(Formatting.ago(returning.interruptedAt))被打断"
                ) { store.resume(returning.id) }
            }
            if let queued = store.queue.first {
                PeekRow(
                    label: "接下来",
                    title: queued.title,
                    detail: queued.estimateMinutes.map { "约 \($0) 分钟" } ?? "\(Formatting.ago(queued.addedAt))添加"
                ) { store.startQueued(queued.id) }
            }
            if store.returnTarget == nil && store.queue.isEmpty {
                Text("后面没有排队的任务。")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))
        .transition(.opacity)
    }

    /// Show the upcoming task on the left wing for a few seconds, then restore the current one.
    private func flash() {
        guard upcomingLine != nil, !isExpanded else { return }
        flipTask?.cancel()
        flipTask = Task {
            withAnimation(.smooth(duration: 0.45)) { isFlipped = true }
            try? await Task.sleep(for: Self.flipHold)
            withAnimation(.smooth(duration: 0.45)) { isFlipped = false }
        }
    }
}

/// One actionable line in the peek: clicking it switches to that task.
private struct PeekRow: View {
    let label: String
    let title: String
    let detail: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                    Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(.white.opacity(isHovered ? 0.14 : 0), in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
