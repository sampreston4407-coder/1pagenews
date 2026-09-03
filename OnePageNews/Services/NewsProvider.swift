import Foundation

/// Anything that can produce a briefing for a set of topics.
///
/// Today there are two: the bundled sample file and a remote server that
/// speaks the JSON contract documented in the README.
protocol NewsProvider: Sendable {
    func fetchBriefing(topics: Set<Topic>) async throws -> Briefing
}

enum NewsProviderError: LocalizedError {
    case missingSampleData
    case badResponse(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingSampleData:
            "The sample briefing is missing from the app bundle."
        case .badResponse(let statusCode):
            "The news server responded with status \(statusCode)."
        }
    }
}

extension JSONDecoder {
    /// Decoder configured for the briefing JSON contract (ISO 8601 dates).
    static func briefing() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
