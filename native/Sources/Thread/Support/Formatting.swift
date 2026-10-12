import Foundation

/// Text formatting shared by the side panel and the notch island.
nonisolated enum Formatting {
    /// Focus time as "mm:ss", or "h:mm:ss" once it passes an hour.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    /// Wall-clock time as 24-hour "HH:mm", regardless of the system's 12/24-hour setting.
    static func timeOfDay(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Coarse relative time: "刚刚", "12 分钟前", "3 小时前" or "2 天前".
    static func ago(_ date: Date?, now: Date = .now) -> String {
        guard let date else { return "刚刚" }
        let minutes = Int(now.timeIntervalSince(date) / 60)
        switch minutes {
        case ..<1: return "刚刚"
        case ..<60: return "\(minutes) 分钟前"
        case ..<(60 * 24): return "\(minutes / 60) 小时前"
        default: return "\(minutes / (60 * 24)) 天前"
        }
    }
}
