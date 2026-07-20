import Foundation
import SwiftData

@Model
final class JournalEntry {
    var uuid: String = UUID().uuidString
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var content: String = ""
    @Relationship(deleteRule: .cascade, inverse: \JournalPhoto.entry) var photos: [JournalPhoto]? = []

    init(content: String = "", createdAt: Date = Date()) {
        self.uuid = UUID().uuidString
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.content = content
    }

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
