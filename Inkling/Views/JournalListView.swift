//
//  JournalListView.swift
//  Inkling
//

import SwiftUI
import SwiftData

/// Main journal list with NavigationSplitView — sidebar on iPad, single column on iPhone
struct JournalListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("sortOrder") private var sortOrderRaw = SortOrder.newestFirst.rawValue
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = JournalViewModel()
    @State private var selectedEntryID: String?
    @State private var isCreatingNew = false
    @State private var composingEntry: JournalEntry?
    @State private var showDeleteAlert = false
    @State private var entryToDelete: JournalEntry?

    /// Look up the currently selected entry by its ID
    private var selectedEntry: JournalEntry? {
        guard let id = selectedEntryID else { return nil }
        return entries.first { $0.uuid == id }
    }

    private var sortOrder: SortOrder {
        SortOrder(rawValue: sortOrderRaw) ?? .newestFirst
    }

    private var sortedEntries: [JournalEntry] {
        switch sortOrder {
        case .newestFirst:
            return entries.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return entries.sorted { $0.createdAt < $1.createdAt }
        }
    }

    private var displayedEntries: [JournalEntry] {
        viewModel.filteredEntries(sortedEntries)
    }

    private var groupedEntries: [(month: Date, entries: [JournalEntry])] {
        let entries = displayedEntries
        guard !entries.isEmpty else { return [] }

        var groups: [(Date, [JournalEntry])] = []
        var currentMonth: String?
        var currentEntries: [JournalEntry] = []

        for entry in entries {
            let monthKey = DateFormatter.journalMonth.string(from: entry.createdAt)
            if monthKey != currentMonth {
                if !currentEntries.isEmpty, let month = currentEntries.first?.createdAt {
                    groups.append((month, currentEntries))
                }
                currentMonth = monthKey
                currentEntries = [entry]
            } else {
                currentEntries.append(entry)
            }
        }

        if !currentEntries.isEmpty, let month = currentEntries.first?.createdAt {
            groups.append((month, currentEntries))
        }

        return groups.map { (month: $0.0, entries: $0.1) }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .tabItem {
            Label {
                Text("tab.journal")
            } icon: {
                Image(systemName: "book.pages")
            }
        }
        .alert(
            String(localized: "journal.delete_title"),
            isPresented: $showDeleteAlert
        ) {
            Button(String(localized: "journal.delete_cancel"), role: .cancel) {
                entryToDelete = nil
            }
            Button(String(localized: "journal.delete_confirm"), role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
        } message: {
            Text("journal.delete_message")
        }
        .sheet(item: $composingEntry) { entry in
            NavigationStack {
                JournalEditView(entry: entry, onDismiss: {
                    composingEntry = nil
                    if entry.isEmpty {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                })
            }
        }
    }

    // MARK: - Sidebar
    private var sidebarContent: some View {
        Group {
            if entries.isEmpty {
                emptyStateView
            } else {
                entryListView
            }
        }
        .navigationTitle("app.name")
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "journal.search_placeholder"
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    createNewEntry()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .fontWeight(.medium)
                }
                .tint(.brown)
            }
        }
    }

    // MARK: - Detail Column
    @ViewBuilder
    private var detailContent: some View {
        if let entry = selectedEntry {
            if isCreatingNew && horizontalSizeClass == .regular {
                // iPad: show editor inline in the detail column
                JournalEditView(entry: entry, onDismiss: {
                    isCreatingNew = false
                    if entry.isEmpty {
                        modelContext.delete(entry)
                        try? modelContext.save()
                        selectedEntryID = nil
                    }
                })
                .id(entry.uuid)
            } else if isCreatingNew && horizontalSizeClass == .compact {
                // iPhone: sheet is presented, show placeholder
                emptyDetailView
            } else {
                JournalDetailView(entry: entry)
                    .id(entry.uuid)
            }
        } else {
            emptyDetailView
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundStyle(.brown.opacity(0.25))

            Text("journal.empty")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State (sidebar)
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.brown.opacity(0.4))

            Text("journal.empty")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                createNewEntry()
            } label: {
                Label("journal.new_entry", systemImage: "square.and.pencil")
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .tint(.brown)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entry List (sidebar)
    private var entryListView: some View {
        List(selection: $selectedEntryID) {
            if viewModel.isSearching && displayedEntries.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("journal.search_no_results")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(groupedEntries, id: \.month) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            JournalRowView(entry: entry)
                                .tag(entry.uuid)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteAlert = true
                                    } label: {
                                        Label("journal.delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(DateFormatter.journalMonth.string(from: group.month))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.brown)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .onChange(of: selectedEntryID) { _, _ in
            isCreatingNew = false
        }
    }

    // MARK: - Actions
    private func createNewEntry() {
        let entry = JournalEntry(createdAt: Date())
        modelContext.insert(entry)
        try? modelContext.save()

        if horizontalSizeClass == .compact {
            // iPhone: present as sheet for proper keyboard support
            composingEntry = entry
        } else {
            // iPad: show inline in the detail column
            selectedEntryID = entry.uuid
            isCreatingNew = true
        }
    }

    private func deleteEntry(_ entry: JournalEntry) {
        withAnimation {
            if selectedEntryID == entry.uuid {
                selectedEntryID = nil
                isCreatingNew = false
            }
            modelContext.delete(entry)
            try? modelContext.save()
        }
        entryToDelete = nil
    }
}

#Preview {
    JournalListView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
