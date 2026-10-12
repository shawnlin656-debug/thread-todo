import SwiftUI

/// The return path: tasks set aside by an interruption, most recent first.
struct ReturnPathSection: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeading(title: "返回路径") {
                if !store.interrupted.isEmpty { Text("\(store.interrupted.count) 个待继续") }
            }

            if store.interrupted.isEmpty {
                EmptyHint("没有搁置的任务。")
            } else {
                // Relative times go stale, so the list re-evaluates once a minute.
                TimelineView(.everyMinute) { context in
                    VStack(spacing: 0) {
                        ForEach(store.interrupted) { task in
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
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.title3)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TaskRowText(
                title: task.title,
                detail: "\(Formatting.ago(task.interruptedAt, now: now))被打断 · 已专注 \(Formatting.clock(task.accumulated))"
            )
            Spacer(minLength: 8)
            Button("继续") { store.resume(task.id) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .rowHover()
        .contextMenu { Button("删除", systemImage: "trash", role: .destructive) { store.delete(task.id) } }
    }
}

/// Tasks with a set start time. Each takes over on its own when its time comes.
struct ScheduledSection: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeading(title: "定时") { Text("到点自动切换") }
            TimelineView(.everyMinute) { context in
                VStack(spacing: 0) {
                    ForEach(store.scheduled) { task in
                        ScheduledRow(task: task, now: context.date)
                    }
                }
            }
        }
    }
}

private struct ScheduledRow: View {
    @Environment(TaskStore.self) private var store
    let task: TaskItem
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.title3)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            TaskRowText(
                title: task.title,
                detail: task.scheduledAt.map { "\(Formatting.startTime($0, now: now)) 开始 · \(Formatting.until($0, now: now))" } ?? ""
            )
            Spacer(minLength: 8)
            Button("现在开始") { store.startScheduled(task.id) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .rowHover()
        .contextMenu { Button("删除", systemImage: "trash", role: .destructive) { store.delete(task.id) } }
    }
}

/// The queue: tasks planned for later, followed by what has been completed.
struct QueueSection: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeading(title: "接下来") {
                if !store.done.isEmpty {
                    Button("清理已完成") { store.clearDone() }.buttonStyle(.link)
                }
            }

            if store.queue.isEmpty && store.done.isEmpty {
                EmptyHint("队列是空的。输入任务后按 ⇧↩ 排到这里。")
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
                }
            }
        }
    }
}

/// A queued task. Clicking anywhere on the row starts it.
private struct QueueRow: View {
    @Environment(TaskStore.self) private var store
    let task: TaskItem
    let position: Int
    let now: Date

    var body: some View {
        Button {
            store.startQueued(task.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "\(min(position, 50)).circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TaskRowText(
                    title: task.title,
                    detail: task.estimateMinutes.map { "约 \($0) 分钟" } ?? "\(Formatting.ago(task.addedAt, now: now))添加"
                )
                Spacer(minLength: 8)
                Image(systemName: "play.fill").font(.caption).foregroundStyle(.tertiary)
            }
            .rowHover()
        }
        .buttonStyle(.plain)
        .help("现在开始这个任务")
        .contextMenu { Button("删除", systemImage: "trash", role: .destructive) { store.delete(task.id) } }
    }
}

private struct DoneRow: View {
    @Environment(TaskStore.self) private var store
    let task: TaskItem
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.title3).accessibilityHidden(true)
            TaskRowText(
                title: task.title,
                detail: "\(Formatting.ago(task.completedAt, now: now))完成 · 用时 \(Formatting.clock(task.accumulated))",
                isStruckThrough: true
            )
            Spacer(minLength: 8)
        }
        .foregroundStyle(.secondary)
        .rowHover()
        .contextMenu { Button("删除", systemImage: "trash", role: .destructive) { store.delete(task.id) } }
    }
}

/// Title over a one-line detail, shared by every row.
private struct TaskRowText: View {
    let title: String
    let detail: String
    var isStruckThrough = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body).strikethrough(isStruckThrough).lineLimit(1)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

/// One line of guidance shown in place of an empty list.
private struct EmptyHint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.callout).foregroundStyle(.tertiary).padding(.vertical, 4)
    }
}
