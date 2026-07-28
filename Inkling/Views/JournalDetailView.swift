import SwiftUI
import SwiftData
import AVFoundation

/// Read-only detail view for a journal entry
struct JournalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fontStyle") private var fontStyle = FontStyle.songti.rawValue
    @AppStorage("fontSize") private var fontSize: Double = 18.0
    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.deepseek.rawValue
    @AppStorage("aiApiKey_deepseek") private var deepseekKey = ""
    @AppStorage("aiApiKey_siliconflow") private var siliconflowKey = ""
    @AppStorage("aiApiKey_gemini") private var geminiKey = ""
    @AppStorage("voiceIdentifier") private var voiceIdentifier = ""
    @AppStorage("speechRate") private var speechRate: Double = 0.5
    @State private var showDeleteAlert = false
    @State private var isEditing = false
    @State private var isPolishing = false
    @State private var polishError: String?
    @State private var fullScreenPhoto: JournalPhoto?
    @State private var speechManager = SpeechManager.shared
    @State private var shareCardImage: UIImage?
    @State private var showSharePreview = false
    @State private var triggerShare = false

    let entry: JournalEntry

    private var journalFont: Font {
        let style = FontStyle(rawValue: fontStyle) ?? .songti
        return style.makeFont(size: fontSize)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Date header
                dateHeader

                Divider()
                    .overlay(Color.brown.opacity(0.2))

                // Tags
                if !entry.tags.isEmpty {
                    tagsView
                }

                // Content
                contentView

                // Photo gallery
                if let photos = entry.photos, !photos.isEmpty {
                    photoGallery(photos: photos.sorted(by: { $0.sortOrder < $1.sortOrder }))
                }

                // Word count footer
                wordCountFooter
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color("JournalBackground"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 12) {
                    // Bookmark toggle
                    Button {
                        entry.isBookmarked.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: entry.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .tint(.brown)

                    if !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            toggleSpeech()
                        } label: {
                            Image(systemName: speechManager.isSpeaking && !speechManager.isPaused
                                  ? "speaker.wave.2.fill"
                                  : "speaker.wave.2")
                        }
                        .tint(.brown)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Share card button
                    if !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            renderAndShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .tint(.brown)
                    }

                    // AI Polish button
                    if !currentProviderKey.isEmpty && !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            polishContent()
                        } label: {
                            if isPolishing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                            }
                        }
                        .disabled(isPolishing)
                        .tint(.brown)
                    }

                    Button {
                        isEditing = true
                    } label: {
                        Text("journal.edit")
                    }
                    .tint(.brown)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .alert(
            String(localized: "journal.delete_title"),
            isPresented: $showDeleteAlert
        ) {
            Button(String(localized: "journal.delete_cancel"), role: .cancel) {}
            Button(String(localized: "journal.delete_confirm"), role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("journal.delete_message")
        }
        .alert("AI 润色失败", isPresented: Binding(
            get: { polishError != nil },
            set: { if !$0 { polishError = nil } }
        )) {
            Button("common.done") { polishError = nil }
        } message: {
            Text(polishError ?? "")
        }
        .fullScreenCover(item: $fullScreenPhoto) { photo in
            FullScreenPhotoView(imageData: photo.imageData)
        }
        .onDisappear {
            speechManager.stop()
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                JournalEditView(entry: entry)
            }
        }
        .sheet(isPresented: $showSharePreview) {
            if let image = shareCardImage {
                NavigationStack {
                    SharePreviewView(
                        image: image,
                        triggerShare: $triggerShare,
                        onDismiss: { showSharePreview = false }
                    )
                }
            }
        }
    }

    // MARK: - Subviews
    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DateFormatter.weekdayShort.string(from: entry.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.brown)
                    .fontWeight(.medium)

                Spacer()

                Text(entry.createdAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(entry.createdAt, style: .date)
                .font(.title3)
                .fontWeight(.regular)
                .foregroundStyle(.primary)

            // Mood
            if let moodRaw = entry.mood,
               let mood = MoodType(rawValue: moodRaw) {
                HStack(spacing: 4) {
                    Text(mood.emoji)
                        .font(.title3)
                    Text(String(localized: String.LocalizationValue(mood.localizationKey)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Weather info
            if let conditionRaw = entry.weatherCondition,
               let condition = WeatherCondition(rawValue: conditionRaw),
               let temp = entry.temperature {
                HStack(spacing: 6) {
                    Image(systemName: condition.symbolName)
                        .foregroundStyle(.brown)
                    Text("\(String(localized: String.LocalizationValue(condition.localizationKey))) · \(Int(temp.rounded()))°")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let location = entry.weatherLocation {
                        Text("· \(location)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(entry.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.brown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.brown.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var contentView: some View {
        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AnyView(
                Text("journal.empty_content")
                    .font(journalFont)
                    .lineSpacing(8)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        } else {
            return AnyView(
                Text(MarkdownRenderer.render(entry.content, baseFont: journalFont))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            )
        }
    }

    private func photoGallery(photos: [JournalPhoto]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos, id: \.id) { photo in
                    if let uiImage = UIImage(data: photo.imageData) {
                        Button {
                            fullScreenPhoto = photo
                        } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private var wordCountFooter: some View {
        HStack {
            Spacer()
            Text(String(format: String(localized: "journal.word_count"), entry.wordCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    // MARK: - Speech
    private func toggleSpeech() {
        if speechManager.isSpeaking && !speechManager.isPaused {
            speechManager.pause()
        } else if speechManager.isPaused {
            speechManager.resume()
        } else {
            let voice = voiceIdentifier.isEmpty
                ? AVSpeechSynthesisVoice(language: "zh-CN")
                : AVSpeechSynthesisVoice(identifier: voiceIdentifier)
            speechManager.speak(
                entry.content,
                voice: voice,
                rate: Float(speechRate) * AVSpeechUtteranceMaximumSpeechRate
            )
        }
    }

    // MARK: - AI Polish
    private var currentProviderKey: String {
        switch AIProvider(rawValue: aiProviderRaw) ?? .deepseek {
        case .deepseek: return deepseekKey
        case .siliconflow: return siliconflowKey
        case .gemini: return geminiKey
        }
    }

    private func polishContent() {
        let key = currentProviderKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        let provider = AIProvider(rawValue: aiProviderRaw) ?? .deepseek
        let textToPolish = entry.content

        isPolishing = true
        polishError = nil

        Task {
            do {
                let polished = try await AIService.shared.polish(
                    text: textToPolish,
                    provider: provider,
                    apiKey: key
                )
                await MainActor.run {
                    entry.content = polished
                    try? modelContext.save()
                    isPolishing = false
                }
            } catch {
                await MainActor.run {
                    polishError = error.localizedDescription
                    isPolishing = false
                }
            }
        }
    }

    // MARK: - Share Card
    private func renderAndShare() {
        let card = ShareCardView(entry: entry)
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        renderer.scale = UIScreen.main.scale
        shareCardImage = renderer.uiImage
        showSharePreview = true
    }

    private func doShare() {
        guard shareCardImage != nil else { return }
        triggerShare = true
    }

    // MARK: - Actions
    private func deleteEntry() {
        withAnimation {
            entry.deletedAt = Date()
            try? modelContext.save()
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        JournalDetailView(
            entry: JournalEntry(
                content: "Today was a beautiful day.\n\nI took a long walk by the river and watched the sunset paint the sky in shades of amber and rose. The water was calm, reflecting the colors like a mirror. A gentle breeze carried the scent of summer flowers.",
                createdAt: Date()
            )
        )
    }
}
