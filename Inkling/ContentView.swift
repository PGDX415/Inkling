//
//  ContentView.swift
//  Inkling
//
//  Created by Paul Dexin Gong on 2026/7/16.
//

import SwiftUI
import SwiftData

/// Main tab-based navigation container for the app
struct ContentView: View {
    @AppStorage("isLockEnabled") private var isLockEnabled = false

    var body: some View {
        TabView {
            JournalListView()
            CalendarView()
            SettingsView()
        }
        .tint(.brown)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
