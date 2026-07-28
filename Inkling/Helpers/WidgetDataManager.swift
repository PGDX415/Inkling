import Foundation

/// Writes app data to shared UserDefaults so the widget can read it
enum WidgetDataManager {
    private static let suite = UserDefaults(suiteName: "group.com.gongdexin.paul.Inkling")

    static func update(streak: Int, hasWrittenToday: Bool, prompt: String) {
        suite?.set(streak, forKey: "widget_streak")
        suite?.set(hasWrittenToday, forKey: "widget_hasWrittenToday")
        suite?.set(prompt, forKey: "widget_prompt")
    }
}
