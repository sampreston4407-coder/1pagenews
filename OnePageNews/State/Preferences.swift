import Foundation
import Observation

/// How many stories make it onto the one page. The whole point is that it
/// stays short, so even "Full" is capped.
enum BriefingLength: String, CaseIterable, Codable, Identifiable {
    case quick
    case standard
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: "Quick"
        case .standard: "Standard"
        case .full: "Full"
        }
    }

    var maxStories: Int {
        switch self {
        case .quick: 5
        case .standard: 8
        case .full: 12
        }
    }

    var detail: String {
        switch self {
        case .quick: "About a one-minute read."
        case .standard: "A couple of minutes. The default."
        case .full: "Everything that made the cut today."
        }
    }
}

/// User settings, persisted to `UserDefaults` as soon as they change.
@Observable
final class Preferences {
    private enum Keys {
        static let selectedTopics = "preferences.selectedTopics"
        static let briefingLength = "preferences.briefingLength"
        static let serverURL = "preferences.serverURL"
    }

    static let defaultTopics: Set<Topic> = [.general, .world, .finance]

    private let defaults: UserDefaults

    var selectedTopics: Set<Topic> {
        didSet { save(selectedTopics, forKey: Keys.selectedTopics) }
    }

    var briefingLength: BriefingLength {
        didSet { defaults.set(briefingLength.rawValue, forKey: Keys.briefingLength) }
    }

    /// Raw text from the Settings field. Empty means "use the bundled sample data".
    var serverURLString: String {
        didSet { defaults.set(serverURLString, forKey: Keys.serverURL) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.selectedTopics),
           let stored = try? JSONDecoder().decode(Set<Topic>.self, from: data) {
            selectedTopics = stored
        } else {
            selectedTopics = Preferences.defaultTopics
        }

        briefingLength = defaults.string(forKey: Keys.briefingLength)
            .flatMap(BriefingLength.init(rawValue:)) ?? .standard

        serverURLString = defaults.string(forKey: Keys.serverURL) ?? ""
    }

    /// The topics actually used for fetching. General is always included, no
    /// matter what ends up in `selectedTopics`.
    var activeTopics: Set<Topic> {
        selectedTopics.union([.general])
    }

    /// A usable server URL, or nil when the field is empty or not http(s).
    var serverURL: URL? {
        let trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil else {
            return nil
        }
        return url
    }

    func setTopic(_ topic: Topic, enabled: Bool) {
        if enabled || topic.isRequired {
            selectedTopics.insert(topic)
        } else {
            selectedTopics.remove(topic)
        }
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
