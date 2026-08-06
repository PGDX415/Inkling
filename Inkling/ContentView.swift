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
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            JournalListView()
                .tabItem {
                    Label(String(localized: "tab.journal"), systemImage: "book.pages")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Label(String(localized: "tab.calendar"), systemImage: "calendar")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(.brown)
        .onAppear {
            configureTabBarAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("InklingSelectTab"))) { notif in
            if let tab = notif.object as? Int {
                selectedTab = tab
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        #if targetEnvironment(macCatalyst)
        // Prevent Mac Catalyst window from being too large
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 800, height: 600)
        }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
