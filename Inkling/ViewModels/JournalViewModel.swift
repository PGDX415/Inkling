import Foundation
import SwiftData
import SwiftUI

/// Sort order for journal entries
enum SortOrder: String, CaseIterable {
    case newestFirst
    case oldestFirst

    var localizedName: LocalizedStringKey {
        switch self {
        case .newestFirst: return "settings.sort_newest"
        case .oldestFirst: return "settings.sort_oldest"
        }
    }

    var sortDescriptor: SortDescriptor<JournalEntry> {
        switch self {
        case .newestFirst:
            return SortDescriptor(\.createdAt, order: .reverse)
        case .oldestFirst:
            return SortDescriptor(\.createdAt, order: .forward)
        }
    }
}

/// View model for journal-related operations
@Observable
final class JournalViewModel {
    var searchText = ""
    var isSearching = false
    var selectedDate: Date?

    /// Search results filtered in-memory from all entries
    func filteredEntries(_ entries: [JournalEntry]) -> [JournalEntry] {
        guard !searchText.isEmpty else { return entries }
        isSearching = true
        let results = entries.filter { entry in
            entry.content.localizedCaseInsensitiveContains(searchText)
        }
        return results
    }

    /// Highlight search terms in a text string
    func highlightSearchTerms(in text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard !searchText.isEmpty else { return attributed }

        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()

        var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
        while let range = lowercasedText.range(
            of: lowercasedSearch,
            options: .caseInsensitive,
            range: searchRange
        ) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let length = text.distance(from: range.lowerBound, to: range.upperBound)

            if let attrRange = Range(
                NSRange(location: start, length: length),
                in: attributed
            ) {
                attributed[attrRange].backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
                attributed[attrRange].foregroundColor = .primary
                attributed[attrRange].font = .body.bold()
            }

            searchRange = range.upperBound..<lowercasedText.endIndex
        }

        return attributed
    }

    /// Reset search state
    func clearSearch() {
        searchText = ""
        isSearching = false
    }
}
