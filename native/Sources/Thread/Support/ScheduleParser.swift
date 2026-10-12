import Foundation

/// Pulls a start time out of typed text, so "3:00 写周报" or "写周报 15:00" schedules a task
/// without reaching for the time picker.
nonisolated enum ScheduleParser {
    struct Result: Equatable {
        let title: String
        let date: Date
    }

    /// - Returns: The title without its time and the next moment that time occurs, or `nil`
    ///   when the text has no leading or trailing "H:mm".
    static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> Result? {
        let leading = /^(\d{1,2})[:：](\d{2})\s+(.+)$/
        let trailing = /^(.+?)\s+(\d{1,2})[:：](\d{2})$/

        let hour: Int, minute: Int, title: String
        if let match = text.wholeMatch(of: leading), let h = Int(match.1), let m = Int(match.2) {
            (hour, minute, title) = (h, m, String(match.3))
        } else if let match = text.wholeMatch(of: trailing), let h = Int(match.2), let m = Int(match.3) {
            (hour, minute, title) = (h, m, String(match.1))
        } else {
            return nil
        }
        guard let date = nextOccurrence(hour: hour, minute: minute, after: now, calendar: calendar) else { return nil }
        return Result(title: title.trimmingCharacters(in: .whitespaces), date: date)
    }

    /// The soonest future moment the clock reads `hour:minute`.
    ///
    /// Hours from 1 to 11 are read on a 12-hour clock: at 2:25 pm, "3:00" means 3 pm today,
    /// not 3 am tomorrow. 12 always means noon, and 0 and 13 upward are unambiguous.
    static func nextOccurrence(hour: Int, minute: Int, after now: Date, calendar: Calendar = .current) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        let hours = (1...11).contains(hour) ? [hour, hour + 12] : [hour]
        return hours
            .compactMap { calendar.nextDate(after: now, matching: DateComponents(hour: $0, minute: minute, second: 0), matchingPolicy: .nextTime) }
            .min()
    }
}
