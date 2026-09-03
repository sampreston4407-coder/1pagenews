import SwiftUI

extension Topic {
    var color: Color {
        switch self {
        case .general: .gray
        case .world: .teal
        case .politics: .purple
        case .ai: .indigo
        case .technology: .blue
        case .finance: .green
        case .environment: .mint
        case .science: .cyan
        case .health: .pink
        }
    }
}

extension PerspectiveTab {
    var color: Color {
        switch self {
        case .left: .blue
        case .unbiased: .accentColor
        case .right: .red
        }
    }

    var symbol: String {
        switch self {
        case .left: "arrow.left.circle"
        case .unbiased: "checkmark.seal"
        case .right: "arrow.right.circle"
        }
    }
}

extension SourceLean {
    var color: Color {
        switch self {
        case .left: .blue
        case .center: .gray
        case .right: .red
        }
    }
}

/// Small capsule showing a topic's icon and name.
struct TopicTag: View {
    let topic: Topic

    var body: some View {
        Label(topic.title, systemImage: topic.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(topic.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(topic.color.opacity(0.14)))
    }
}

/// Small capsule showing which way a source leans.
struct LeanBadge: View {
    let lean: SourceLean

    var body: some View {
        Text(lean.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(lean.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(lean.color.opacity(0.14)))
    }
}

/// Rounded card background used on the detail screen.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}
