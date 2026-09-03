import SwiftUI

/// What happened. Not in dispute. Disputed. Framing, collapsed. Why it matters.
/// Sources, always visible.
///
/// The signature move is the spine. It is drawn as ONE overlay over the facts
/// and the disputes, from the rows' real positions, so every segment meets the
/// next one: solid down the facts and the claim, a fork into two dashed strands
/// for the two sides, a join back into one line. It reveals top to bottom.
///
/// The two sides begin as one block on the line. As the wipe crosses the fork
/// and the curve is drawn, the second side slides out to its own column and
/// arrives where the curve lands.
struct StoryDetailView: View {
    let story: Story
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                Text(story.whatHappened)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                SpinedSection(
                    facts: story.notInDispute,
                    disputes: story.disputed,
                    stacked: typeSize.isAccessibilitySize
                )

                if !story.framing.isEmpty {
                    FramingSection(framing: story.framing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Why it matters", symbol: "arrow.turn.down.right")
                    Text(story.whyItMatters)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SourcesSection(sources: story.sources, storyID: story.id)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(story.headline)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                if story.topic != .general {
                    TopicTag(topic: story.topic)
                }
                Text(story.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Spine

enum Spine {
    static let width: CGFloat = 3
    static let inset: CGFloat = 6          // left edge of the main strand
    static let textInset: CGFloat = 18     // text starts here, clear of the strand
    static let gap: CGFloat = 28           // height of a fork or a join
    static let columnSpacing: CGFloat = 14
    static let dash: [CGFloat] = [5, 4]

    /// x of the main strand's center line.
    static var x0: CGFloat { inset + width / 2 }
}

/// A row that the spine runs beside, reported by the row's real bounds.
struct SpineNode {
    enum Kind { case solid, fork, sides, join }
    let kind: Kind
    let bounds: Anchor<CGRect>
}

struct SpineKey: PreferenceKey {
    static var defaultValue: [SpineNode] = []
    static func reduce(value: inout [SpineNode], nextValue: () -> [SpineNode]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func spineNode(_ kind: SpineNode.Kind) -> some View {
        anchorPreference(key: SpineKey.self, value: .bounds) { [SpineNode(kind: kind, bounds: $0)] }
    }
}

/// Where the first fork sits, so the second side can slide out exactly while
/// the curve is being drawn.
struct SpineMeasure: Equatable {
    var height: CGFloat = 0
    var forkTop: CGFloat = 0
    var forkBottom: CGFloat = 0
    var slideDistance: CGFloat = 0
}

/// Slides the second side out of the first. Animatable on `progress`, so the
/// slide follows the wipe: 0 until the wipe reaches the fork, 1 when it has
/// crossed it, whatever curve the outer animation uses.
struct ForkSlide: ViewModifier, Animatable {
    var progress: CGFloat
    let measure: SpineMeasure
    let enabled: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var slide: CGFloat {
        guard enabled, measure.forkBottom > measure.forkTop else { return 1 }
        let revealed = measure.height * progress
        let p = min(1, max(0, (revealed - measure.forkTop) / (measure.forkBottom - measure.forkTop)))
        return 1 - (1 - p) * (1 - p)
    }

    func body(content: Content) -> some View {
        content.offset(x: -(1 - slide) * measure.slideDistance)
    }
}

/// Not in dispute, then each dispute: claim, fork, two sides, join.
struct SpinedSection: View {
    let facts: [String]
    let disputes: [Dispute]
    let stacked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var measure = SpineMeasure()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Not in dispute", symbol: "checkmark.seal.fill")
                .padding(.leading, Spine.textInset)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(facts.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, Spine.textInset)
            .spineNode(.solid)
            .accessibilityElement(children: .contain)

            ForEach(Array(disputes.enumerated()), id: \.offset) { index, dispute in
                VStack(alignment: .leading, spacing: 6) {
                    if index == 0 {
                        SectionLabel(title: "Disputed", symbol: "arrow.triangle.branch")
                            .padding(.top, 14)
                    }
                    Text(dispute.claim)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text("The claim in dispute: \(dispute.claim)"))
                }
                .padding(.leading, Spine.textInset)
                .spineNode(.solid)

                Color.clear
                    .frame(height: Spine.gap)
                    .spineNode(.fork)

                let layout = stacked
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: Spine.columnSpacing))
                layout {
                    SideView(who: dispute.sideAWho, position: dispute.sideAPosition)
                    SideView(who: dispute.sideBWho, position: dispute.sideBPosition)
                        .modifier(ForkSlide(progress: progress, measure: measure, enabled: !stacked))
                        .zIndex(1)
                }
                .spineNode(.sides)

                Color.clear
                    .frame(height: Spine.gap)
                    .spineNode(.join)
            }
        }
        .overlayPreferenceValue(SpineKey.self) { nodes in
            GeometryReader { proxy in
                let rects = nodes.map { ($0.kind, proxy[$0.bounds]) }
                SpineDrawing(rects: rects, stacked: stacked, progress: progress)
                    .onAppear { measure = SpineDrawing.measure(rects) }
                    .onChange(of: proxy.size) { _, _ in measure = SpineDrawing.measure(rects) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeOut(duration: 1.1).delay(0.1)) { progress = 1 }
            }
        }
    }
}

/// Builds the solid and dashed paths from the rows' rectangles and reveals
/// them top to bottom.
struct SpineDrawing: View {
    let rects: [(SpineNode.Kind, CGRect)]
    let stacked: Bool
    let progress: CGFloat

    var body: some View {
        let paths = build()
        ZStack {
            paths.solid
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: Spine.width, lineCap: .round))
            paths.dashed
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: Spine.width, lineCap: .round, dash: Spine.dash))
        }
        .mask(alignment: .top) {
            Rectangle().frame(height: max(0, paths.height * progress))
        }
    }

    static func measure(_ rects: [(SpineNode.Kind, CGRect)]) -> SpineMeasure {
        var m = SpineMeasure()
        m.height = rects.map(\.1.maxY).max() ?? 0
        if let fork = rects.first(where: { $0.0 == .fork })?.1 {
            m.forkTop = fork.minY
            m.forkBottom = fork.maxY
        }
        if let sides = rects.first(where: { $0.0 == .sides })?.1 {
            m.slideDistance = (sides.width - Spine.columnSpacing) / 2 + Spine.columnSpacing
        }
        return m
    }

    private func build() -> (solid: Path, dashed: Path, height: CGFloat) {
        var solid = Path()
        var dashed = Path()
        let x0 = Spine.x0
        var y: CGFloat? = nil          // where the previous segment ended
        var bottom: CGFloat = 0
        var xB = x0                    // the right strand's x, set by each fork

        for (kind, rect) in rects {
            let top = y ?? rect.minY
            switch kind {
            case .solid:
                solid.move(to: CGPoint(x: x0, y: top))
                solid.addLine(to: CGPoint(x: x0, y: rect.maxY))
            case .fork:
                xB = rightStrandX(after: rect)
                solid.move(to: CGPoint(x: x0, y: top))
                solid.addLine(to: CGPoint(x: x0, y: rect.maxY))
                if abs(xB - x0) > 1 {
                    solid.move(to: CGPoint(x: x0, y: rect.minY))
                    solid.addCurve(
                        to: CGPoint(x: xB, y: rect.maxY),
                        control1: CGPoint(x: x0, y: rect.midY + 6),
                        control2: CGPoint(x: xB, y: rect.midY - 6)
                    )
                }
            case .sides:
                dashed.move(to: CGPoint(x: x0, y: top))
                dashed.addLine(to: CGPoint(x: x0, y: rect.maxY))
                if abs(xB - x0) > 1 {
                    dashed.move(to: CGPoint(x: xB, y: top))
                    dashed.addLine(to: CGPoint(x: xB, y: rect.maxY))
                }
            case .join:
                dashed.move(to: CGPoint(x: x0, y: top))
                dashed.addLine(to: CGPoint(x: x0, y: rect.minY))
                solid.move(to: CGPoint(x: x0, y: rect.minY))
                solid.addLine(to: CGPoint(x: x0, y: rect.maxY))
                if abs(xB - x0) > 1 {
                    dashed.move(to: CGPoint(x: xB, y: top))
                    dashed.addLine(to: CGPoint(x: xB, y: rect.minY))
                    solid.move(to: CGPoint(x: xB, y: rect.minY))
                    solid.addCurve(
                        to: CGPoint(x: x0, y: rect.maxY),
                        control1: CGPoint(x: xB, y: rect.midY + 6),
                        control2: CGPoint(x: x0, y: rect.midY - 6)
                    )
                }
            }
            y = rect.maxY
            bottom = max(bottom, rect.maxY)
        }
        return (solid, dashed, bottom)
    }

    /// The right column's strand sits at the same inset as the main one, from
    /// the column's own left edge. When the sides are stacked there is no
    /// right column and both strands share x0.
    private func rightStrandX(after fork: CGRect) -> CGFloat {
        guard !stacked,
              let sides = rects.first(where: { $0.0 == .sides && $0.1.minY >= fork.maxY - 1 })?.1 else {
            return Spine.x0
        }
        let columnWidth = (sides.width - Spine.columnSpacing) / 2
        return sides.minX + columnWidth + Spine.columnSpacing + Spine.x0
    }
}

struct SideView: View {
    let who: String
    let position: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(who)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(position)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.trailing, 10)
        .padding(.leading, Spine.textInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemBackground))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.11))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(who) says: \(position)"))
    }
}

struct FramingSection: View {
    let framing: [Framing]
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(framing) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(item.outlet)
                                .font(.caption.weight(.semibold))
                            LeanBadge(lean: item.lean)
                        }
                        Text(item.howTheyPutIt)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 10)
        } label: {
            SectionLabel(title: "How each outlet put it", symbol: "text.quote")
        }
        .tint(.secondary)
    }
}

struct SourcesSection: View {
    let sources: [Source]
    let storyID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Sources", symbol: "link")
            ForEach(sources) { source in
                Link(destination: source.url) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.outlet)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(source.url.host() ?? source.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        LeanBadge(lean: source.lean)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
                }
                .accessibilityLabel(Text("\(source.outlet), leans \(source.lean.title). Opens the original article."))
            }
            if let report = reportURL {
                Link("Report an error", destination: report)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var reportURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "corrections@1page.news"
        components.queryItems = [URLQueryItem(name: "subject", value: "Error in story \(storyID)")]
        return components.url
    }
}

#Preview {
    NavigationStack {
        if let story = EditionCache.bundled()?.stories.first {
            StoryDetailView(story: story)
        }
    }
}
