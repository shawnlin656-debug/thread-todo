import AppKit
import SwiftUI

/// The input at the foot of the panel.
///
/// - Return starts the task immediately, interrupting the current one.
/// - Shift-Return queues it for later.
/// - A time in the text ("3pm 写周报"), or the clock button, schedules it to take over then.
///
/// The ⌃⌥Space quick-entry window reads text by the same rules; see `TaskStore.entry(for:queued:now:)`.
struct QuickAddBar: View {
    @Environment(TaskStore.self) private var store
    @Environment(PanelPresentation.self) private var presentation
    @State private var title = ""
    @State private var isPickingTime = false
    @State private var pickedTime = Date.now
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // `onSubmit` rather than a key handler: it only fires after an input method
                // has committed its text, so confirming a Chinese candidate never submits.
                TextField("插入临时任务", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .focused($isFocused)
                    .onSubmit(submit)
                    // Escape hands the keyboard back and lets the panel tuck away again.
                    .onExitCommand(perform: dismiss)

                Button {
                    // Offer the next round half hour as a starting point.
                    pickedTime = Self.nextHalfHour(after: .now)
                    isPickingTime = true
                } label: {
                    Image(systemName: "clock")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("定时开始")
                .accessibilityLabel("定时开始")
                .popover(isPresented: $isPickingTime, arrowEdge: .top) { timePicker }
            }

            Text("↩ 立即开始　⇧↩ 排到接下来　写上时间（如 3pm）定时开始")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        // Keep the panel open for as long as the user is typing in it or choosing a time.
        .onChange(of: isFocused) { presentation.isEditing = isFocused }
        .onChange(of: isPickingTime) { presentation.isShowingPopover = isPickingTime }
        .onChange(of: presentation.isWindowKey) {
            if !presentation.isWindowKey { isFocused = false }
        }
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("开始时间", selection: $pickedTime, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                .environment(\.locale, Self.twelveHourLocale)
            Text("到点后当前任务会自动暂停并保留在返回路径。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("取消") { isPickingTime = false }
                Button("定时开始") {
                    store.schedule(trimmedTitle, at: pickedTime)
                    title = ""
                    isPickingTime = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedTitle.isEmpty)
            }
            if trimmedTitle.isEmpty {
                Text("先在输入框里写下任务名称。").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard let entry = TaskStore.entry(for: title, queued: NSEvent.modifierFlags.contains(.shift)) else { return }
        title = ""
        store.add(entry)
        dismiss()
    }

    /// Give the keyboard back to the app the user came from.
    private func dismiss() {
        isFocused = false
        presentation.relinquishKeyboard()
    }

    /// The user's locale with the clock forced to 12 hours, so the picker shows AM/PM
    /// like every other time in the app.
    private static let twelveHourLocale: Locale = {
        var components = Locale.Components(locale: .current)
        components.hourCycle = .oneToTwelve
        return Locale(components: components)
    }()

    private static func nextHalfHour(after date: Date) -> Date {
        let step: TimeInterval = 30 * 60
        return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / step).rounded(.up) * step)
    }
}
