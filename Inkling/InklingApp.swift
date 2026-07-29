//
//  InklingApp.swift
//  Inkling
//
//  Created by Paul Dexin Gong on 2026/7/16.
//

import SwiftUI
import SwiftData

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
                        if newPhase == .background || newPhase == .inactive {
                            if isLockEnabled {
                                isLocked = true
                            }
                        }
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("journal.new_entry") {
                    // New entry command for macOS
                    NotificationCenter.default.post(name: .init("InklingNewEntry"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
    }
}
