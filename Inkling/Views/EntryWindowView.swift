import SwiftUI
import SwiftData

/// Standalone window for viewing a single journal entry (iPad multi-window)
struct EntryWindowView: View {
    let entryUUID: String

    @Query private var entries: [JournalEntry]

    init(entryUUID: String) {
        self.entryUUID = entryUUID
        // Query the specific entry by UUID
        _entries = Query(
            filter: #Predicate<JournalEntry> {
                $0.uuid == entryUUID && $0.deletedAt == nil
            }
        )
    }

    var body: some View {
        NavigationStack {
            if let entry = entries.first {
                JournalDetailView(entry: entry)
                    .navigationTitle(DateFormatter.journalShortDate.string(from: entry.createdAt))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundStyle(.brown.opacity(0.4))
                    Text("Entry not found or has been deleted.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("JournalBackground"))
            }
        }
    }
}
