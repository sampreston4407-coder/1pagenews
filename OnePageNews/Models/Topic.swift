import Foundation

/// A subject area the reader can opt into. `general` is always on: it is the
/// "things everyone should know today" baseline that the app is built around.
enum Topic: String, CaseIterable, Codable, Identifiable, Hashable {
    case general
    case world
    case politics
    case ai
    case technology
    case finance
    case environment
    case science
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .world: "World"
        case .politics: "Politics"
        case .ai: "AI"
        case .technology: "Technology"
        case .finance: "Finance"
        case .environment: "Environment"
        case .science: "Science"
        case .health: "Health"
        }
    }

    var detail: String {
        switch self {
        case .general: "The handful of things everyone should know today. Always on."
        case .world: "Major international events and diplomacy."
        case .politics: "Elections, legislation, and government decisions."
        case .ai: "Model releases, regulation, and how AI is changing work."
        case .technology: "Products, platforms, privacy, and security."
        case .finance: "Markets, interest rates, jobs, and the cost of living."
        case .environment: "Climate, energy, weather, and conservation."
        case .science: "Discoveries, space, and research that matters."
        case .health: "Public health, medicine, and approvals."
        }
    }

    /// SF Symbol used for the topic wherever it is shown.
    var symbol: String {
        switch self {
        case .general: "newspaper"
        case .world: "globe"
        case .politics: "building.columns"
        case .ai: "brain"
        case .technology: "cpu"
        case .finance: "chart.line.uptrend.xyaxis"
        case .environment: "leaf"
        case .science: "atom"
        case .health: "heart.text.square"
        }
    }

    /// General can never be switched off.
    var isRequired: Bool { self == .general }

    static var optional: [Topic] { allCases.filter { !$0.isRequired } }

    /// Tolerate topics a future backend might add that this build does not know
    /// about yet: they fall into General instead of failing the whole decode.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Topic(rawValue: raw.lowercased()) ?? .general
    }
}
