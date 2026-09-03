import Foundation

/// The three readings of a story. `unbiased` is the product's reason to exist;
/// `left` and `right` are there so the reader can see how each side frames it.
struct Perspectives: Codable, Hashable {
    let left: Perspective
    let unbiased: Perspective
    let right: Perspective

    subscript(tab: PerspectiveTab) -> Perspective {
        switch tab {
        case .left: left
        case .unbiased: unbiased
        case .right: right
        }
    }
}

struct Perspective: Codable, Hashable {
    let summary: String
    let keyPoints: [String]
}

enum PerspectiveTab: String, CaseIterable, Identifiable, Hashable {
    case left
    case unbiased
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Left"
        case .unbiased: "Unbiased"
        case .right: "Right"
        }
    }

    var caption: String {
        switch self {
        case .left: "How left-leaning outlets are framing it."
        case .unbiased: "Just what happened, with no political framing."
        case .right: "How right-leaning outlets are framing it."
        }
    }
}

struct Source: Codable, Identifiable, Hashable {
    let name: String
    let url: URL
    let lean: SourceLean

    var id: String { url.absoluteString }
}

enum SourceLean: String, Codable, CaseIterable, Hashable {
    case left
    case center
    case right

    var title: String {
        switch self {
        case .left: "Leans left"
        case .center: "Center"
        case .right: "Leans right"
        }
    }
}
