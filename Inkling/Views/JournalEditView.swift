import SwiftUI
import SwiftData
import PhotosUI

/// Editor view for creating or editing a journal entry with auto-save
struct JournalEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let entry: JournalEntry
    var onDismiss: (() -> Void)?

    @State private var content: String
    @State private var entryDate: Date
    @State private var showSavedIndicator = false
    @State private var saveTask: Task<Void, Never>?
    @State private var entryPhotos: [JournalPhoto] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var fullScreenPhoto: JournalPhoto?
    @State private var isPolishing = false
    @State private var polishError: String?
    @State private var weatherData: WeatherData?
    @State private var isFetchingWeather = false
    @State private var selectedMood: String? = nil
    @State private var tagInput = ""
    @State private var entryTags: [String] = []

    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.deepseek.rawValue
    @AppStorage("aiApiKey_deepseek") private var deepseekKey = ""
    @AppStorage("aiApiKey_siliconflow") private var siliconflowKey = ""
    @AppStorage("aiApiKey_gemini") private var geminiKey = ""
    @AppStorage("fontStyle") private var fontStyle = FontStyle.songti.rawValue
    @AppStorage("fontSize") private var fontSize: Double = 18.0

    private let maxPhotoCount = 5

    init(entry: JournalEntry, onDismiss: (() -> Void)? = nil) {
        self.entry = entry
        self.onDismiss = onDismiss
        _content = State(initialValue: entry.content)
        _entryDate = State(initialValue: entry.createdAt)
    }

    /// Compute journal font from saved settings
    private var journalFont: Font {
        let style = FontStyle(rawValue: fontStyle) ?? .songti
        return style.makeFont(size: fontSize)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date picker row
            datePickerRow

            Divider()
                .overlay(Color.brown.opacity(0.2))

            // Mood picker
            moodPicker

            Divider()
                .overlay(Color.brown.opacity(0.2))

            // Tag editor
            tagEditor

            Divider()
                .overlay(Color.brown.opacity(0.2))

            // Photo strip
            photoStrip

            Divider()
                .overlay(Color.brown.opacity(0.2))

            // Editor area
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("editor.placeholder")
                        .font(journalFont)
                        .lineSpacing(8)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $content)
                    .font(journalFont)
                    .lineSpacing(8)
                    .scrollContentBackground(.hidden)
                    .background(Color("JournalBackground"))
                    .padding(.horizontal, 16)
                    .focused($isFocused)
                    .onChange(of: content) { _, _ in
                        scheduleAutoSave()
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color("JournalBackground"))
        .navigationTitle(isNewEntry
                         ? String(localized: "journal.new_entry_title")
                         : String(localized: "journal.edit_entry_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "common.done")) {
                    saveImmediately()
                    onDismiss?()
                    dismiss()
                }
                .tint(.brown)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    if isDiscardable {
                        modelContext.delete(entry)
                    } else {
                        saveImmediately()
                    }
                    onDismiss?()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                }
            }

            ToolbarItem(placement: .keyboard) {
                HStack {
                    Text(String(format: String(localized: "journal.word_count"), wordCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // AI Polish button
                    if !currentProviderKey.isEmpty && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            polishContent()
                        } label: {
                            HStack(spacing: 4) {
                                if isPolishing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isPolishing
                                     ? String(localized: "journal.polishing")
                                     : String(localized: "journal.polish"))
                                    .font(.caption)
                            }
                        }
                        .disabled(isPolishing)
                        .tint(.brown)
                    }

                    Button(String(localized: "common.done")) {
                        isFocused = false
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Quietly saved indicator
            if showSavedIndicator {
                savedIndicator
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            // Load existing data from the entry
            entryPhotos = entry.photos?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
            selectedMood = entry.mood
            entryTags = entry.tags
            try? await Task.sleep(for: .seconds(0.5))
            isFocused = true

            // Fetch weather for new entries that don't already have weather data
            if isNewEntry && entry.weatherCondition == nil {
                isFetchingWeather = true
                weatherData = await WeatherManager.shared.fetchWeather()
                if let weather = weatherData {
                    entry.weatherCondition = weather.condition.rawValue
                    entry.temperature = weather.temperature
                    entry.weatherLocation = weather.location
                    try? modelContext.save()
                }
                isFetchingWeather = false
            }
        }
        .onChange(of: selectedPhotos) { _, items in
            guard !items.isEmpty else { return }
            loadPhotos(from: items)
        }
        .onDisappear {
            saveTask?.cancel()
            saveImmediately()
        }
        .fullScreenCover(item: $fullScreenPhoto) { photo in
            FullScreenPhotoView(imageData: photo.imageData)
        }
        .alert("AI 润色失败", isPresented: Binding(
            get: { polishError != nil },
            set: { if !$0 { polishError = nil } }
        )) {
            Button("common.done") { polishError = nil }
        } message: {
            Text(polishError ?? "")
        }
    }

    // MARK: - Subviews
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(entryPhotos.enumerated()), id: \.element.id) { index, photo in
                    if let uiImage = UIImage(data: photo.imageData) {
                        Button {
                            fullScreenPhoto = photo
                        } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                deletePhoto(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                }

                if entryPhotos.count < maxPhotoCount {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: maxPhotoCount - entryPhotos.count,
                        matching: .images
                    ) {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brown.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 72, height: 72)
                            .overlay {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.title3)
                                    Text("journal.photos_add")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.brown.opacity(0.5))
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private var datePickerRow: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.brown)
                    .font(.subheadline)

                DatePicker("", selection: $entryDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .onChange(of: entryDate) { _, newDate in
                        entry.createdAt = newDate
                        entry.modifiedAt = Date()
                        scheduleAutoSave()
                    }

                Spacer()

                Text(wordCount > 0
                     ? String(format: String(localized: "journal.word_count"), wordCount)
                     : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Weather indicator
            if isFetchingWeather {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Fetching weather...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let weather = weatherData {
                HStack(spacing: 6) {
                    Image(systemName: weather.condition.symbolName)
                        .foregroundStyle(.brown)
                        .font(.caption)
                    Text("\(String(localized: String.LocalizationValue(weather.condition.localizationKey))) · \(Int(weather.temperature.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("· \(weather.location)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("JournalBackground"))
    }

    private var savedIndicator: some View {
        Text("journal.saved")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.brown.opacity(0.85))
            )
            .padding(.bottom, 16)
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing tags
            if !entryTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entryTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                    .font(.caption)
                                    .foregroundStyle(.brown)
                                Button {
                                    entryTags.removeAll { $0 == tag }
                                    scheduleAutoSave()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.brown.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 8)
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

            // Input field
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundStyle(.brown.opacity(0.5))

                TextField("添加标签...", text: $tagInput)
                    .font(.subheadline)
                    .onSubmit {
                        addTag()
                    }

                if !tagInput.isEmpty {
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.brown)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 6)
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !entryTags.contains(trimmed) {
            entryTags.append(trimmed)
            scheduleAutoSave()
        }
        tagInput = ""
    }

    private var moodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MoodType.allCases, id: \.rawValue) { mood in
                    Button {
                        selectedMood = (selectedMood == mood.rawValue) ? nil : mood.rawValue
                    } label: {
                        VStack(spacing: 2) {
                            Text(mood.emoji)
                                .font(.title2)
                            Text(String(localized: String.LocalizationValue(mood.localizationKey)))
                                .font(.caption2)
                                .foregroundStyle(selectedMood == mood.rawValue ? .brown : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedMood == mood.rawValue ? Color.brown.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed properties
    private var isNewEntry: Bool {
        entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True if both the model and current editing state are empty — safe to discard
    private var isDiscardable: Bool {
        let currentContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedContent = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return currentContent.isEmpty && savedContent.isEmpty
    }

    private var wordCount: Int {
        content.filter { !$0.isWhitespace }.count
    }

    // MARK: - Auto-save
    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    persistContent()
                }
            } catch {}
        }
    }

    private func saveImmediately() {
        saveTask?.cancel()
        persistContent()
    }

    // MARK: - Photos
    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let compressed: Data
                if let image = UIImage(data: data),
                   let jpeg = image.jpegData(compressionQuality: 0.7) {
                    compressed = jpeg
                } else {
                    compressed = data
                }
                await MainActor.run {
                    let photo = JournalPhoto(imageData: compressed, sortOrder: entryPhotos.count)
                    entryPhotos.append(photo)
                }
            }
            await MainActor.run {
                selectedPhotos = []
                scheduleAutoSave()
            }
        }
    }

    private func deletePhoto(at index: Int) {
        entryPhotos.remove(at: index)
        // Re-index sort orders
        for i in 0..<entryPhotos.count {
            entryPhotos[i].sortOrder = i
        }
        scheduleAutoSave()
    }

    // MARK: - AI Key
    private var currentProviderKey: String {
        switch AIProvider(rawValue: aiProviderRaw) ?? .deepseek {
        case .deepseek: return deepseekKey
        case .siliconflow: return siliconflowKey
        case .gemini: return geminiKey
        }
    }

    // MARK: - AI Polish
    private func polishContent() {
        let key = currentProviderKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        let textToPolish = content
        isPolishing = true
        polishError = nil

        let provider = AIProvider(rawValue: aiProviderRaw) ?? .deepseek

        Task {
            do {
                let polished = try await AIService.shared.polish(
                    text: textToPolish,
                    provider: provider,
                    apiKey: key
                )
                await MainActor.run {
                    content = polished
                    isPolishing = false
                    scheduleAutoSave()
                }
            } catch {
                await MainActor.run {
                    polishError = error.localizedDescription
                    isPolishing = false
                }
            }
        }
    }

    private func persistContent() {
        entry.content = content
        entry.createdAt = entryDate
        entry.modifiedAt = Date()
        entry.mood = selectedMood
        entry.tagString = entryTags.joined(separator: ",")

        // Sync photos: remove old ones, insert current ones
        if let existingPhotos = entry.photos {
            for photo in existingPhotos {
                if !entryPhotos.contains(where: { $0.id == photo.id }) {
                    modelContext.delete(photo)
                }
            }
        }
        entry.photos = entryPhotos.isEmpty ? nil : entryPhotos.map { photo in
            if photo.modelContext == nil {
                modelContext.insert(photo)
            }
            return photo
        }

        do {
            try modelContext.save()

            withAnimation(.easeInOut(duration: 0.3)) {
                showSavedIndicator = true
            }

            // Hide indicator after 2 seconds
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSavedIndicator = false
                }
            }
        } catch {
            print("Failed to save entry: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        JournalEditView(entry: JournalEntry())
    }
}
