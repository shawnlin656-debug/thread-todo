import Foundation

/// One unit of work. The same value moves between the store's lists as its status changes.
nonisolated struct TaskItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    /// One-line reminder of where the work stands.
    var note: String?
    /// Short category label shown as a chip, e.g. "临时任务".
    var type: String
    /// Seconds of focus accumulated before the current run started.
    var accumulated: TimeInterval = 0
    /// Planned duration in minutes.
    var estimateMinutes: Int?

    /// When the task should take over automatically; set only for scheduled tasks.
    var scheduledAt: Date?
    var addedAt: Date?
    /// When the task first took focus.
    var startedAt: Date?
    /// When the task was last parked on the return path.
    var interruptedAt: Date?
    var completedAt: Date?
}
