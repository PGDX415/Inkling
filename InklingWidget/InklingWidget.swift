import WidgetKit
import SwiftUI

/// Data shared between main app and widget via App Groups UserDefaults
struct WidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let hasWrittenToday: Bool
    let prompt: String
}

struct Provider: TimelineProvider {
    private let suite = UserDefaults(suiteName: "group.com.gongdexin.paul.Inkling")

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), streak: 7, hasWrittenToday: true, prompt: "今天，写下你最感激的一件事。")
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: Date(), streak: 5, hasWrittenToday: false, prompt: "如果今天是一本书的最后一页..."))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let streak = suite?.integer(forKey: "widget_streak") ?? 0
        let hasWritten = suite?.bool(forKey: "widget_hasWrittenToday") ?? false
        let prompt = suite?.string(forKey: "widget_prompt") ?? "一字一句，拾起时光。"

        let entry = WidgetEntry(
            date: Date(),
            streak: streak,
            hasWrittenToday: hasWritten,
            prompt: prompt
        )
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct InklingWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        default:
            mediumWidget
        }
    }

    private var smallWidget: some View {
        VStack(spacing: 4) {
            Text(streakEmoji)
                .font(.system(size: 36))
            Text("\(entry.streak)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.brown)
            Text("天")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(streakEmoji)
                    .font(.title)
                Text("已坚持 \(entry.streak) 天")
                    .font(.headline)
                    .foregroundStyle(.brown)
                Text(entry.prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if !entry.hasWrittenToday {
                Image(systemName: "square.and.pencil")
                    .font(.title)
                    .foregroundStyle(.brown)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var streakEmoji: String {
        switch entry.streak {
        case 1...2: return "🔥"
        case 3...6: return "🔥🔥"
        case 7...13: return "🔥🔥🔥"
        default: return "🔥🔥🔥🔥"
        }
    }
}

struct InklingWidget: Widget {
    let kind: String = "InklingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            InklingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("拾光")
        .description("写作连续天数与每日灵感")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
