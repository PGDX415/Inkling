import SwiftUI

/// A single journal entry row in the list
struct JournalRowView: View {
    let entry: JournalEntry
    var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date & Time
            HStack {
                HStack(spacing: 4) {
                    Text(DateFormatter.journalShortDate.string(from: entry.createdAt))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(entry.createdAt, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(DateFormatter.weekdayShort.string(from: entry.createdAt))
                        .font(.subheadline)
                        .foregroundStyle(.brown)
                }

                Spacer()

                // Photo indicator
                if let photos = entry.photos, !photos.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "photo")
                            .font(.caption2)
                        Text("\(photos.count)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.brown.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brown.opacity(0.08))
                    )
                }

                // Word count badge
                Text("\(entry.wordCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }

            // Title (first line)
            titleView

            // Content preview
            previewView
        }
        .padding(.vertical, 6)
    }

    // MARK: - Title with optional search highlight
    @ViewBuilder
    private var titleView: some View {
        if !entry.title.isEmpty {
            Text(JournalViewModel.highlightSearchTerms(
                in: entry.title,
                query: searchText,
                font: .headline.weight(.regular),
                foregroundColor: .primary
            ))
            .lineLimit(1)
        } else {
            Text("(Untitled)")
                .font(.headline)
                .fontWeight(.regular)
                .foregroundStyle(.tertiary)
                .italic()
        }
    }

    // MARK: - Preview with optional search highlight
    @ViewBuilder
    private var previewView: some View {
        if !entry.preview.isEmpty {
            Text(JournalViewModel.highlightSearchTerms(
                in: entry.preview,
                query: searchText,
                font: .subheadline,
                foregroundColor: .secondary
            ))
            .lineLimit(2)
            .lineSpacing(4)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let entry = JournalEntry(
        content: "Today was a beautiful day.\nI took a long walk by the river and watched the sunset. The colors were magnificent.",
        createdAt: Date()
    )
    return JournalRowView(entry: entry)
        .padding()
}
