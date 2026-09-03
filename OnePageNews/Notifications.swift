import Foundation
import UserNotifications

/// One notification a day, at a time the reader picks. Nothing else, ever.
enum DailyNotification {
    static let identifier = "daily-edition"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(minutesAfterMidnight: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Today's seven are ready")
        content.body = String(localized: "Two minutes and you're caught up.")
        content.sound = .default

        var components = DateComponents()
        components.hour = minutesAfterMidnight / 60
        components.minute = minutesAfterMidnight % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Apply the current preference: schedule, or cancel.
    static func apply(_ preferences: Preferences, muted: Bool = false) {
        if preferences.notificationsOn, !muted {
            schedule(minutesAfterMidnight: preferences.notificationMinutes)
        } else {
            cancel()
        }
    }
}
