import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// App settings view
struct SettingsView: View {
    @AppStorage("isLockEnabled") private var isLockEnabled = false
    @AppStorage("sortOrder") private var sortOrder = SortOrder.newestFirst.rawValue
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showExportAlert = false
    @State private var exportMessage = ""
    @State private var showFileImporter = false
    @State private var showImportAlert = false
    @State private var importMessage = ""
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Me Section
                Section {
                    HStack(spacing: 16) {
                        // Profile photo
                        profilePhotoView

                        // Name field
                        TextField(
                            String(localized: "settings.profile_name_placeholder"),
                            text: Binding(
                                get: { currentProfile.name },
                                set: { newValue in
                                    currentProfile.name = newValue
                                    try? modelContext.save()
                                }
                            )
                        )
                        .font(.body)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("settings.section_me")
                }

                // MARK: - Security Section
                Section {
                    Toggle(isOn: $isLockEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.app_lock")
                                .font(.body)
                            Text("settings.app_lock_description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.brown)
                    .onChange(of: isLockEnabled) { _, newValue in
                        if newValue {
                            // Verify biometrics are available before enabling
                            if !BiometricAuthManager.shared.isAvailable {
                                isLockEnabled = false
                            }
                        }
                    }
                    .disabled(!BiometricAuthManager.shared.isAvailable)
                } header: {
                    Text("settings.section_privacy")
                }

                // MARK: - Display Section
                Section {
                    Picker(selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.localizedName).tag(order.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(.brown)
                            Text("settings.sort_order")
                        }
                    }
                } header: {
                    Text("settings.section_display")
                }

                // MARK: - Data Section
                Section {
                    Button {
                        exportEntries()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.brown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.export")
                                Text("settings.export_description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.brown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.import")
                                Text("settings.import_description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                } header: {
                    Text("settings.section_data")
                }

                // MARK: - About Section
                Section {
                    HStack {
                        Text("settings.version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("settings.about")
                        Spacer()
                        Text("app.name")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("settings.about")
                }
            }
            .navigationTitle("settings.title")
            .alert(exportMessage, isPresented: $showExportAlert) {
                Button("common.done") {}
            }
            .alert(importMessage, isPresented: $showImportAlert) {
                Button("common.done") {}
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                loadPhoto(from: newItem)
            }
        }
        .tabItem {
            Label {
                Text("tab.settings")
            } icon: {
                Image(systemName: "gearshape")
            }
        }
    }

    // MARK: - Profile
    /// Return the first UserProfile or create one lazily
    private var currentProfile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    // MARK: - Profile Photo
    private var profilePhotoView: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Group {
                if let photoData = currentProfile.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.brown.opacity(0.4))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.brown.opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityLabel(String(localized: "settings.profile_photo"))
    }

    private func loadPhoto(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            // Compress to a reasonable size for storage
            let compressed: Data
            if let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.7) {
                compressed = jpeg
            } else {
                compressed = data
            }
            await MainActor.run {
                currentProfile.photoData = compressed
                try? modelContext.save()
            }
        }
    }

    // MARK: - Export
    private func exportEntries() {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let entries = try modelContext.fetch(descriptor)
            guard !entries.isEmpty else {
                exportMessage = String(localized: "settings.no_entries_export")
                showExportAlert = true
                return
            }

            var text = ""
            text += "\(String(localized: "app.name"))\n"
            text += "\(String(localized: "settings.export")): \(DateFormatter.journalDate.string(from: Date()))\n"
            text += String(repeating: "─", count: 40) + "\n\n"

            for entry in entries {
                text += "[\(DateFormatter.iso8601.string(from: entry.createdAt))] "
                text += DateFormatter.journalFull.string(from: entry.createdAt) + "\n"
                text += String(repeating: "─", count: 40) + "\n"
                text += entry.content + "\n\n"
            }

            // Save to temp file and share
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Inkling_Export_\(Date().timeIntervalSince1970).txt")

            try text.write(to: tempURL, atomically: true, encoding: .utf8)

            // Use UIActivityViewController via SwiftUI share sheet
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                // Find the topmost presented view controller
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(activityVC, animated: true)
            }

        } catch {
            exportMessage = String(localized: "settings.export_failed")
            showExportAlert = true
        }
    }

    // MARK: - Import
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importMessage = String(localized: "settings.import_failed")
                showImportAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let imported = parseImportedEntries(from: content)
                guard !imported.isEmpty else {
                    importMessage = String(localized: "settings.import_no_entries")
                    showImportAlert = true
                    return
                }

                var newCount = 0
                var skippedCount = 0
                let allExisting = try modelContext.fetch(FetchDescriptor<JournalEntry>())
                let existingSet = Set(allExisting.map { "\($0.createdAt.timeIntervalSince1970)|\($0.content)" })

                for entryData in imported {
                    let key = "\(entryData.date.timeIntervalSince1970)|\(entryData.content)"
                    if existingSet.contains(key) {
                        skippedCount += 1
                    } else {
                        let entry = JournalEntry(content: entryData.content, createdAt: entryData.date)
                        modelContext.insert(entry)
                        newCount += 1
                    }
                }
                try modelContext.save()

                var messageParts: [String] = []
                if newCount > 0 {
                    messageParts.append(String(format: String(localized: "settings.import_success"), newCount))
                }
                if skippedCount > 0 {
                    messageParts.append(String(format: String(localized: "settings.import_skipped"), skippedCount))
                }
                importMessage = messageParts.isEmpty
                    ? String(localized: "settings.import_no_entries")
                    : messageParts.joined(separator: "\n")
                showImportAlert = true

            } catch {
                importMessage = String(localized: "settings.import_failed")
                showImportAlert = true
            }

        case .failure:
            importMessage = String(localized: "settings.import_failed")
            showImportAlert = true
        }
    }

    /// Parse the exported text format back into entry data
    private func parseImportedEntries(from text: String) -> [(date: Date, content: String)] {
        var entries: [(date: Date, content: String)] = []

        // Split by separator lines (──)
        let lines = text.components(separatedBy: .newlines)
        var currentDate: Date?
        var currentContent: String = ""
        var inContent = false

        for line in lines {
            // Detect date line: starts with [ISO8601]
            if line.hasPrefix("[") && line.contains("]") {
                // Save previous entry if we have one
                if let date = currentDate, !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    entries.append((date: date, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }

                // Extract ISO date
                if let bracketEnd = line.firstIndex(of: "]") {
                    let isoString = String(line[line.index(after: line.startIndex)..<bracketEnd])
                    currentDate = DateFormatter.iso8601.date(from: isoString) ?? DateFormatter.iso8601Full.date(from: isoString)
                    currentContent = ""
                    inContent = true
                }
                continue
            }

            // Skip separator lines and header
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("─") || trimmed.hasPrefix("—") || trimmed.isEmpty {
                if inContent && currentContent.hasSuffix("\n") {
                    // separator inside content, keep it
                }
                continue
            }

            // Skip header lines (before first date entry)
            if currentDate == nil { continue }

            // Accumulate content
            if inContent {
                if !currentContent.isEmpty {
                    currentContent += "\n"
                }
                currentContent += line
            }
        }

        // Save last entry
        if let date = currentDate, !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entries.append((date: date, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return entries
    }
}

#Preview {
    SettingsView()
}
