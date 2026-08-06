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
    @State private var isPreviewMode = false
    @State private var showAccessorySheet = false
    @State private var showDatePickerPopover = false
    @State private var editorActions = EditorActions()

    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.deepseek.rawValue
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

    // MARK: - Format Options
    private struct FormatOption: Identifiable {
        let id: String
        let label: String
        let insertion: String
    }

    private var formatOptions: [FormatOption] {
        [
            FormatOption(id: "bold", label: "B", insertion: "**\(String(localized: "md.placeholder_bold"))**"),
            FormatOption(id: "italic", label: "I", insertion: "*\(String(localized: "md.placeholder_italic"))*"),
            FormatOption(id: "strike", label: "S", insertion: "~~\(String(localized: "md.placeholder_strikethrough"))~~"),
            FormatOption(id: "heading", label: "#", insertion: "\n# \(String(localized: "md.placeholder_heading"))"),
            FormatOption(id: "list", label: "•", insertion: "\n- \(String(localized: "md.placeholder_list"))"),
            FormatOption(id: "quote", label: "\u{00AB}", insertion: "\n> \(String(localized: "md.placeholder_quote"))"),
            FormatOption(id: "code", label: "`", insertion: "`\(String(localized: "md.placeholder_code"))`"),
            FormatOption(id: "divider", label: "—", insertion: "\n---\n"),
        ]
    }

    /// Insert markdown formatting at the end of content
    private func insertFormat(_ option: FormatOption) {
        content += option.insertion
        scheduleAutoSave()
    }

    /// Build editor actions once for focusedValue — prevents per-frame recreation
    private func setupEditorActions() {
        let viewRef = self
        editorActions = EditorActions(
            insertBold:     { viewRef.insertFormat(viewRef.formatOptions.first { $0.id == "bold" }!) },
            insertItalic:   { viewRef.insertFormat(viewRef.formatOptions.first { $0.id == "italic" }!) },
            insertStrikethrough: { viewRef.insertFormat(viewRef.formatOptions.first { $0.id == "strike" }!) },
            insertHeading:  { viewRef.insertFormat(viewRef.formatOptions.first { $0.id == "heading" }!) },
            insertQuote:    { viewRef.insertFormat(viewRef.formatOptions.first { $0.id == "quote" }!) },
            insertList:     { viewRef.insertFormat(viewRef.formatOptions.first { $0.id == "list" }!) },
            togglePreview: {
                let ref = viewRef
                withAnimation(.easeInOut(duration: 0.2)) {
                    ref.isPreviewMode.toggle()
                    if ref.isPreviewMode { ref.isFocused = false }
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact metadata accessory bar
            metadataBar

            Divider()
                .overlay(Color.brown.opacity(0.2))

            // Editor area — takes all remaining space
            if isPreviewMode {
                previewContent
            } else {
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
        }
        .background(Color("JournalBackground"))
        .focusedValue(\.editorActions, editorActions)
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
                HStack(spacing: 12) {
                    // Preview / Edit toggle
                    if !content.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPreviewMode.toggle()
                                if isPreviewMode {
                                    isFocused = false
                                }
                            }
                        } label: {
                            Image(systemName: isPreviewMode ? "pencil.circle.fill" : "eye")
                        }
                        .tint(.brown)
                    }

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
            }

            ToolbarItem(placement: .keyboard) {
                VStack(spacing: 6) {
                    // Markdown format buttons
                    if !isPreviewMode {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(formatOptions) { option in
                                    Button {
                                        insertFormat(option)
                                    } label: {
                                        Text(option.label)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.brown)
                                            .frame(minWidth: 30, minHeight: 28)
                                            .background(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(Color.brown.opacity(0.08))
                                            )
                                    }
                                    .accessibilityLabel(option.id)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

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
        }
        .overlay(alignment: .bottom) {
            // Quietly saved indicator
            if showSavedIndicator {
                savedIndicator
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            setupEditorActions()

            // Load existing data from the entry
            entryPhotos = entry.photos?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
            selectedMood = entry.mood
            entryTags = entry.tags
            try? await Task.sleep(for: .seconds(0.5))
            isFocused = true

            // Weather: only for today's entries
            let isToday = Calendar.current.isDate(entryDate, inSameDayAs: Date())
            if !isToday && entry.weatherCondition != nil {
                // Clear stale weather from non-today entries
                entry.weatherCondition = nil
                entry.temperature = nil
                entry.weatherLocation = nil
                weatherData = nil
                try? modelContext.save()
            } else if isNewEntry && isToday && entry.weatherCondition == nil {
                // Fetch weather for today's new entries
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
        .sheet(isPresented: $showDatePickerPopover) {
            datePickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAccessorySheet) {
            accessorySheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(String(localized: "ai.polish_error_title"), isPresented: Binding(
            get: { polishError != nil },
            set: { if !$0 { polishError = nil } }
        )) {
            Button("common.done") { polishError = nil }
        } message: {
            Text(polishError ?? "")
        }
    }

    // MARK: - Metadata Bar (compact single row)
    private var metadataBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Date chip
                Button {
                    showDatePickerPopover = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(formattedDateLabel)
                    }
                }
                .chipStyle()

                // Weather chip (if available)
                if isFetchingWeather {
                    HStack(spacing: 3) {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    .chipStyle(active: true)
                } else if let weather = weatherData {
                    HStack(spacing: 3) {
                        Image(systemName: weather.condition.symbolName)
                            .font(.system(size: 11))
                        Text("\(Int(weather.temperature.rounded()))°")
                    }
                    .chipStyle(active: true)
                }

                // Mood chip
                if let mood = selectedMood, let moodType = MoodType(rawValue: mood) {
                    Button {
                        showAccessorySheet = true
                    } label: {
                        Text(moodType.emoji)
                    }
                    .chipStyle(active: true)
                }

                // Tags chip
                if !entryTags.isEmpty {
                    Button {
                        showAccessorySheet = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "tag")
                                .font(.system(size: 10))
                            Text("\(entryTags.count)")
                        }
                    }
                    .chipStyle(active: true)
                }

                // Photos chip
                if !entryPhotos.isEmpty {
                    Button {
                        showAccessorySheet = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "photo")
                                .font(.system(size: 10))
                            Text("\(entryPhotos.count)")
                        }
                    }
                    .chipStyle(active: true)
                }

                // Add / Edit button
                Button {
                    showAccessorySheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .chipStyle()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Accessory Sheet (mood, tags, photos)
    private var accessorySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Section: Mood
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "face.smiling")
                                .font(.caption)
                                .foregroundStyle(.brown)
                            Text(selectedMood != nil
                                 ? String(localized: String.LocalizationValue(MoodType(rawValue: selectedMood ?? "")?.localizationKey ?? ""))
                                 : "Mood")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedMood != nil {
                                Button("Clear") {
                                    selectedMood = nil
                                    scheduleAutoSave()
                                }
                                .font(.caption2)
                                .foregroundStyle(.brown.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(MoodType.allCases, id: \.rawValue) { mood in
                                    Button {
                                        selectedMood = (selectedMood == mood.rawValue) ? nil : mood.rawValue
                                        scheduleAutoSave()
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(mood.emoji)
                                                .font(.title)
                                            Text(String(localized: String.LocalizationValue(mood.localizationKey)))
                                                .font(.caption2)
                                                .foregroundStyle(selectedMood == mood.rawValue ? .brown : .secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedMood == mood.rawValue ? Color.brown.opacity(0.1) : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)

                    Divider()
                        .overlay(Color.brown.opacity(0.15))
                        .padding(.horizontal, 20)

                    // Section: Tags
                    VStack(alignment: .leading, spacing: 10) {
                        Label(String(localized: "journal.tag_placeholder"), systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        // Tag chips
                        if !entryTags.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(entryTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text("#\(tag)")
                                            .font(.caption)
                                        Button {
                                            entryTags.removeAll { $0 == tag }
                                            scheduleAutoSave()
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 8, weight: .bold))
                                        }
                                    }
                                    .foregroundStyle(.brown)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.brown.opacity(0.1))
                                    )
                                    .accessibilityLabel(String(format: String(localized: "a11y.remove_tag"), tag))
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Tag input
                        HStack(spacing: 8) {
                            TextField(String(localized: "journal.tag_placeholder"), text: $tagInput)
                                .font(.subheadline)
                                .onSubmit { addTag() }

                            if !tagInput.isEmpty {
                                Button { addTag() } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.brown)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.brown.opacity(0.04))
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)

                    Divider()
                        .overlay(Color.brown.opacity(0.15))
                        .padding(.horizontal, 20)

                    // Section: Photos
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(String(localized: "journal.photos_add"), systemImage: "photo.on.rectangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(entryPhotos.count)/\(maxPhotoCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(entryPhotos.enumerated()), id: \.element.id) { index, photo in
                                    Button {
                                        fullScreenPhoto = photo
                                    } label: {
                                        AsyncPhotoView(imageData: photo.imageData)
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                            .accessibilityLabel(String(localized: "a11y.remove_photo"))
                                        }
                                    }


                                if entryPhotos.count < maxPhotoCount {
                                    PhotosPicker(
                                        selection: $selectedPhotos,
                                        maxSelectionCount: maxPhotoCount - entryPhotos.count,
                                        matching: .images
                                    ) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.brown.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                            .frame(width: 80, height: 80)
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
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color("JournalBackground"))
            .navigationTitle(String(localized: "journal.new_entry_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        showAccessorySheet = false
                    }
                }
            }
        }
    }

    // MARK: - Date Picker Sheet
    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button(String(localized: "common.cancel")) {
                    showDatePickerPopover = false
                }
                .foregroundStyle(.secondary)

                Spacer()

                Text(String(localized: "calendar.title"))
                    .font(.headline)

                Spacer()

                Button(String(localized: "common.done")) {
                    showDatePickerPopover = false
                }
                .fontWeight(.medium)
                .foregroundStyle(.brown)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            DatePicker(
                "",
                selection: $entryDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, 12)
            .onChange(of: entryDate) { _, newDate in
                entry.createdAt = newDate
                entry.modifiedAt = Date()
                if !Calendar.current.isDate(newDate, inSameDayAs: Date()) {
                    entry.weatherCondition = nil
                    entry.temperature = nil
                    entry.weatherLocation = nil
                    weatherData = nil
                }
                scheduleAutoSave()
            }

            Spacer()
        }
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

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !entryTags.contains(trimmed) {
            entryTags.append(trimmed)
            scheduleAutoSave()
        }
        tagInput = ""
    }

    // MARK: - Preview Content
    private var previewContent: some View {
        VStack(spacing: 0) {
            // Preview mode indicator
            HStack {
                Image(systemName: "eye")
                    .font(.caption)
                Text("editor.preview_mode")
                    .font(.caption)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPreviewMode = false
                        isFocused = true
                    }
                } label: {
                    Label(String(localized: "journal.edit"), systemImage: "pencil")
                        .font(.caption)
                }
                .tint(.brown)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Divider()
                .overlay(Color.brown.opacity(0.15))

            ScrollView {
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("editor.placeholder")
                        .font(journalFont)
                        .foregroundStyle(.tertiary)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(MarkdownRenderer.render(content, baseFont: journalFont))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("JournalBackground"))
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

    /// Formatted date label for the metadata bar chip
    private var formattedDateLabel: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(entryDate) {
            formatter.dateFormat = "HH:mm"
            return "\(String(localized: "date.today")) \(formatter.string(from: entryDate))"
        } else if calendar.isDateInYesterday(entryDate) {
            formatter.dateFormat = "HH:mm"
            return "\(String(localized: "date.yesterday")) \(formatter.string(from: entryDate))"
        } else if calendar.isDateInTomorrow(entryDate) {
            formatter.dateFormat = "HH:mm"
            return "\(String(localized: "date.tomorrow")) \(formatter.string(from: entryDate))"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: entryDate)
        }
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
        let provider = AIProvider(rawValue: aiProviderRaw) ?? .deepseek
        return KeychainManager.shared.load(key: provider)
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
        entry.refreshDisplayCache()

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

// MARK: - Chip Style Modifier
extension View {
    func chipStyle(active: Bool = false) -> some View {
        self
            .font(.caption)
            .foregroundStyle(active ? .white : .brown)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(active ? Color.brown : Color.brown.opacity(0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .hoverEffect(.highlight)
    }
}

