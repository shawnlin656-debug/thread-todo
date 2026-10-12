import AppKit
import SwiftUI

/// The input at the foot of the panel. Return starts the task immediately, interrupting
/// the current one; Shift-Return queues it for later.
struct QuickAddBar: View {
    @Environment(TaskStore.self) private var store
    @Environment(PanelPresentation.self) private var presentation
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // `onSubmit` rather than a key handler: it only fires after an input method
            // has committed its text, so confirming a Chinese candidate never submits.
            TextField("插入临时任务", text: $title)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .focused($isFocused)
                .onSubmit(submit)
                // Escape hands the keyboard back and lets the panel tuck away again.
                .onExitCommand { isFocused = false }

            Text("↩ 立即开始，当前任务进入返回路径　⇧↩ 排到接下来")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        // Keep the panel open for as long as the user is typing in it.
        .onChange(of: isFocused) { presentation.isEditing = isFocused }
        .onChange(of: presentation.isWindowKey) {
            if !presentation.isWindowKey { isFocused = false }
        }
    }

    private func submit() {
        let newTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { return }
        title = ""
        if NSEvent.modifierFlags.contains(.shift) {
            store.enqueue(newTitle)
        } else {
            store.interrupt(with: newTitle)
        }
    }
}
