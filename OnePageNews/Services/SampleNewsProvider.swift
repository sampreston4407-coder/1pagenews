import Foundation

/// Serves the briefing bundled with the app. Lets the whole UI work before a
/// backend exists, and doubles as fixture data for tests and previews.
struct SampleNewsProvider: NewsProvider {
    private let fileURL: URL?
    private let simulatedDelay: Duration

    init(bundle: Bundle = .main, simulatedDelay: Duration = .milliseconds(350)) {
        fileURL = bundle.url(forResource: "SampleBriefing", withExtension: "json")
        self.simulatedDelay = simulatedDelay
    }

    func fetchBriefing(topics: Set<Topic>) async throws -> Briefing {
        guard let fileURL else { throw NewsProviderError.missingSampleData }
        let data = try Data(contentsOf: fileURL)
        let briefing = try JSONDecoder.briefing().decode(Briefing.self, from: data)
        if simulatedDelay > .zero {
            try? await Task.sleep(for: simulatedDelay)
        }
        return briefing.filtered(to: topics)
    }
}
