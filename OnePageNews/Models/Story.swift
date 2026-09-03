import Foundation

/// One item on the one-page briefing, with everything the detail screen needs.
struct Story: Codable, Identifiable, Hashable {
    let id: String
    let headline: String
    /// One or two sentences. This is all the reader sees on the briefing page.
    let summary: String
    let topic: Topic
    let importance: Importance
    let publishedAt: Date
    let whyItMatters: String
    /// Verified, framing-free statements. Shown first on the detail screen.
    let facts: [String]
    let perspectives: Perspectives
    let sources: [Source]

    /// Ordering used for the briefing page: most important first, then newest.
    static func briefingOrder(_ lhs: Story, _ rhs: Story) -> Bool {
        if lhs.importance != rhs.importance {
            return lhs.importance > rhs.importance
        }
        return lhs.publishedAt > rhs.publishedAt
    }
}

enum Importance: Int, Codable, Comparable, Hashable {
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: Importance, rhs: Importance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The payload the app consumes, whether from the bundled sample file or a server.
struct Briefing: Codable, Hashable {
    let generatedAt: Date
    let stories: [Story]

    func filtered(to topics: Set<Topic>) -> Briefing {
        Briefing(generatedAt: generatedAt, stories: stories.filter { topics.contains($0.topic) })
    }
}
