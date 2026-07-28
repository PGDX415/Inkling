import UserNotifications

/// Manages daily writing reminder notification
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// Request notification permission
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schedule a daily reminder at the given hour and minute
    func scheduleDailyReminder(hour: Int, minute: Int, enabled: Bool) {
        let center = UNUserNotificationCenter.current()

        // Remove existing reminder
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder.title")
        content.body = String(localized: "reminder.body")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-reminder", content: content, trigger: trigger)

        center.add(request)
    }
}
