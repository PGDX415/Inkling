import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt != nil },
           sort: \JournalEntry.deletedAt, order: .reverse) private var trashedEntries: [JournalEntry]
    @State private var showEmptyTrashAlert = false

    private let retentionDays = 30

    var body: some View {
        List {
            if trashedEntries.isEmpty {
                emptyTrashView
            } else {
                Section {
                    ForEach(trashedEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(DateFormatter.journalShortDate.string(from: entry.createdAt))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(entry.createdAt, style: .time)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()

                                // Days remaining
                                if let deletedAt = entry.deletedAt {
                                    let remaining = remainingDays(deletedAt)
                                    Text(String(format: String(localized: "trash.remaining"), remaining))
                                        .font(.caption)
                                        .foregroundStyle(remaining <= 3 ? .red : .secondary)
                                }
                            }

                            if !entry.title.isEmpty {
                                Text(entry.title)
                                    .font(.body)
                                    .lineLimit(1)
                            }

                            if !entry.preview.isEmpty {
                                Text(entry.preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .leading) {
                            Button {
                                restoreEntry(entry)
                            } label: {
                                Label("trash.restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.brown)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                permanentlyDelete(entry)
                            } label: {
                                Label("trash.delete_forever", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    if !trashedEntries.isEmpty {
                        Text(String(format: String(localized: "trash.header"), trashedEntries.count, retentionDays))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("trash.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !trashedEntries.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showEmptyTrashAlert = true
                    } label: {
                        Text("trash.empty")
                    }
                }
            }
        }
        .alert("trash.empty_confirm", isPresented: $showEmptyTrashAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("trash.empty", role: .destructive) { emptyTrash() }
        } message: {
            Text("trash.empty_message")
        }
        .onAppear { purgeExpired() }
    }

    private var emptyTrashView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 40))
                .foregroundStyle(.brown.opacity(0.3))

            Text("trash.empty")
                .font(.body)
                .foregroundStyle(.secondary)

            Text(String(format: String(localized: "trash.retention_hint"), retentionDays))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }

    // MARK: - Helpers
    private func remainingDays(_ deletedAt: Date) -> Int {
        let expiration = Calendar.current.date(byAdding: .day, value: retentionDays, to: deletedAt) ?? deletedAt
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
        return max(0, days)
    }

    private func restoreEntry(_ entry: JournalEntry) {
        withAnimation {
            entry.deletedAt = nil
            try? modelContext.save()
        }
    }

    private func permanentlyDelete(_ entry: JournalEntry) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func emptyTrash() {
        withAnimation {
            for entry in trashedEntries {
                modelContext.delete(entry)
            }
            try? modelContext.save()
        }
    }

    /// Remove entries that have been in trash longer than retention period
    private func purgeExpired() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let expired = trashedEntries.filter { entry in
            guard let deletedAt = entry.deletedAt else { return false }
            return deletedAt < cutoff
        }
        for entry in expired {
            modelContext.delete(entry)
        }
        if !expired.isEmpty {
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        TrashView()
    }
}
