import Foundation
import Observation

/// Screen-independent app state: the loaded stories, loading status, and
/// which provider to use based on the user's settings.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences

    private(set) var stories: [Story] = []
    private(set) var generatedAt: Date?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let sampleProvider: NewsProvider
    private let makeRemoteProvider: (URL) -> NewsProvider

    init(
        preferences: Preferences = Preferences(),
        sampleProvider: NewsProvider = SampleNewsProvider(),
        makeRemoteProvider: @escaping (URL) -> NewsProvider = { RemoteNewsProvider(baseURL: $0) }
    ) {
        self.preferences = preferences
        self.sampleProvider = sampleProvider
        self.makeRemoteProvider = makeRemoteProvider
    }

    var isUsingSampleData: Bool {
        preferences.serverURL == nil
    }

    /// What the one page shows: the most important stories, capped by the
    /// reader's chosen briefing length.
    var briefing: [Story] {
        Array(stories.sorted(by: Story.briefingOrder).prefix(preferences.briefingLength.maxStories))
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let provider = preferences.serverURL.map(makeRemoteProvider) ?? sampleProvider
        do {
            let result = try await provider.fetchBriefing(topics: preferences.activeTopics)
            stories = result.stories
            generatedAt = result.generatedAt
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
