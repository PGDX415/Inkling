import SwiftUI
import SwiftData

/// Read-only detail view for a journal entry
struct JournalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var isEditing = false

    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Date header
                dateHeader

                Divider()
                    .overlay(Color.brown.opacity(0.2))

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
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
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
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                JournalEditView(entry: entry)
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
        }
    }

    private var contentView: some View {
        Text(entry.content.isEmpty
             ? String(localized: "journal.empty_content")
             : entry.content
        )
        .font(.custom(serifFontName, size: 18, relativeTo: .body))
        .lineSpacing(8)
        .foregroundStyle(entry.content.isEmpty ? .tertiary : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func photoGallery(photos: [JournalPhoto]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos, id: \.id) { photo in
                    if let uiImage = UIImage(data: photo.imageData) {
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

    private var wordCountFooter: some View {
        HStack {
            Spacer()
            Text(String(format: String(localized: "journal.word_count"), entry.wordCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
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

    // MARK: - Actions
    private func deleteEntry() {
        withAnimation {
            modelContext.delete(entry)
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
