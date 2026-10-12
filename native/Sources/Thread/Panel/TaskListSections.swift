import SwiftUI

/// The return path: tasks set aside by an interruption, most recent first.
struct ReturnPathSection: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeading(title: "返回路径") { Text("\(store.interrupted.count) 个待继续") }

            if store.interrupted.isEmpty {
                EmptyHint("没有搁置的任务，你的工作线很干净。")
            } else {
                // Relative times go stale, so the list re-evaluates once a minute.
                TimelineView(.everyMinute) { context in
                    VStack(spacing: 0) {
                        ForEach(store.interrupted) { task in
                            if task.id != store.interrupted.first?.id { Divider() }
                            ReturnRow(task: task, now: context.date)
                        }
                    }
                }
            }
        }
    }
}

private struct ReturnRow: View {
    @Environment(TaskStore.self) private var store
    let task: TaskItem
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            // A short thread from where the task was left to where it picks up again.
            VStack(spacing: 0) {
                Circle().strokeBorder(.tertiary, lineWidth: 1.5).frame(width: 7, height: 7)
                Rectangle().fill(.quaternary).frame(width: 1.5)
                Circle().fill(Color.accentColor).frame(width: 7, height: 7)
            }
            .frame(height: 34)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                Text("\(Formatting.ago(task.interruptedAt, now: now))被打断 · 已专注 \(Formatting.clock(task.accumulated))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            Button("继续") { store.resume(task.id) }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.14), in: .capsule)
        }
        .padding(.vertical, 10)
        .padding(.leading, 4)
        .contextMenu { Button("删除", role: .destructive) { store.delete(task.id) } }
    }
}

/// The queue: tasks planned for later, followed by what has been completed.
struct QueueSection: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeading(title: "接下来") {
                if !store.done.isEmpty {
                    Button("清理已完成") { store.clearDone() }.buttonStyle(.plain)
                }
            }

            if store.queue.isEmpty && store.done.isEmpty {
                EmptyHint("队列是空的。输入任务后按 ⇧↵ 可以排到这里。")
            } else {
                TimelineView(.everyMinute) { context in
                    VStack(spacing: 0) {
                        ForEach(Array(store.queue.enumerated()), id: \.element.id) { index, task in
                            QueueRow(task: task, position: index + 1, now: context.date)
                        }
                        ForEach(store.done) { task in
                            DoneRow(task: task, now: context.date)
                        }
                    }
                    // Rows highlight edge to edge of the section, so pull them out past its padding.
                    .padding(.horizontal, -8)
                }
            }
        }
    }
}

private struct QueueRow: View {
    @Environment(TaskStore.self) private var store
    let task: TaskItem
    let position: Int
    let now: Date
    @State private var isHovered = false

    var body: some View {
        Button {
            store.startQueued(task.id)
        } label: {
            HStack(spacing: 11) {
                Text("\(position)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 25, height: 25)
                    .background(.quaternary, in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                    Text(task.estimateMinutes.map { "约 \($0) 分钟" } ?? "\(Formatting.ago(task.addedAt, now: now))添加")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(8)
            .frame(minHeight: 52)
            .background(isHovered ? AnyShapeStyle(.quinary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("现在开始这个任务")
        .contextMenu { Button("删除", role: .destructive) { store.delete(task.id) } }
    }
}

private struct DoneRow: View {
    @Environment(TaskStore.self) private var store
    let task: TaskItem
    let now: Date

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 25, height: 25)
                .background(.quaternary, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title).font(.system(size: 12.5, weight: .medium)).strikethrough().lineLimit(1)
                Text("\(Formatting.ago(task.completedAt, now: now))完成 · 用时 \(Formatting.clock(task.accumulated))").font(.system(size: 11))
            }
            Spacer(minLength: 8)
        }
        .foregroundStyle(.secondary)
        .padding(8)
        .frame(minHeight: 52)
        .contextMenu { Button("删除", role: .destructive) { store.delete(task.id) } }
    }
}

/// One line of guidance shown in place of an empty list.
private struct EmptyHint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
            .padding(.leading, 4)
    }
}
