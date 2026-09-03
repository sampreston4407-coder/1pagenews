import Foundation

// The content model. Mirrors backend/app/models.py field for field.
// Shared between the app and the widget extension.

enum Lean: String, Codable, Hashable {
    case left, center, right

    var title: String {
        switch self {
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        }
    }
}

enum Topic: String, Codable, CaseIterable, Identifiable, Hashable {
    case general, ai, finance, environment, sports, health, science, local

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .ai: "AI"
        case .finance: "Finance"
        case .environment: "Environment"
        case .sports: "Sports"
        case .health: "Health"
        case .science: "Science"
        case .local: "Local"
        }
    }

    var symbol: String {
        switch self {
        case .general: "newspaper"
        case .ai: "cpu"
        case .finance: "chart.line.uptrend.xyaxis"
        case .environment: "leaf"
        case .sports: "sportscourt"
        case .health: "heart"
        case .science: "atom"
        case .local: "mappin.and.ellipse"
        }
    }

    static let optional: [Topic] = allCases.filter { $0 != .general }
}

struct Source: Codable, Hashable, Identifiable {
    let outlet: String
    let url: URL
    let lean: Lean
    let covers: [String]

    var id: String { url.absoluteString }
}

struct Dispute: Codable, Hashable {
    let claim: String
    let sideAPosition: String
    let sideAWho: String
    let sideBPosition: String
    let sideBWho: String
}

struct Framing: Codable, Hashable, Identifiable {
    let outlet: String
    let lean: Lean
    let howTheyPutIt: String

    var id: String { outlet + howTheyPutIt }
}

struct Story: Codable, Hashable, Identifiable {
    let id: String
    let headline: String
    let whatHappened: String
    let notInDispute: [String]
    let disputed: [Dispute]
    let framing: [Framing]
    let whyItMatters: String
    let sources: [Source]
    let updatedAt: Date
    let topic: Topic
}

struct Edition: Codable, Hashable {
    /// Calendar day, "2026-09-03". Kept as a string so it never shifts with time zones.
    let date: String
    let publishedAt: Date
    let nextEditionAt: Date
    let stories: [Story]
    let topicStories: [String: [Story]]

    func stories(for topic: Topic) -> [Story] {
        topicStories[topic.rawValue] ?? []
    }

    /// The day as a Date at local midnight, for display only.
    var day: Date? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

struct MethodologySection: Codable, Hashable, Identifiable {
    let heading: String
    let body: String

    var id: String { heading }
}

struct Methodology: Codable, Hashable {
    let title: String
    let sections: [MethodologySection]
}

struct SourceInfo: Codable, Hashable, Identifiable {
    let outlet: String
    let lean: Lean
    let homepage: URL
    let why: String

    var id: String { outlet }
}

struct Correction: Codable, Hashable, Identifiable {
    let storyId: String
    let editionDate: String
    let correctedAt: Date
    let whatWeSaid: String
    let whatWasTrue: String
    let howWeFoundOut: String

    var id: String { storyId + editionDate }
}

extension Story {
    /// First sentence of what happened. The row on the Today page shows this.
    var oneLine: String {
        let text = whatHappened
        guard let end = text.firstIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) else { return text }
        let next = text.index(after: end)
        // "4.25 percent" has a period that is not a sentence end.
        if next < text.endIndex, !text[next].isWhitespace {
            let rest = String(text[next...])
            if let restEnd = rest.firstIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
                return String(text[..<end]) + "." + String(rest[..<restEnd]) + "."
            }
        }
        return String(text[...end])
    }
}

// MARK: - Decoding

extension JSONDecoder {
    /// Decoder for the backend's JSON: snake_case keys, ISO 8601 dates with or
    /// without fractional seconds.
    static func onePage() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601.parse(raw) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(raw)"))
        }
        return decoder
    }
}

extension JSONEncoder {
    static func onePage() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.fractional.string(from: date))
        }
        return encoder
    }
}

enum ISO8601 {
    /// Accepts "2026-09-03T11:00:00Z" and "2026-09-03T11:00:00.123456Z".
    /// The formatter only reads three fractional digits, so longer fractions
    /// are trimmed first.
    static func parse(_ raw: String) -> Date? {
        if let date = plain.date(from: raw) { return date }
        var text = raw
        if let dot = text.firstIndex(of: "."),
           let end = text[dot...].firstIndex(where: { !$0.isNumber && $0 != "." }) {
            let fraction = text[text.index(after: dot)..<end]
            if fraction.count > 3 {
                text.replaceSubrange(dot..<end, with: "." + fraction.prefix(3))
            }
        }
        return fractional.date(from: text)
    }

    static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
