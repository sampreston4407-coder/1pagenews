import Foundation

/// Fetches a briefing from a server that implements `GET /briefing?topics=a,b`.
/// See the README for the JSON contract.
struct RemoteNewsProvider: NewsProvider {
    let baseURL: URL
    var session: URLSession = .shared

    func fetchBriefing(topics: Set<Topic>) async throws -> Briefing {
        let endpoint = baseURL.appending(path: "briefing")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        let topicList = topics.map(\.rawValue).sorted().joined(separator: ",")
        components.queryItems = [URLQueryItem(name: "topics", value: topicList)]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NewsProviderError.badResponse(statusCode: http.statusCode)
        }
        return try JSONDecoder.briefing().decode(Briefing.self, from: data).filtered(to: topics)
    }
}
