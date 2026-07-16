import Foundation

extension DateFormatter {
    /// Full date display for journal detail: e.g. "July 16, 2026"
    static let journalDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    /// Time display: e.g. "14:30"
    static let journalTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Section header: e.g. "July 2026"
    static let journalMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter
    }()

    /// Compact date + time: e.g. "Jul 16, 2026 at 14:30"
    static let journalFull: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Weekday short: e.g. "Mon"
    static let weekdayShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    /// ISO 8601 for reliable export/import: "2026-07-16T14:30:00+08:00"
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO 8601 fallback without fractional seconds
    static let iso8601Full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension Calendar {
    /// Generate all days for a given month, including padding from adjacent months
    func daysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = self.dateInterval(of: .month, for: date),
              let firstWeekInterval = self.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date] = []
        var current = firstWeekInterval.start
        let end = monthInterval.end

        // Pad from start of first week
        while current < monthInterval.start {
            days.append(current)
            current = self.date(byAdding: .day, value: 1, to: current) ?? current
        }

        // Days in the month
        while current < end {
            days.append(current)
            current = self.date(byAdding: .day, value: 1, to: current) ?? current
        }

        // Pad to end of last week
        let remaining = 7 - (days.count % 7)
        if remaining < 7 {
            for _ in 0..<remaining {
                days.append(current)
                current = self.date(byAdding: .day, value: 1, to: current) ?? current
            }
        }

        return days
    }
}
