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
    @AppStorage("fontStyle") private var fontStyle = FontStyle.songti.rawValue
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt == nil },
           sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = JournalViewModel()
    @State private var selectedEntryID: String?
    @State private var isCreatingNew = false
    @State private var composingEntry: JournalEntry?
    @State private var showDeleteAlert = false
    @State private var entryToDelete: JournalEntry?
    @State private var selectedTag: String? = nil
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    var initialTag: String? = nil

    /// Look up the currently selected entry by its ID
    private var selectedEntry: JournalEntry? {
        guard let id = selectedEntryID else { return nil }
        return entries.first { $0.uuid == id }
    }

    private var sortOrder: SortOrder {
        SortOrder(rawValue: sortOrderRaw) ?? .newestFirst
    }

    /// All unique tags from all entries
    private var allTags: [String] {
        JournalEntry.allTags(from: entries)
    }

    /// Entries filtered by selected tag
    private var tagFilteredEntries: [JournalEntry] {
        guard let tag = selectedTag else { return sortedEntries }
        return sortedEntries.filter { $0.tags.contains(tag) }
    }

    private var currentStreak: Int {
        JournalEntry.streak(from: entries)
    }

    private var sortedEntries: [JournalEntry] {
        switch sortOrder {
        case .newestFirst:
            return entries.sorted {
                if $0.isBookmarked != $1.isBookmarked { return $0.isBookmarked }
                return $0.createdAt > $1.createdAt
            }
        case .oldestFirst:
            return entries.sorted {
                if $0.isBookmarked != $1.isBookmarked { return $0.isBookmarked }
                return $0.createdAt < $1.createdAt
            }
        }
    }

    private var displayedEntries: [JournalEntry] {
        viewModel.filteredEntries(tagFilteredEntries)
    }

    /// Entries from previous years on this same month and day
    private var onThisDayEntries: [JournalEntry] {
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        let thisYear = Calendar.current.component(.year, from: Date())
        return entries.filter { entry in
            let comps = Calendar.current.dateComponents([.year, .month, .day], from: entry.createdAt)
            return comps.month == today.month && comps.day == today.day && (comps.year ?? thisYear) < thisYear
        }.sorted { $0.createdAt > $1.createdAt }
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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
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
                VStack(spacing: 0) {
                    // Tag filter bar
                    if !viewModel.isSearching && !allTags.isEmpty {
                        tagFilterBar
                    }
                    entryListView
                }
            }
        }
        .navigationTitle("app.name")
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "journal.search_placeholder"
        )
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                if horizontalSizeClass == .regular {
                    Button {
                        withAnimation {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .fontWeight(.medium)
                    }
                    .tint(.brown)
                }
            }
            #endif

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    createNewEntry()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .fontWeight(.medium)
                }
                .keyboardShortcut("n", modifiers: .command)
                .tint(.brown)
            }
        }
        .onAppear {
            if let initialTag, selectedTag == nil {
                selectedTag = initialTag
            }
            Task.detached { updateWidgetData() }
        }
        // Update widget when entries change
        .onChange(of: entries.count) { _, _ in
            Task.detached { updateWidgetData() }
        }
    }

    // MARK: - Tag Filter
    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTag = nil }
                } label: {
                    Text("journal.all_entries")
                        .font(.caption)
                        .fontWeight(selectedTag == nil ? .semibold : .regular)
                        .foregroundStyle(selectedTag == nil ? .white : .brown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTag == nil ? Color.brown : Color.brown.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)

                // Tag buttons
                ForEach(allTags, id: \.self) { tag in
                    let count = entries.filter { $0.tags.contains(tag) }.count
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTag = (selectedTag == tag) ? nil : tag
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.caption)
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .fontWeight(selectedTag == tag ? .semibold : .regular)
                        .foregroundStyle(selectedTag == tag ? .white : .brown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTag == tag ? Color.brown : Color.brown.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color("JournalBackground"))
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
        List {
            Section {
                dailyQuoteView
            }

            Section {
                VStack(spacing: 16) {
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .listStyle(.insetGrouped)
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
                // Streak counter
                if !viewModel.isSearching && currentStreak > 0 {
                    Section {
                        streakView
                    }
                }

                // Daily writing prompt
                if !viewModel.isSearching {
                    Section {
                        dailyQuoteView
                    }
                }

                // On This Day
                if !viewModel.isSearching && !onThisDayEntries.isEmpty {
                    Section {
                        ForEach(onThisDayEntries) { entry in
                            JournalRowView(entry: entry, searchText: viewModel.searchText)
                                .tag(entry.uuid)
                                .contextMenu {
                                    Button {
                                        toggleBookmark(entry)
                                    } label: {
                                        Label(
                                            entry.isBookmarked
                                                ? String(localized: "a11y.unbookmark")
                                                : String(localized: "a11y.bookmark"),
                                            systemImage: entry.isBookmarked ? "bookmark.slash" : "bookmark"
                                        )
                                    }
                                }
                                .listRowBackground(
                                    Color.brown.opacity(0.04)
                                )
                        }
                    } header: {
                        onThisDayHeader
                    }
                }

                ForEach(groupedEntries, id: \.month) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            JournalRowView(entry: entry, searchText: viewModel.searchText)
                                .tag(entry.uuid)
                                .contextMenu {
                                    Button {
                                        toggleBookmark(entry)
                                    } label: {
                                        Label(
                                            entry.isBookmarked
                                                ? String(localized: "a11y.unbookmark")
                                                : String(localized: "a11y.bookmark"),
                                            systemImage: entry.isBookmarked ? "bookmark.slash" : "bookmark"
                                        )
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteAlert = true
                                    } label: {
                                        Label(String(localized: "journal.delete"), systemImage: "trash")
                                    }
                                }
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

    // MARK: - Streak
    private var streakView: some View {
        HStack(spacing: 8) {
            Text(streakEmoji)
                .font(.title3)
            Text(String(format: String(localized: "journal.streak_days"), currentStreak))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.brown)
            Spacer()
        }
        .listRowBackground(Color.brown.opacity(0.04))
    }

    private var streakEmoji: String {
        switch currentStreak {
        case 1...2: return "🔥"
        case 3...6: return "🔥🔥"
        case 7...13: return "🔥🔥🔥"
        default: return "🔥🔥🔥🔥"
        }
    }

    // MARK: - Daily Quote & On This Day
    private var dailyQuoteView: some View {
        let quote = DailyQuote.today()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.caption)
                    .foregroundStyle(.brown.opacity(0.5))
                Text("journal.daily_prompt")
                    .font(.caption)
                    .foregroundStyle(.brown.opacity(0.5))
                    .textCase(nil)
            }

            Text(quote)
                .font((FontStyle(rawValue: fontStyle) ?? .songti).makeFont(size: 15))
                .foregroundStyle(.secondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }

    private var onThisDayHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .foregroundStyle(.brown)
            Text("journal.on_this_day")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.brown)
                .textCase(nil)
            Text("· \(onThisDayEntries.count)")
                .font(.caption)
                .foregroundStyle(.brown.opacity(0.6))
        }
    }

    // MARK: - Widget
    private func updateWidgetData() {
        let streak = JournalEntry.streak(from: entries)
        let today = Calendar.current.startOfDay(for: Date())
        let hasWritten = entries.contains {
            Calendar.current.isDate($0.createdAt, inSameDayAs: today)
        }
        WidgetDataManager.update(streak: streak, hasWrittenToday: hasWritten, prompt: DailyQuote.today())
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
            entry.deletedAt = Date()
            try? modelContext.save()
        }
        entryToDelete = nil
    }

    private func toggleBookmark(_ entry: JournalEntry) {
        withAnimation {
            entry.isBookmarked.toggle()
            try? modelContext.save()
        }
    }
}

#Preview {
    JournalListView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
