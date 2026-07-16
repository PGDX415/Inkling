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

    private let maxPhotoCount = 5

    init(entry: JournalEntry, onDismiss: (() -> Void)? = nil) {
        self.entry = entry
        self.onDismiss = onDismiss
        _content = State(initialValue: entry.content)
        _entryDate = State(initialValue: entry.createdAt)
    }

    /// Choose serif font based on system language
    private var serifFontName: String {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("zh") {
            return "Songti SC"
        } else {
            return "Georgia"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date picker row
            datePickerRow

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
                        .font(.custom(serifFontName, size: 18, relativeTo: .body))
                        .lineSpacing(8)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $content)
                    .font(.custom(serifFontName, size: 18, relativeTo: .body))
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
                    Spacer()

                    // Word count
                    Text(String(format: String(localized: "journal.word_count"), wordCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

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
            // Load existing photos from the entry
            entryPhotos = entry.photos?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
            try? await Task.sleep(for: .seconds(0.5))
            isFocused = true
        }
        .onChange(of: selectedPhotos) { _, items in
            guard !items.isEmpty else { return }
            loadPhotos(from: items)
        }
        .onDisappear {
            saveTask?.cancel()
            saveImmediately()
        }
    }

    // MARK: - Subviews
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(entryPhotos.enumerated()), id: \.element.id) { index, photo in
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .frame(height: entryPhotos.isEmpty ? 0 : nil)
        .opacity(entryPhotos.isEmpty && selectedPhotos.isEmpty ? 0 : 1)
    }

    private var datePickerRow: some View {
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

    private func persistContent() {
        entry.content = content
        entry.createdAt = entryDate
        entry.modifiedAt = Date()

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
