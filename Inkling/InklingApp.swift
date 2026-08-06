//
//  InklingApp.swift
//  Inkling
//
//  Created by Paul Dexin Gong on 2026/7/16.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct InklingApp: App {
    @AppStorage("isLockEnabled") private var isLockEnabled = false
    @AppStorage("displayMode") private var displayModeRaw = DisplayMode.system.rawValue
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    @State private var isLocked = false
    @State private var showSplash = true
    @State private var showOnboarding = false
    @State private var syncMonitor = SyncMonitor()
    @Environment(\.scenePhase) private var scenePhase
    @FocusedValue(\.editorActions) private var focusedEditor

    init() {
        CrashDiagnostics.shared.start()
    }

    var sharedModelContainer: ModelContainer = {
        let config = ModelConfiguration(
            cloudKitDatabase: .private("iCloud.com.gongdexin.paul.Inkling")
        )
        do {
            let container = try ModelContainer(
                for: JournalEntry.self, JournalPhoto.self, UserProfile.self,
                migrationPlan: InklingMigrationPlan.self,
                configurations: config
            )
            print("[Inkling] ModelContainer initialized with CloudKit + migration plan.")
            return container
        } catch {
            print("[Inkling] CloudKit container failed: \(error). Falling back to local-only store.")
            do {
                let fallbackConfig = ModelConfiguration()
                let container = try ModelContainer(
                    for: JournalEntry.self, JournalPhoto.self, UserProfile.self,
                    migrationPlan: InklingMigrationPlan.self,
                    configurations: fallbackConfig
                )
                print("[Inkling] Fallback local ModelContainer initialized.")
                return container
            } catch {
                // Last resort: in-memory store — data won't persist but app won't crash
                print("[Inkling] CRITICAL: Local store also failed: \(error). Using in-memory fallback.")
                let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try! ModelContainer(
                    for: JournalEntry.self, JournalPhoto.self, UserProfile.self,
                    migrationPlan: InklingMigrationPlan.self,
                    configurations: memoryConfig
                )
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(isActive: $showSplash)
                        .transition(.opacity)
                        .onChange(of: showSplash) { _, active in
                            if !active && !onboardingCompleted {
                                showOnboarding = true
                            }
                        }
                } else if showOnboarding {
                    OnboardingView(isPresented: $showOnboarding)
                } else {
                    ZStack {
                        ContentView()
                            .opacity(isLocked && isLockEnabled ? 0 : 1)
                            .allowsHitTesting(!(isLocked && isLockEnabled))

                        if isLocked && isLockEnabled {
                            LockView(isLocked: $isLocked)
                                .transition(.opacity)
                        }
                    }
                    .environment(syncMonitor)
                    .environment(StoreManager.shared)
                    .preferredColorScheme(DisplayMode(rawValue: displayModeRaw)?.colorScheme ?? nil)
                    .onAppear {
                        KeychainManager.shared.migrateIfNeeded()
                        if isLockEnabled {
                            isLocked = true
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .background {
                            #if os(iOS)
                            // Request extra time for CloudKit sync to complete gracefully
                            var bgTaskID: UIBackgroundTaskIdentifier = .invalid
                            bgTaskID = UIApplication.shared.beginBackgroundTask {
                                UIApplication.shared.endBackgroundTask(bgTaskID)
                                bgTaskID = .invalid
                            }
                            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                                UIApplication.shared.endBackgroundTask(bgTaskID)
                                bgTaskID = .invalid
                            }
                            #endif
                            if isLockEnabled {
                                isLocked = true
                            }
                        }
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // Tab navigation shortcuts
            CommandGroup(after: .sidebar) {
                Button(String(localized: "tab.journal")) {
                    NotificationCenter.default.post(name: .init("InklingSelectTab"), object: 0)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(String(localized: "tab.calendar")) {
                    NotificationCenter.default.post(name: .init("InklingSelectTab"), object: 1)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button(String(localized: "tab.settings")) {
                    NotificationCenter.default.post(name: .init("InklingSelectTab"), object: 2)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Editor formatting shortcuts
            CommandGroup(after: .textFormatting) {
                Button("**Bold**") {
                    focusedEditor?.insertBold()
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("*Italic*") {
                    focusedEditor?.insertItalic()
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("~~Strikethrough~~") {
                    focusedEditor?.insertStrikethrough()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                Button("# Heading") {
                    focusedEditor?.insertHeading()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("> Quote") {
                    focusedEditor?.insertQuote()
                }
                .keyboardShortcut("'", modifiers: [.command, .shift])

                Button("- List") {
                    focusedEditor?.insertList()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button(String(localized: "editor.preview_mode")) {
                    focusedEditor?.togglePreview()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

        // Secondary window for opening a journal entry on iPad
        #if os(iOS)
        WindowGroup(id: "entry-detail", for: String.self) { $entryUUID in
            if let uuid = entryUUID {
                EntryWindowView(entryUUID: uuid)
            }
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
