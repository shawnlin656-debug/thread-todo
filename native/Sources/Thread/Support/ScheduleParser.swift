import Foundation

/// Pulls a start time out of typed text, so "3pm 写周报" or "写周报 3:30 PM" schedules a task
/// without reaching for the time picker.
///
/// Accepted time forms, at the start or the end of the text:
/// - with a meridiem, which is exact: `3pm`, `3 PM`, `3:30pm`, `3:30 am`
/// - a bare `H:mm`, which is read as the soonest future match (see ``nextOccurrence``)
///
/// A bare number without a colon or a meridiem ("买 iPhone 15") is never treated as a time.
nonisolated enum ScheduleParser {
    struct Result: Equatable {
        let title: String
        let date: Date
    }

    /// - Returns: The title without its time and the next moment that time occurs, or `nil`
    ///   when the text carries no recognizable time or nothing but a time.
    static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> Result? {
        let leading = /^(\d{1,2})(?:[:：](\d{2}))?\s*([aApP][mM])?\s+(.+)$/
        let trailing = /^(.+?)\s+(\d{1,2})(?:[:：](\d{2}))?\s*([aApP][mM])?$/

        let hourText: Substring, minuteText: Substring?, meridiem: Substring?, title: Substring
        if let match = text.wholeMatch(of: leading) {
            (hourText, minuteText, meridiem, title) = (match.1, match.2, match.3, match.4)
        } else if let match = text.wholeMatch(of: trailing) {
            (title, hourText, minuteText, meridiem) = (match.1, match.2, match.3, match.4)
        } else {
            return nil
        }
        // A lone number is just part of the title.
        guard minuteText != nil || meridiem != nil else { return nil }
        guard let hour = Int(hourText), let minute = minuteText.map({ Int($0) }) ?? 0 else { return nil }

        let date: Date?
        if let meridiem, (1...12).contains(hour) {
            // 12 am is midnight and 12 pm is noon; every other hour shifts by 12 in the afternoon.
            let isAfternoon = meridiem.lowercased() == "pm"
            date = exactOccurrence(hour: hour % 12 + (isAfternoon ? 12 : 0), minute: minute, after: now, calendar: calendar)
        } else {
            // "15:00 pm" lands here too: the 24-hour reading wins over a contradictory meridiem.
            date = nextOccurrence(hour: hour, minute: minute, after: now, calendar: calendar)
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard let date, !cleanTitle.isEmpty else { return nil }
        return Result(title: cleanTitle, date: date)
    }

    /// The soonest future moment the clock reads `hour:minute`, for a time typed without am or pm.
    ///
    /// Hours from 1 to 11 are read on a 12-hour clock: at 2:25 pm, "3:00" means 3 pm today,
    /// not 3 am tomorrow. 12 always means noon, and 0 and 13 upward are unambiguous.
    static func nextOccurrence(hour: Int, minute: Int, after now: Date, calendar: Calendar = .current) -> Date? {
        let hours = (1...11).contains(hour) ? [hour, hour + 12] : [hour]
        return hours.compactMap { exactOccurrence(hour: $0, minute: minute, after: now, calendar: calendar) }.min()
    }

    /// The next moment the 24-hour clock reads `hour:minute`: later today, or else tomorrow.
    private static func exactOccurrence(hour: Int, minute: Int, after now: Date, calendar: Calendar) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, second: 0), matchingPolicy: .nextTime)
    }
}
