import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

/// App settings view
struct SettingsView: View {
    @AppStorage("isLockEnabled") private var isLockEnabled = false
    @AppStorage("sortOrder") private var sortOrder = SortOrder.newestFirst.rawValue
    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.deepseek.rawValue
    @AppStorage("fontStyle") private var fontStyle = FontStyle.songti.rawValue
    @State private var apiKeyInput = ""
    @AppStorage("fontSize") private var fontSize: Double = 18.0
    @AppStorage("displayMode") private var displayMode = DisplayMode.system.rawValue
    @AppStorage("voiceIdentifier") private var voiceIdentifier = ""
    @AppStorage("speechRate") private var speechRate: Double = 0.5
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncMonitor.self) private var syncMonitor
    @Environment(StoreManager.self) private var store
    @State private var showPaywall = false
    @State private var resolvedProfile: UserProfile?
    @FocusState private var isApiKeyFocused: Bool
    @State private var showExportAlert = false
    @State private var exportMessage = ""
    @State private var showFileImporter = false
    @State private var showImportAlert = false
    @State private var importMessage = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewingVoice: String?
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var isApiKeyExpanded = false

    private let speechRateRange: ClosedRange<Double> = 0.35...0.65

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
                                get: { resolveProfile().name },
                                set: { newValue in
                                    resolveProfile().name = newValue
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

                // MARK: - AI Section
                Section {
                    Picker(selection: $aiProviderRaw) {
                        ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.brown)
                            Text("settings.ai_provider")
                        }
                    }
                    .onChange(of: aiProviderRaw) { _, _ in
                        isApiKeyExpanded = false
                        apiKeyInput = KeychainManager.shared.load(key: currentProvider)
                    }

                    DisclosureGroup(isExpanded: $isApiKeyExpanded) {
                        SecureField(
                            String(localized: "settings.ai_api_key_placeholder"),
                            text: $apiKeyInput
                        )
                        .focused($isApiKeyFocused)
                        .onChange(of: apiKeyInput) { _, _ in
                            persistKey()
                        }
                        .onSubmit {
                            isApiKeyExpanded = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "key")
                                .foregroundStyle(.brown)
                            Text("settings.ai_api_key")
                            Spacer()
                            keyStatusBadge
                        }
                    }
                } header: {
                    Text("settings.section_ai")
                }

                // MARK: - Pro Section
                Section {
                    if store.isPro {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                            Text("settings.pro_active")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Button {
                            Task {
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                    await MainActor.run { UIApplication.shared.open(url) }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "creditcard")
                                    .foregroundStyle(.brown)
                                Text("store.manage_subscription")
                            }
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown")
                                    .foregroundStyle(.brown)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("settings.pro_upgrade")
                                        .fontWeight(.medium)
                                    Text("store.pro_subtitle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("settings.section_pro")
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

                // MARK: - Reminder Section
                Section {
                    Toggle(isOn: $reminderEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.reminder")
                                .font(.body)
                            Text("settings.reminder_description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.brown)
                    .onChange(of: reminderEnabled) { _, enabled in
                        scheduleReminder(enabled: enabled)
                    }

                    if reminderEnabled {
                        DatePicker(
                            String(localized: "settings.reminder_time"),
                            selection: Binding(
                                get: {
                                    Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
                                },
                                set: { date in
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                    reminderHour = components.hour ?? 21
                                    reminderMinute = components.minute ?? 0
                                    scheduleReminder(enabled: reminderEnabled)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .tint(.brown)
                    }
                } header: {
                    Text("settings.section_reminder")
                }

                // MARK: - Display Section
                Section {
                    Picker(selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.rawValue) { mode in
                            Text(mode.localizedName).tag(mode.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(.brown)
                            Text("settings.display_mode")
                        }
                    }

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

                // MARK: - Font Section
                Section {
                    DisclosureGroup {
                        // Font style selector
                        ForEach(FontStyle.allCases, id: \.rawValue) { style in
                            Button {
                                fontStyle = style.rawValue
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(style.displayName)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text(style.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if fontStyle == style.rawValue {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.brown)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            // Font preview
                            Text(style.sampleText)
                                .font(style.makeFont(size: 16))
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color("JournalBackground"))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.brown.opacity(0.15), lineWidth: 1)
                                )
                        }

                        Divider()

                        // Font size slider
                        VStack(spacing: 8) {
                            HStack {
                                Text("settings.font_size")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(Int(fontSize))pt")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $fontSize, in: 14...24, step: 1)
                                .tint(.brown)

                            HStack {
                                Text("A")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("A")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "textformat")
                                .foregroundStyle(.brown)
                            Text("settings.section_font")
                                .fontWeight(.medium)
                            Spacer()
                            // Show current font name as subtitle
                            Text(FontStyle(rawValue: fontStyle)?.displayName ?? "Songti")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Voice Section
                voiceSection

                // MARK: - Data Section
                Section {
                    NavigationLink {
                        StatsView()
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.brown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("tab.stats")
                            }
                        }
                    }

                    NavigationLink {
                        TrashView()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(.brown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.trash")
                                Text("settings.trash_description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

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

                    HStack {
                        Image(systemName: syncStatusIcon)
                            .foregroundStyle(syncStatusColor)
                            .font(.caption)
                        Text("settings.syncing")
                            .font(.subheadline)
                        Spacer()
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        HelpView()
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.brown)
                            Text("settings.help")
                        }
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.brown)
                            Text("settings.privacy")
                        }
                    }
                } header: {
                    Text("settings.about")
                }
            }
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(String(localized: "common.done")) {
                            isApiKeyFocused = false
                        }
                        .fontWeight(.medium)
                    }
                }
            }
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
            .onAppear {
                apiKeyInput = KeychainManager.shared.load(key: currentProvider)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - AI Key Management
    private var currentProvider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .deepseek
    }

    private var currentProviderKey: String {
        KeychainManager.shared.load(key: currentProvider)
    }

    private func persistKey() {
        KeychainManager.shared.save(key: currentProvider, value: apiKeyInput)
    }

    private var keyStatusBadge: some View {
        if currentProviderKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AnyView(
                Text("settings.ai_key_not_set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
        } else {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("••••••••")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            )
        }
    }

    // MARK: - Sync Status
    private var syncStatusIcon: String {
        switch syncMonitor.status {
        case .upToDate, .imported, .exported: return "icloud.fill"
        case .syncing: return "icloud.and.arrow.up"
        case .error: return "icloud.slash"
        }
    }

    private var syncStatusColor: Color {
        switch syncMonitor.status {
        case .upToDate, .imported, .exported: return .green
        case .syncing: return .brown
        case .error: return .red
        }
    }

    private var syncStatusText: String {
        switch syncMonitor.status {
        case .upToDate:
            return String(localized: "sync.status_uptodate")
        case .syncing:
            return String(localized: "sync.status_syncing")
        case .imported(let date):
            let formatter = RelativeDateTimeFormatter()
            return String(format: String(localized: "sync.status_imported"), formatter.localizedString(for: date, relativeTo: Date()))
        case .exported:
            return String(localized: "sync.status_exported")
        case .error:
            return String(localized: "sync.status_error")
        }
    }

    // MARK: - Profile
    /// Return the single UserProfile, creating one lazily and merging duplicates from sync
    private func resolveProfile() -> UserProfile {
        let matching = profiles.filter { $0.id == UserProfile.fixedID }
        if let first = matching.first {
            if matching.count > 1 {
                // Merge data from CloudKit-synced duplicates before removing them
                for duplicate in matching.dropFirst() {
                    if first.name.isEmpty && !duplicate.name.isEmpty {
                        first.name = duplicate.name
                    }
                    if first.photoData == nil && duplicate.photoData != nil {
                        first.photoData = duplicate.photoData
                    }
                    modelContext.delete(duplicate)
                }
                try? modelContext.save()
            }
            return first
        }
        // No profile yet — create one (local; CloudKit data may arrive later)
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    // MARK: - Profile Photo
    private var profilePhotoView: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Group {
                if let photoData = resolveProfile().photoData,
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
                resolveProfile().photoData = compressed
                try? modelContext.save()
            }
        }
    }

    // MARK: - Voice Section
    @ViewBuilder
    private var voiceSection: some View {
        let enhancedList = availableVoices.filter { $0.quality == .enhanced || $0.quality == .premium }
        let defaultList = availableVoices.filter { $0.quality == .default }
        let allVoices = enhancedList + defaultList
        let hasVoices = !allVoices.isEmpty
        let selectedVoice = allVoices.first { $0.identifier == voiceIdentifier }

        Section {
            if hasVoices {
                // Collapsible voice picker
                DisclosureGroup {
                    // Enhanced voices
                    if !enhancedList.isEmpty {
                        ForEach(enhancedList, id: \.identifier) { voice in
                            voiceRow(voice, language: voice.language)
                        }
                    }
                    // Basic voices
                    if !defaultList.isEmpty {
                        ForEach(defaultList, id: \.identifier) { voice in
                            voiceRow(voice, language: voice.language)
                        }
                    }
                } label: {
                    HStack {
                        Text("settings.section_voice")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(selectedVoice?.name ?? String(localized: "voice.unavailable"))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                }
            } else {
                VStack(spacing: 12) {
                    Text("voice.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "voice.download_hint"))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brown.opacity(0.06))
                    )
                }
            }

            // Speech rate
            VStack(spacing: 8) {
                HStack {
                    Text("settings.speech_rate")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(speedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Image(systemName: "tortoise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $speechRate, in: speechRateRange)
                        .tint(.brown)
                    Image(systemName: "hare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("settings.section_voice")
        }
        .onAppear {
            refreshVoices()
        }
    }

    private var speedLabel: String {
        if speechRate < 0.4 { return String(localized: "speech.slow") }
        if speechRate > 0.55 { return String(localized: "speech.fast") }
        return String(localized: "speech.normal")
    }

    private func voiceRow(_ voice: AVSpeechSynthesisVoice, language: String) -> some View {
        let isSelected = voiceIdentifier == voice.identifier
        let isPreviewing = previewingVoice == voice.identifier
        let isEnhanced = voice.quality == .enhanced || voice.quality == .premium
        let qualityText = SpeechManager.qualityLabel(voice)

        return Button {
            voiceIdentifier = voice.identifier
            previewingVoice = voice.identifier
            SpeechManager.shared.preview(
                voice: voice,
                sample: String(localized: "voice.sample_text")
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if previewingVoice == voice.identifier { previewingVoice = nil }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(voice.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        if let label = qualityText {
                            Text(label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isEnhanced ? .green : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isEnhanced ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                                )
                        }
                    }
                    Text(voice.gender == .female
                         ? String(localized: "voice.female")
                         : String(localized: "voice.male"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.brown)
                        .fontWeight(.medium)
                }
                if isPreviewing {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.brown)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reminder
    private func scheduleReminder(enabled: Bool) {
        Task {
            if enabled {
                let granted = await NotificationManager.shared.requestAuthorization()
                if granted {
                    NotificationManager.shared.scheduleDailyReminder(
                        hour: reminderHour,
                        minute: reminderMinute,
                        enabled: true
                    )
                } else {
                    // User denied notifications — revert toggle
                    await MainActor.run { reminderEnabled = false }
                }
            } else {
                NotificationManager.shared.scheduleDailyReminder(
                    hour: 0, minute: 0, enabled: false
                )
            }
        }
    }

    // MARK: - Voice Refresh
    private func refreshVoices() {
        if availableVoices.isEmpty {
            availableVoices = SpeechManager.rankedVoices()
        }
    }

    // MARK: - Export
    private func exportEntries() {
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.deletedAt == nil },
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
                text += entry.content + "\n"

                // Embed photos as Base64
                if let photos = entry.photos?.sorted(by: { $0.sortOrder < $1.sortOrder }), !photos.isEmpty {
                    for photo in photos {
                        let base64 = photo.imageData.base64EncodedString()
                        text += "[PHOTO]\(base64)[/PHOTO]\n"
                    }
                }

                text += "\n"
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
                let allExisting = try modelContext.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.deletedAt == nil }))
                let existingSet = Set(allExisting.map { "\($0.createdAt.timeIntervalSince1970)|\($0.content)" })

                for entryData in imported {
                    let key = "\(entryData.date.timeIntervalSince1970)|\(entryData.content)"
                    if existingSet.contains(key) {
                        skippedCount += 1
                    } else {
                        let entry = JournalEntry(content: entryData.content, createdAt: entryData.date)
                        // Restore photos
                        if !entryData.photos.isEmpty {
                            var photoObjects: [JournalPhoto] = []
                            for (index, photoData) in entryData.photos.enumerated() {
                                let photo = JournalPhoto(imageData: photoData, sortOrder: index)
                                photoObjects.append(photo)
                            }
                            entry.photos = photoObjects
                        }
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
    private func parseImportedEntries(from text: String) -> [(date: Date, content: String, photos: [Data])] {
        var entries: [(date: Date, content: String, photos: [Data])] = []

        let lines = text.components(separatedBy: .newlines)
        var currentDate: Date?
        var currentContent: String = ""
        var currentPhotos: [Data] = []
        var inContent = false

        for line in lines {
            // Detect photo line: [PHOTO]base64[/PHOTO]
            if line.hasPrefix("[PHOTO]") && line.contains("[/PHOTO]") {
                let base64 = line
                    .replacingOccurrences(of: "[PHOTO]", with: "")
                    .replacingOccurrences(of: "[/PHOTO]", with: "")
                if let data = Data(base64Encoded: base64), !data.isEmpty {
                    currentPhotos.append(data)
                }
                continue
            }

            // Detect date line: starts with [ISO8601]
            if line.hasPrefix("[") && line.contains("]") {
                // Save previous entry if we have one
                if let date = currentDate, !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    entries.append((date: date, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines), photos: currentPhotos))
                }

                // Extract ISO date
                if let bracketEnd = line.firstIndex(of: "]") {
                    let isoString = String(line[line.index(after: line.startIndex)..<bracketEnd])
                    currentDate = DateFormatter.iso8601.date(from: isoString) ?? DateFormatter.iso8601Full.date(from: isoString)
                    currentContent = ""
                    currentPhotos = []
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
            entries.append((date: date, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines), photos: currentPhotos))
        }

        return entries
    }
}

#Preview {
    SettingsView()
}
