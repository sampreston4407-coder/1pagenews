import Foundation

protocol EditionProvider: Sendable {
    func fetchEdition(topics: [Topic]) async throws -> Edition
    func fetchMethodology() async throws -> Methodology
    func fetchSources() async throws -> [SourceInfo]
    func fetchCorrections() async throws -> [Correction]
}

enum ProviderError: LocalizedError {
    case missingBundledFile(String)
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingBundledFile(let name): "\(name) is missing from the app bundle."
        case .badStatus(let code): "The server answered with status \(code)."
        }
    }
}

/// Talks to the backend in `backend/`. Every path is under /v1.
struct RemoteEditionProvider: EditionProvider {
    let baseURL: URL
    var session: URLSession = .shared

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ProviderError.badStatus(http.statusCode)
        }
        return try JSONDecoder.onePage().decode(T.self, from: data)
    }

    func fetchEdition(topics: [Topic]) async throws -> Edition {
        let list = topics.filter { $0 != .general }.map(\.rawValue).sorted().joined(separator: ",")
        let query = list.isEmpty ? [] : [URLQueryItem(name: "topics", value: list)]
        return try await get("v1/edition/today", query: query)
    }

    func fetchMethodology() async throws -> Methodology { try await get("v1/methodology") }
    func fetchSources() async throws -> [SourceInfo] { try await get("v1/sources") }
    func fetchCorrections() async throws -> [Correction] { try await get("v1/corrections") }
}

/// Serves the files in Resources/. Used for previews, tests, and as the
/// fallback when there is no network and no cache.
struct BundledEditionProvider: EditionProvider {
    private let fixture: URL?
    private let methodology: URL?
    private let sources: URL?

    init(bundle: Bundle = .main) {
        fixture = bundle.url(forResource: "FixtureEdition", withExtension: "json")
        methodology = bundle.url(forResource: "Methodology", withExtension: "json")
        sources = bundle.url(forResource: "Sources", withExtension: "json")
    }

    private func load<T: Decodable>(_ url: URL?, name: String) throws -> T {
        guard let url else { throw ProviderError.missingBundledFile(name) }
        return try JSONDecoder.onePage().decode(T.self, from: try Data(contentsOf: url))
    }

    func fetchEdition(topics: [Topic]) async throws -> Edition {
        let edition: Edition = try load(fixture, name: "FixtureEdition.json")
        let keep = edition.topicStories.filter { key, _ in topics.contains { $0.rawValue == key } }
        return Edition(date: edition.date, publishedAt: edition.publishedAt, nextEditionAt: edition.nextEditionAt, stories: edition.stories, topicStories: keep)
    }

    func fetchMethodology() async throws -> Methodology { try load(methodology, name: "Methodology.json") }
    func fetchSources() async throws -> [SourceInfo] { try load(sources, name: "Sources.json") }
    func fetchCorrections() async throws -> [Correction] { [] }
}
