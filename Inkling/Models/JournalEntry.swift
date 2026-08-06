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

    /// Cached display values — updated once on save, not recomputed every render
    var displayTitle: String = ""
    var displayPreview: String = ""
    var displayWordCount: Int = 0
    /// Cached parsed tags (stored as JSON string for SwiftData compatibility)
    var cachedTagsJSON: String = "[]"

    /// Parsed tag list from cache
    var tags: [String] {
        guard let data = cachedTagsJSON.data(using: .utf8),
              let result = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return result
    }

    /// Refresh all cached display values from content and tagString.
    /// Call before modelContext.save() in the editor.
    func refreshDisplayCache() {
        // Title: first non-empty line, max 50 chars
        let firstLine = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        displayTitle = String(firstLine.prefix(50))

        // Preview: up to 2 lines after title, max 80 chars
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.count > 1 {
            displayPreview = String(lines.dropFirst().prefix(2).joined(separator: "\n").prefix(80))
        } else {
            displayPreview = String(content.prefix(80))
        }

        // Word count: non-whitespace characters
        displayWordCount = content.filter { !$0.isWhitespace }.count

        // Tags
        let parsedTags = tagString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let data = try? JSONEncoder().encode(parsedTags),
           let json = String(data: data, encoding: .utf8) {
            cachedTagsJSON = json
        }
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

    /// Cached title — first meaningful line of content
    var title: String { displayTitle.isEmpty ? String(content.prefix(50)) : displayTitle }

    /// Cached preview for list display
    var preview: String { displayPreview.isEmpty ? String(content.prefix(80)) : displayPreview }

    /// Cached word count
    var wordCount: Int { displayWordCount > 0 ? displayWordCount : content.filter { !$0.isWhitespace }.count }

    /// Whether the entry has meaningful content
    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
