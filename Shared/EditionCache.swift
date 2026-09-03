import Foundation

/// The last edition we loaded, written to the app group so the widget and the
/// Siri intent can read it without a network call.
enum EditionCache {
    static let appGroup = "group.com.sampreston.onepagenews"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "edition.json")
    }

    static func save(_ edition: Edition) {
        guard let url = fileURL, let data = try? JSONEncoder.onePage().encode(edition) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> Edition? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.onePage().decode(Edition.self, from: data)
    }

    /// The fixture edition bundled with the app. Always available.
    static func bundled(in bundle: Bundle = .main) -> Edition? {
        guard let url = bundle.url(forResource: "FixtureEdition", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.onePage().decode(Edition.self, from: data)
    }

    /// Cached edition, or the bundled one. Never nil in a correctly built app.
    static func loadOrBundled() -> Edition? {
        load() ?? bundled()
    }
}

/// Settings the widget and intents need, kept in the shared defaults.
enum SharedDefaults {
    static let suite = UserDefaults(suiteName: EditionCache.appGroup) ?? .standard
    static let selectedTopicsKey = "selectedTopics"

    static var selectedTopics: [Topic] {
        get { (suite.stringArray(forKey: selectedTopicsKey) ?? []).compactMap(Topic.init(rawValue:)) }
        set { suite.set(newValue.map(\.rawValue), forKey: selectedTopicsKey) }
    }
}
