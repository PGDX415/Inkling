import SwiftUI

/// Renders a shareable card image from a journal entry
struct ShareCardView: View {
    let entry: JournalEntry
    @AppStorage("fontStyle") private var fontStyle = FontStyle.songti.rawValue
    @AppStorage("fontSize") private var fontSize: Double = 18.0

    private var journalFont: Font {
        (FontStyle(rawValue: fontStyle) ?? .songti).makeFont(size: fontSize)
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color("JournalBackground"), Color("JournalBackground").opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative border
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(
                    LinearGradient(
                        colors: [.brown.opacity(0.15), .brown.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .padding(12)

            VStack(spacing: 0) {
                // Top bar with app branding
                topBranding

                Divider().overlay(Color.brown.opacity(0.15)).padding(.horizontal, 24)

                // Content area
                VStack(alignment: .leading, spacing: 16) {
                    dateHeader

                    if !entry.tags.isEmpty {
                        tagsRow
                    }

                    if !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.content)
                            .font(journalFont)
                            .lineSpacing(8)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 8)

                    Divider().overlay(Color.brown.opacity(0.1))

                    bottomBar
                }
                .padding(24)
            }
            .padding(.vertical, 12)
        }
        .frame(width: 390)
    }

    // MARK: - Subviews
    private var topBranding: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.brown)
                Text("app.name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.brown)
            }
            Spacer()
            Text(String(localized: "share.made_with"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateFormatter.weekdayShort.string(from: entry.createdAt))
                .font(.caption)
                .foregroundStyle(.brown)
                .fontWeight(.medium)

            Text(entry.createdAt, style: .date)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                if let moodRaw = entry.mood, let mood = MoodType(rawValue: moodRaw) {
                    HStack(spacing: 3) {
                        Text(mood.emoji).font(.caption)
                        Text(mood.localizedName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let cond = entry.weatherCondition, let temp = entry.temperature,
                   let w = WeatherCondition(rawValue: cond) {
                    HStack(spacing: 3) {
                        Image(systemName: w.symbolName).font(.caption2)
                        Text("\(Int(temp.rounded()))°").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var tagsRow: some View {
        HStack(spacing: 4) {
            ForEach(entry.tags.prefix(5), id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption2)
                    .foregroundStyle(.brown.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.brown.opacity(0.06)))
            }
            if entry.tags.count > 5 {
                Text("+\(entry.tags.count - 5)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Text(String(format: String(localized: "journal.word_count"), entry.wordCount))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Text(DateFormatter.journalDate.string(from: entry.createdAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.top, 8)
    }
}

#Preview {
    ShareCardView(
        entry: {
            let e = JournalEntry(
                content: "夕阳的余晖洒在旧书店的木地板上，像一页页泛黄的诗。我抽出一本泛旧的朱自清，扉页上有人用钢笔写着：「愿每一个黄昏，都有人与你共读」。原来时光从来不曾真正离去，它只是换了一种方式，藏在某一本书的某一页里，等你翻开。",
                createdAt: Date()
            )
            e.mood = MoodType.calm.rawValue
            return e
        }()
    )
    .preferredColorScheme(.light)
}

// MARK: - Share Preview View
struct SharePreviewView: View {
    let image: UIImage
    @Binding var triggerShare: Bool
    let onDismiss: () -> Void

    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Image preview
            ScrollView {
                VStack(spacing: 16) {
                    // Hint text
                    Text("share.preview_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                        .padding(.horizontal, 16)
                }
            }
            .background(Color(.systemGroupedBackground))

            // Bottom share bar
            VStack(spacing: 12) {
                Button {
                    showShareSheet = true
                } label: {
                    Label("share.button", systemImage: "square.and.arrow.up")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(
                Rectangle()
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
            )
        }
        .navigationTitle("share.preview_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "common.cancel")) {
                    onDismiss()
                }
                .tint(.brown)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(image: image)
        }
        .onChange(of: triggerShare) { _, newValue in
            if newValue {
                triggerShare = false
                showShareSheet = true
            }
        }
    }
}

// MARK: - UIKit Activity Controller
private struct ActivityViewController: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard !context.coordinator.didPresent else { return }
        context.coordinator.didPresent = true
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = uiViewController.view
        uiViewController.present(activity, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var didPresent = false }
}
