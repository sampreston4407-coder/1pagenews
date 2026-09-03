import Foundation
import Observation

enum TextSize: String, CaseIterable, Identifiable {
    case system, large, larger, largest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .large: "Large"
        case .larger: "Larger"
        case .largest: "Largest"
        }
    }
}

/// User settings. Persisted on every change. Topics also go to the shared
/// defaults so the widget and Siri see the same selection.
@Observable
final class Preferences {
    static let defaultServerURL = "https://api-production-50ff.up.railway.app"

    private enum Keys {
        static let topics = "prefs.topics"
        static let notificationsOn = "prefs.notificationsOn"
        static let notificationMinutes = "prefs.notificationMinutes"
        static let textSize = "prefs.textSize"
        static let serverURL = "prefs.serverURL"
    }

    private let defaults: UserDefaults

    var selectedTopics: [Topic] {
        didSet {
            defaults.set(selectedTopics.map(\.rawValue), forKey: Keys.topics)
            SharedDefaults.selectedTopics = selectedTopics
        }
    }

    var notificationsOn: Bool {
        didSet { defaults.set(notificationsOn, forKey: Keys.notificationsOn) }
    }

    /// Minutes after midnight, local time. Default 7:00.
    var notificationMinutes: Int {
        didSet { defaults.set(notificationMinutes, forKey: Keys.notificationMinutes) }
    }

    var textSize: TextSize {
        didSet { defaults.set(textSize.rawValue, forKey: Keys.textSize) }
    }

    var serverURLString: String {
        didSet { defaults.set(serverURLString, forKey: Keys.serverURL) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedTopics = (defaults.stringArray(forKey: Keys.topics) ?? []).compactMap(Topic.init(rawValue:))
        notificationsOn = defaults.bool(forKey: Keys.notificationsOn)
        notificationMinutes = defaults.object(forKey: Keys.notificationMinutes) as? Int ?? 7 * 60
        textSize = defaults.string(forKey: Keys.textSize).flatMap(TextSize.init(rawValue:)) ?? .system
        serverURLString = defaults.string(forKey: Keys.serverURL) ?? Preferences.defaultServerURL
    }

    func isOn(_ topic: Topic) -> Bool {
        topic == .general || selectedTopics.contains(topic)
    }

    func set(_ topic: Topic, on: Bool) {
        guard topic != .general else { return }
        if on, !selectedTopics.contains(topic) {
            selectedTopics.append(topic)
        } else if !on {
            selectedTopics.removeAll { $0 == topic }
        }
    }

    var notificationTime: Date {
        get {
            Calendar.current.date(bySettingHour: notificationMinutes / 60, minute: notificationMinutes % 60, second: 0, of: Date()) ?? Date()
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            notificationMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
        }
    }

    var serverURL: URL? {
        let trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", url.host() != nil else { return nil }
        return url
    }
}
