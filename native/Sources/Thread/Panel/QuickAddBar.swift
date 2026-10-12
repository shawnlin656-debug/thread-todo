import AppKit
import SwiftUI

/// The input at the foot of the panel. Return starts the task immediately, interrupting
/// the current one; Shift-Return queues it for later.
struct QuickAddBar: View {
    @Environment(TaskStore.self) private var store
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)

                // `onSubmit` rather than a key handler: it only fires after an input method
                // has committed its text, so confirming a Chinese candidate never submits.
                TextField("插入临时任务", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($isFocused)
                    .onSubmit(submit)

                Button("插队", action: submit)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color.accentColor, in: .capsule)
                    .opacity(trimmedTitle.isEmpty ? 0.5 : 1)
                    .disabled(trimmedTitle.isEmpty)
            }
            .padding(EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 5))
            .background(.quaternary, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.accentColor, lineWidth: isFocused ? 1.5 : 0) }
            .contentShape(.capsule)
            .onTapGesture { isFocused = true }

            Text("↵ 插队，当前任务保留在返回路径 · ⇧↵ 排到接下来")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 13, trailing: 14))
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        let newTitle = trimmedTitle
        guard !newTitle.isEmpty else { return }
        title = ""
        if NSEvent.modifierFlags.contains(.shift) {
            store.enqueue(newTitle)
        } else {
            store.interrupt(with: newTitle)
        }
    }
}
