import SwiftUI

/// The "now" card: the task in focus, its running clock, and the two ways to leave it.
/// With nothing in focus it shows the idle prompt and disables both actions.
struct CurrentTaskSection: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        let task = store.current

        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "正在进行") {
                HStack(spacing: 6) {
                    Circle().fill(task == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.green)).frame(width: 7, height: 7)
                    Text(task == nil ? "空闲" : "专注中")
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(task?.type ?? "空闲")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 22)
                    .background(Color.accentColor.opacity(0.14), in: .rect(cornerRadius: 6))

                Text(task?.title ?? "选择下一件最重要的事")
                    .font(.system(size: 19, weight: .semibold))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                if let note = task == nil ? "从下方队列中选择，或添加一个新任务。" : task?.note {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }

                // The clock is the only thing that changes every second, so only it sits in a timeline.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(Formatting.clock(store.elapsed(at: context.date)))
                            .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        Text("已专注").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        if let startedAt = task?.startedAt {
                            Text("\(Formatting.timeOfDay(startedAt)) 开始").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 18)

                HStack(spacing: 8) {
                    Button { store.completeCurrent() } label: { Label("完成", systemImage: "checkmark") }
                        .buttonStyle(CapsuleActionStyle(prominent: true))
                    Button { store.pauseCurrent() } label: { Label("稍后继续", systemImage: "pause") }
                        .buttonStyle(CapsuleActionStyle())
                }
                .disabled(task == nil)
                .padding(.top, 14)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: .rect(cornerRadius: 14))
            // A new task slides in rather than swapping in place.
            .id(task?.id)
            .transition(.opacity.combined(with: .offset(y: -5)))
        }
        .animation(.easeOut(duration: 0.25), value: task?.id)
    }
}
