import SwiftUI
import SwiftData

/// Writing statistics dashboard with charts and insights
struct StatsView: View {
    @Query(filter: #Predicate<JournalEntry> { $0.deletedAt == nil },
           sort: \JournalEntry.createdAt) private var entries: [JournalEntry]

    var body: some View {
        NavigationStack {
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        summaryCards
                        monthlyChart
                        moodDistribution
                        tagDistribution
                        timeDistribution
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color("JournalBackground"))
            }
        }
        .navigationTitle("stats.title")
        .navigationBarTitleDisplayMode(.inline)
        .tabItem {
            Label {
                Text("tab.stats")
            } icon: {
                Image(systemName: "chart.bar.fill")
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.brown.opacity(0.25))
            Text("stats.empty")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("JournalBackground"))
    }

    // MARK: - Computed Stats
    private var activeEntries: [JournalEntry] {
        entries.filter { !$0.isEmpty }
    }
    private var totalEntries: Int { activeEntries.count }
    private var totalWords: Int { activeEntries.reduce(0) { $0 + $1.wordCount } }
    private var currentStreak: Int { JournalEntry.streak(from: activeEntries) }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let activeDates = Set(activeEntries.compactMap { entry in
            calendar.date(from: calendar.dateComponents([.year, .month, .day], from: entry.createdAt))
        })
        let sortedDates = activeDates.sorted()
        guard !sortedDates.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<sortedDates.count {
            if let diff = calendar.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day, diff == 1 {
                current += 1
                longest = max(longest, current)
            } else { current = 1 }
        }
        return longest
    }

    private var averageWords: Int {
        guard totalEntries > 0 else { return 0 }
        return totalWords / totalEntries
    }

    private var daysActiveThisMonth: Int {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else { return 0 }
        let days = activeEntries.filter { $0.createdAt >= monthStart }
        return Set(days.map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    // MARK: - Summary Cards
    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(icon: "book.pages", value: "\(totalEntries)", label: String(localized: "stats.total_entries"))
            StatCard(icon: "text.word.spacing", value: "\(totalWords)", label: String(localized: "stats.total_words"))
            StatCard(icon: "flame", value: "\(currentStreak)", label: String(localized: "stats.current_streak"))
            StatCard(icon: "trophy", value: "\(longestStreak)", label: String(localized: "stats.longest_streak"))
            StatCard(icon: "text.alignleft", value: "\(averageWords)", label: String(localized: "stats.avg_words"))
            StatCard(icon: "calendar.badge.checkmark", value: "\(daysActiveThisMonth)", label: String(localized: "stats.active_days_month"))
        }
    }

    // MARK: - Monthly Chart
    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "chart.bar", title: "stats.monthly_entries")
            let data = computeMonthlyData()
            if data.isEmpty {
                Text("stats.no_data").font(.caption).foregroundStyle(.secondary)
            } else {
                GeometryReader { geo in
                    let maxCount = data.map(\.count).max() ?? 1
                    let barW: CGFloat = 6
                    let count = CGFloat(data.count)
                    let sp = max((geo.size.width - barW * count) / max(count - 1, 1), 4)
                    HStack(alignment: .bottom, spacing: sp) {
                        ForEach(data, id: \.month) { item in
                            VStack(spacing: 4) {
                                if item.count > 0 {
                                    Text("\(item.count)").font(.system(size: 9)).foregroundStyle(.brown.opacity(0.7))
                                }
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [.brown.opacity(0.6), .brown.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: barW, height: max(4, CGFloat(item.count) / CGFloat(max(maxCount, 1)) * 100))
                                Text(item.label).font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
    }

    private struct MonthlyItem { let month: String; let label: String; let count: Int }
    private func computeMonthlyData() -> [MonthlyItem] {
        let calendar = Calendar.current
        let now = Date()
        var result: [MonthlyItem] = []
        for i in stride(from: 11, through: 0, by: -1) {
            guard let md = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: md)
            guard let start = calendar.date(from: comps),
                  let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { continue }
            let m = calendar.component(.month, from: md)
            let cnt = activeEntries.filter { $0.createdAt >= start && $0.createdAt <= min(end, now) }.count
            result.append(MonthlyItem(month: "\(calendar.component(.year, from: md))-\(String(format: "%02d", m))", label: calendar.shortStandaloneMonthSymbols[m - 1], count: cnt))
        }
        return result
    }

    // MARK: - Mood Distribution
    private var moodDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "face.smiling", title: "stats.mood_distribution")
            let moods = computeMoodDistribution()
            if moods.isEmpty {
                Text("stats.no_mood_data").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(moods, id: \.mood) { item in
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Text(item.emoji).font(.title3)
                            Text(MoodType(rawValue: item.mood)?.localizedName ?? item.mood).font(.subheadline).foregroundStyle(.primary)
                            Spacer()
                            Text("\(item.count)").font(.subheadline).fontWeight(.medium).foregroundStyle(.brown)
                            Text("\(Int(item.percentage * 100))%").font(.caption).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2).fill(Color.brown.opacity(0.15)).frame(width: geo.size.width, height: 6)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(LinearGradient(colors: [.brown, .brown.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(6, geo.size.width * item.percentage), height: 6)
                                }
                        }.frame(height: 6)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
    }

    private struct MoodItem { let mood: String; let emoji: String; let count: Int; let percentage: Double }
    private func computeMoodDistribution() -> [MoodItem] {
        let withMood = activeEntries.filter { $0.mood != nil }
        guard !withMood.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for e in withMood { counts[e.mood!, default: 0] += 1 }
        let total = withMood.count
        return counts.map { k, c in MoodItem(mood: k, emoji: MoodType(rawValue: k)?.emoji ?? "", count: c, percentage: Double(c)/Double(total)) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Tag Distribution
    private var tagDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "tag", title: "stats.tag_distribution")
            let tags = computeTagDistribution()
            if tags.isEmpty {
                Text("stats.no_tag_data").font(.caption).foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.tag) { item in
                        HStack(spacing: 4) {
                            Text("#\(item.tag)").font(.caption).fontWeight(.medium)
                            Text("\(item.count)").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.brown.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brown.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
    }

    private struct TagItem { let tag: String; let count: Int }
    private func computeTagDistribution() -> [TagItem] {
        var counts: [String: Int] = [:]
        for e in activeEntries { for t in e.tags { counts[t, default: 0] += 1 } }
        return counts.map { TagItem(tag: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    // MARK: - Time Distribution
    private var timeDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "clock", title: "stats.time_distribution")
            ForEach(computeTimeDistribution(), id: \.period) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.icon).font(.subheadline).foregroundStyle(.brown).frame(width: 20)
                    Text(String(localized: String.LocalizationValue(item.period))).font(.subheadline).foregroundStyle(.primary).frame(width: 50, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3).fill(Color.brown.opacity(0.12)).frame(height: 20)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [.brown, .brown.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(4, geo.size.width * item.percentage), height: 20)
                            }
                    }.frame(height: 20)
                    Text("\(item.count)").font(.caption).fontWeight(.medium).foregroundStyle(.brown).frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
    }

    private struct TimeItem { let period: String; let icon: String; let count: Int; let percentage: Double }
    private func computeTimeDistribution() -> [TimeItem] {
        let calendar = Calendar.current
        var morning = 0, afternoon = 0, evening = 0, night = 0
        for e in activeEntries {
            switch calendar.component(.hour, from: e.createdAt) {
            case 5..<12: morning += 1
            case 12..<17: afternoon += 1
            case 17..<22: evening += 1
            default: night += 1
            }
        }
        let total = activeEntries.count
        guard total > 0 else { return [] }
        return [
            TimeItem(period: "stats.time_morning", icon: "sunrise", count: morning, percentage: Double(morning)/Double(total)),
            TimeItem(period: "stats.time_afternoon", icon: "sun.max", count: afternoon, percentage: Double(afternoon)/Double(total)),
            TimeItem(period: "stats.time_evening", icon: "sunset", count: evening, percentage: Double(evening)/Double(total)),
            TimeItem(period: "stats.time_night", icon: "moon.stars", count: night, percentage: Double(night)/Double(total)),
        ]
    }

    // MARK: - Shared
    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(.brown)
            Text(title).font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
        }
    }
}

// MARK: - Stat Card
private struct StatCard: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(.brown.opacity(0.6))
            Text(value).font(.title2).fontWeight(.bold).fontDesign(.rounded).foregroundStyle(.brown)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 6, y: 2))
    }
}

// MARK: - Flow Layout
#Preview {
    StatsView().modelContainer(for: JournalEntry.self, inMemory: true)
}
