import Foundation
import SwiftData

@Model
final class JournalEntry {
    var uuid: String = UUID().uuidString
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var content: String = ""
    /// Non-nil means the entry is in trash; nil means it's active
    var deletedAt: Date? = nil
    @Relationship(deleteRule: .cascade, inverse: \JournalPhoto.entry) var photos: [JournalPhoto]? = []

    // MARK: - Weather
    var weatherCondition: String? = nil  // WeatherCondition rawValue
    var temperature: Double? = nil       // Celsius
    var weatherLocation: String? = nil   // City name

    // MARK: - Mood & Bookmark
    var mood: String? = nil          // MoodType rawValue
    var isBookmarked: Bool = false

    // MARK: - Tags
    /// Comma-separated tag string, e.g. "旅行,工作,家人"
    var tagString: String = ""

    /// Parsed tag list (read-only)
    var tags: [String] {
        tagString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Calculate current writing streak (consecutive days with entries)
    /// Counts from today (or yesterday if today hasn't been written) backwards
    static func streak(from entries: [JournalEntry]) -> Int {
        let calendar = Calendar.current
        let activeDates = Set(entries.compactMap { entry -> Date? in
            let comps = calendar.dateComponents([.year, .month, .day], from: entry.createdAt)
            return calendar.date(from: comps)
        })

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        // Skip today if not written yet
        var date = activeDates.contains(today) ? today : yesterday
        var streak = 0

        while activeDates.contains(date) {
            streak += 1
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return streak
    }

    /// All unique tags across all entries (static helper)
    static func allTags(from entries: [JournalEntry]) -> [String] {
        var tagSet = Set<String>()
        for entry in entries {
            for tag in entry.tags {
                tagSet.insert(tag)
            }
        }
        return tagSet.sorted()
    }

    init(content: String = "", createdAt: Date = Date()) {
        self.uuid = UUID().uuidString
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.content = content
    }

    /// Whether the entry is in trash (soft-deleted)
    var isDeleted: Bool { deletedAt != nil }

    /// First meaningful line of content, used as list preview title
    var title: String {
        let firstLine = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        return String(firstLine.prefix(50))
    }

    /// Content preview for list display (first 2 lines after title)
    var preview: String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.count > 1 {
            return String(lines.dropFirst().prefix(2).joined(separator: "\n").prefix(80))
        }
        return String(content.prefix(80))
    }

    /// Word count：counts non-whitespace characters
    var wordCount: Int {
        content.filter { !$0.isWhitespace }.count
    }

    /// Whether the entry has meaningful content
    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
