import Foundation
import Observation
import WidgetKit

enum LoadSource {
    case network, cache, bundled
}

struct TopicSection: Identifiable {
    let topic: Topic
    let stories: [Story]
    var id: Topic { topic }
}

@MainActor
@Observable
final class AppModel {
    let preferences: Preferences

    private(set) var edition: Edition?
    private(set) var loadSource: LoadSource = .bundled
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let bundled: EditionProvider
    private let makeRemote: (URL) -> EditionProvider

    init(
        preferences: Preferences = Preferences(),
        bundled: EditionProvider = BundledEditionProvider(),
        makeRemote: @escaping (URL) -> EditionProvider = { RemoteEditionProvider(baseURL: $0) }
    ) {
        self.preferences = preferences
        self.bundled = bundled
        self.makeRemote = makeRemote
        if let cached = EditionCache.load() {
            edition = cached
            loadSource = .cache
        }
    }

    var provider: EditionProvider {
        preferences.serverURL.map(makeRemote) ?? bundled
    }

    /// The seven, in order.
    var seven: [Story] { edition?.stories ?? [] }

    /// Optional topics the reader has on, with whatever ran today.
    var topicSections: [TopicSection] {
        guard let edition else { return [] }
        return preferences.selectedTopics.compactMap { topic in
            let stories = edition.stories(for: topic)
            return stories.isEmpty ? nil : TopicSection(topic: topic, stories: stories)
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await provider.fetchEdition(topics: preferences.selectedTopics)
            edition = fresh
            loadSource = preferences.serverURL == nil ? .bundled : .network
            lastError = nil
            EditionCache.save(fresh)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            lastError = error.localizedDescription
            if edition == nil {
                edition = EditionCache.loadOrBundled()
                loadSource = EditionCache.load() == nil ? .bundled : .cache
            }
        }
    }
}
