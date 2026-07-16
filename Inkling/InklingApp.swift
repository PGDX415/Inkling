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
    @State private var isLocked = false
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([JournalEntry.self])
        // Explicitly reference the CloudKit container from entitlements
        let config = ModelConfiguration(
            cloudKitDatabase: .private("iCloud.com.gongdexin.paul.Inkling")
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("[Inkling] ModelContainer initialized with CloudKit sync enabled.")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(isActive: $showSplash)
                        .transition(.opacity)
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
                    .onAppear {
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
