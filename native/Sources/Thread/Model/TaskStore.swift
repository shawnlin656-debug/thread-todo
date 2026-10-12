import Foundation
import Observation

/// The app's single source of truth: one focused task plus the lists around it.
///
/// Every mutation goes through a method here, and every method ends by saving, so
/// the views never touch persistence and the file on disk is always current.
@Observable
final class TaskStore {
    /// The task being worked on, or `nil` when idle.
    private(set) var current: TaskItem?
    /// The return path: tasks parked by an interruption, most recent first.
    private(set) var interrupted: [TaskItem] = []
    /// Tasks planned for later, in order.
    private(set) var queue: [TaskItem] = []
    /// Tasks completed and not yet cleared.
    private(set) var done: [TaskItem] = []
    /// Whether the side panel is reduced to its rail.
    var isCollapsed = false { didSet { save() } }

    /// Start of the current uninterrupted run; `nil` when idle.
    private(set) var runningSince: Date?
    /// Increments each time a task is parked by an interruption. The notch island watches
    /// this to flash the task the user will be returning to.
    private(set) var interruptionCount = 0

    private let fileURL: URL

    static let defaultType = "临时任务"
    static let interruptNote = "临时插队 · 完成后会自动回到上一件事。"

    init(fileURL: URL = TaskStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    // MARK: - Derived values

    /// The task the user goes back to when the current one is finished.
    var returnTarget: TaskItem? { interrupted.first }

    /// Seconds of focus on the current task, including the run in progress.
    func elapsed(at now: Date = .now) -> TimeInterval {
        guard let current else { return 0 }
        return current.accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    // MARK: - Actions

    /// Start a brand-new task immediately, parking the current one.
    func interrupt(with title: String) {
        focus(on: TaskItem(title: title, note: Self.interruptNote, type: Self.defaultType))
    }

    /// Add a new task to the end of the queue without touching the current focus.
    func enqueue(_ title: String) {
        queue.append(TaskItem(title: title, type: Self.defaultType, addedAt: .now))
        save()
    }

    /// Start a queued task now.
    func startQueued(_ id: TaskItem.ID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        focus(on: queue.remove(at: index))
    }

    /// Switch to a parked task; the current one takes its place on the return path.
    func resume(_ id: TaskItem.ID) {
        guard let index = interrupted.firstIndex(where: { $0.id == id }) else { return }
        let task = interrupted.remove(at: index)
        parkCurrent()
        current = task
        runningSince = .now
        save()
    }

    /// Finish the current task and fall back to the most recently interrupted one, if any.
    func completeCurrent() {
        guard var finished = current else { return }
        finished.accumulated = elapsed()
        finished.completedAt = .now
        done.insert(finished, at: 0)

        current = interrupted.isEmpty ? nil : interrupted.removeFirst()
        runningSince = current == nil ? nil : .now
        save()
    }

    /// Set the current task aside without finishing it, leaving the app idle.
    func pauseCurrent() {
        guard current != nil else { return }
        parkCurrent()
        save()
    }

    /// Remove a task from whichever waiting list holds it.
    func delete(_ id: TaskItem.ID) {
        interrupted.removeAll { $0.id == id }
        queue.removeAll { $0.id == id }
        done.removeAll { $0.id == id }
        save()
    }

    func clearDone() {
        done.removeAll()
        save()
    }

    /// Give `task` the focus, parking whatever was in progress so it can be resumed.
    private func focus(on task: TaskItem) {
        let interrupting = current != nil
        parkCurrent()

        var task = task
        task.startedAt = task.startedAt ?? .now
        current = task
        runningSince = .now
        if interrupting { interruptionCount += 1 }
        save()
    }

    /// Move the current task to the top of the return path, banking its running time.
    private func parkCurrent() {
        guard var task = current else { return }
        task.accumulated = elapsed()
        task.interruptedAt = .now
        interrupted.insert(task, at: 0)
        current = nil
        runningSince = nil
    }

    // MARK: - Persistence

    /// On-disk shape. Kept separate from the store so observation-only fields stay out of the file.
    private nonisolated struct Snapshot: Codable {
        var current: TaskItem?
        var interrupted: [TaskItem]
        var queue: [TaskItem]
        var done: [TaskItem]
        var isCollapsed: Bool
    }

    /// `~/Library/Application Support/Thread/state.json`, unless `THREAD_STATE_FILE` points
    /// elsewhere (used to try the app against sample data without touching real tasks).
    static var defaultFileURL: URL {
        if let override = ProcessInfo.processInfo.environment["THREAD_STATE_FILE"] {
            return URL(fileURLWithPath: override)
        }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thread", isDirectory: true)
        return directory.appendingPathComponent("state.json")
    }

    /// Write the state to disk. Also called on a timer and at quit so a crash loses
    /// at most a few seconds of focus time.
    func save() {
        // Bank the run in progress into the snapshot only; the live state keeps counting from `runningSince`.
        var running = current
        running?.accumulated = elapsed()
        let snapshot = Snapshot(current: running, interrupted: interrupted, queue: queue, done: done, isCollapsed: isCollapsed)

        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Thread: could not save state: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            current = snapshot.current
            interrupted = snapshot.interrupted
            queue = snapshot.queue
            done = snapshot.done
            isCollapsed = snapshot.isCollapsed
            // Time the app spent closed is not focus time: the clock restarts from launch.
            runningSince = current == nil ? nil : .now
        } catch {
            NSLog("Thread: ignoring unreadable state file: \(error.localizedDescription)")
        }
    }
}
