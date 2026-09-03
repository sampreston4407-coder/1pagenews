import SwiftUI

extension Lean {
    var color: Color {
        switch self {
        case .left: .blue
        case .center: .secondary
        case .right: .red
        }
    }
}

struct LeanBadge: View {
    let lean: Lean

    var body: some View {
        Text(lean.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(lean.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(lean.color.opacity(0.12)))
            .accessibilityLabel(Text("Leans \(lean.title)"))
    }
}

struct TopicTag: View {
    let topic: Topic

    var body: some View {
        Label(topic.title, systemImage: topic.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
    }
}

struct SectionLabel: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

extension Animation {
    /// Respect Reduce Motion on every transition.
    static func respectful(_ reduceMotion: Bool, _ animation: Animation = .easeOut(duration: 0.45)) -> Animation? {
        reduceMotion ? nil : animation
    }
}
