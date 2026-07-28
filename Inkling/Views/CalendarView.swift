import SwiftUI
import SwiftData

/// Calendar view showing a monthly grid with dates that have journal entries highlighted
struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt == nil },
           sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]

    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    /// Set of dates that have at least one journal entry
    private var entryDates: Set<Date> {
        var dates = Set<Date>()
        for entry in allEntries {
            let components = calendar.dateComponents([.year, .month, .day], from: entry.createdAt)
            if let date = calendar.date(from: components) {
                dates.insert(date)
            }
        }
        return dates
    }

    /// Number of entries per day
    private var entryCounts: [Date: Int] {
        var counts: [Date: Int] = [:]
        for entry in allEntries {
            let components = calendar.dateComponents([.year, .month, .day], from: entry.createdAt)
            if let date = calendar.date(from: components) {
                counts[date, default: 0] += 1
            }
        }
        return counts
    }

    /// Total entries in the current month
    private var currentMonthEntryCount: Int {
        allEntries.filter {
            calendar.isDate($0.createdAt, equalTo: currentMonth, toGranularity: .month)
        }.count
    }

    /// Entries for the currently selected date
    private var entriesForSelectedDate: [JournalEntry] {
        guard let selectedDate else { return [] }
        return allEntries.filter { entry in
            calendar.isDate(entry.createdAt, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation
                monthNavigation

                // Weekday headers
                weekdayHeaders

                // Calendar grid
                calendarGrid

                // Heatmap legend
                heatmapLegend

                // Month stats
                monthStats

                Divider()
                    .padding(.vertical, 8)

                // Entries for selected date
                selectedDateEntries
            }
            .navigationTitle("calendar.title")
        }
        .tabItem {
            Label {
                Text("tab.calendar")
            } icon: {
                Image(systemName: "calendar")
            }
        }
    }

    // MARK: - Month Navigation
    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.medium)
            }
            .tint(.brown)

            Spacer()

            VStack(spacing: 2) {
                Text(DateFormatter.journalMonth.string(from: currentMonth))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Button {
                    withAnimation {
                        currentMonth = Date()
                        selectedDate = nil
                    }
                } label: {
                    Text("journal.today")
                        .font(.caption)
                        .foregroundStyle(.brown)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.medium)
            }
            .tint(.brown)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Weekday Headers
    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let days = calendar.daysInMonth(for: currentMonth)

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                let count = entryCounts[date] ?? 0
                let hasEntry = count > 0
                let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                let isToday = calendar.isDateInToday(date)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!) {
                            selectedDate = nil
                        } else {
                            selectedDate = date
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(.body, design: .serif))
                            .fontWeight(isToday ? .bold : .regular)
                            .foregroundStyle(dayColor(
                                isCurrentMonth: isCurrentMonth,
                                isToday: isToday,
                                isSelected: isSelected,
                                hasEntry: hasEntry
                            ))

                        // Entry count indicator
                        if hasEntry && isCurrentMonth {
                            Text("\(count)")
                                .font(.system(size: 9))
                                .foregroundStyle(dayColor(
                                    isCurrentMonth: isCurrentMonth,
                                    isToday: isToday,
                                    isSelected: isSelected,
                                    hasEntry: true
                                ))
                        } else {
                            Text(" ")
                                .font(.system(size: 9))
                        }
                    }
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(cellBackground(isCurrentMonth: isCurrentMonth, count: count, isSelected: isSelected))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }

    /// Heatmap color based on entry count
    private func cellBackground(isCurrentMonth: Bool, count: Int, isSelected: Bool) -> Color {
        if isSelected { return Color.brown.opacity(0.2) }
        if !isCurrentMonth { return Color.clear }
        switch count {
        case 0: return Color.brown.opacity(0.04)
        case 1: return Color.brown.opacity(0.15)
        case 2: return Color.brown.opacity(0.3)
        case 3: return Color.brown.opacity(0.45)
        default: return Color.brown.opacity(0.6)
        }
    }

    private func dayColor(isCurrentMonth: Bool, isToday: Bool, isSelected: Bool, hasEntry: Bool) -> Color {
        if !isCurrentMonth {
            return .clear
        }
        if isToday {
            return .brown
        }
        if isSelected {
            return .brown
        }
        return hasEntry ? .primary : .secondary
    }

    // MARK: - Heatmap Legend
    private var heatmapLegend: some View {
        HStack(spacing: 12) {
            Text("calendar.less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach([0, 1, 2, 3, 4], id: \.self) { level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(cellBackground(isCurrentMonth: true, count: level, isSelected: false))
                    .frame(width: 14, height: 14)
            }
            Text("calendar.more")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Month Stats
    private var monthStats: some View {
        HStack(spacing: 16) {
            Label("\(currentMonthEntryCount) \(String(localized: "calendar.entries_count_simple"))", systemImage: "book.pages")
                .font(.caption)
                .foregroundStyle(.secondary)

            let activeDays = entryCounts.filter { date, count in
                calendar.isDate(date, equalTo: currentMonth, toGranularity: .month) && count > 0
            }.count
            Label(String(format: String(localized: "calendar.days"), activeDays), systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Selected Date Entries
    @ViewBuilder
    private var selectedDateEntries: some View {
        if let selectedDate {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(selectedDate, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.brown)

                    Spacer()

                    Text(String(format: String(localized: "calendar.entries_count"), entriesForSelectedDate.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                if entriesForSelectedDate.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .font(.title2)
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("calendar.no_entries")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    List {
                        ForEach(entriesForSelectedDate) { entry in
                            NavigationLink {
                                JournalDetailView(entry: entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.createdAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if !entry.title.isEmpty {
                                        Text(entry.title)
                                            .font(.body)
                                            .lineLimit(1)
                                    }

                                    if !entry.preview.isEmpty {
                                        Text(entry.preview)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
