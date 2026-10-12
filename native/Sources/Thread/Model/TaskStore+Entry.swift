import Foundation

/// What a line of typed text will turn into. Shared by the quick-entry window and the
/// side panel's input so both read the text the same way.
extension TaskStore {
    enum Entry: Equatable {
        /// Start right away, parking the current task on the return path.
        case interrupt(title: String)
        /// Add to the queue without disturbing the current task.
        case enqueue(title: String)
        /// Take over at `date`.
        case schedule(title: String, date: Date)
    }

    /// Interpret typed text. A time in the text always schedules; otherwise `queued` picks
    /// between queueing and starting now.
    /// - Returns: `nil` for blank text.
    static func entry(for text: String, queued: Bool, now: Date = .now) -> Entry? {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        if let scheduled = ScheduleParser.parse(title, now: now) {
            return .schedule(title: scheduled.title, date: scheduled.date)
        }
        return queued ? .enqueue(title: title) : .interrupt(title: title)
    }

    /// Carry out an interpreted entry.
    func add(_ entry: Entry) {
        switch entry {
        case .interrupt(let title): interrupt(with: title)
        case .enqueue(let title): enqueue(title)
        case .schedule(let title, let date): schedule(title, at: date)
        }
    }
}
