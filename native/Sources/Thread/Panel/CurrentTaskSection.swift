import SwiftUI

/// The task in focus and its running clock. Swiping the card right sets the task aside,
/// left finishes it; right-click offers the same. With nothing in focus it shows the idle prompt.
struct CurrentTaskSection: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        let task = store.current

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(task == nil ? "空闲" : "专注中", systemImage: "circle.fill")
                    .labelStyle(StatusLabelStyle(color: task == nil ? .secondary : .green))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(isOn: Bindable(store).isPinned) {
                    Image(systemName: store.isPinned ? "pin.fill" : "pin")
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .help(store.isPinned ? "取消固定，离开后自动收起" : "固定面板，保持展开")
                .accessibilityLabel("固定面板")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task?.title ?? "选择下一件最重要的事")
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let note = task == nil ? "在返回路径或队列里右滑一个任务继续，或添加新任务。" : task?.note {
                    Text(note).font(.callout).foregroundStyle(.secondary)
                }
            }
            // A new task slides in rather than swapping in place.
            .id(task?.id)
            .transition(.opacity.combined(with: .offset(y: -4)))

            // The clock is the only thing that changes every second, so only it sits in a timeline.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Formatting.clock(store.elapsed(at: context.date)))
                        .font(.system(.title2, design: .rounded, weight: .medium).monospacedDigit())
                        .foregroundStyle(task == nil ? .secondary : .primary)
                    Spacer()
                    if let startedAt = task?.startedAt {
                        Text("\(Formatting.timeOfDay(startedAt)) 开始").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if task != nil {
                // Always visible here, unlike the rows' hover hints: the card has no buttons left to discover.
                Text("\(Image(systemName: "arrow.right")) 稍后继续　\(Image(systemName: "arrow.left")) 完成　双指滑动卡片")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .swipeActions(
            right: task == nil ? nil : .pause { store.pauseCurrent() },
            left: task == nil ? nil : .complete { store.completeCurrent() }
        )
        .contextMenu {
            if task != nil {
                Button("完成", systemImage: "checkmark") { store.completeCurrent() }
                Button("稍后继续", systemImage: "pause") { store.pauseCurrent() }
            }
        }
        .animation(.easeOut(duration: 0.22), value: task?.id)
    }
}

/// A label whose icon is a small coloured status dot.
private struct StatusLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 7)).foregroundStyle(color)
            configuration.title
        }
    }
}
