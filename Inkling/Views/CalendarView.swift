import SwiftUI
import SwiftData

/// Calendar view showing a monthly grid with dates that have journal entries highlighted
struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]

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
            ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                let hasEntry = entryDates.contains(where: { calendar.isDate($0, inSameDayAs: date) })
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
                                isSelected: isSelected
                            ))

                        // Entry indicator dot
                        if hasEntry && isCurrentMonth {
                            Circle()
                                .fill(Color.brown.opacity(isSelected ? 1 : 0.6))
                                .frame(width: 5, height: 5)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.brown.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }

    private func dayColor(isCurrentMonth: Bool, isToday: Bool, isSelected: Bool) -> Color {
        if !isCurrentMonth {
            return .clear
        }
        if isToday {
            return .brown
        }
        if isSelected {
            return .brown
        }
        return .primary
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
