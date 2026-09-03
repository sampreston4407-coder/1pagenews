import SwiftUI

/// What happened. Not in dispute. Disputed. Framing, collapsed. Why it matters.
/// Sources, always visible.
///
/// The signature move is the fork. Below the claim, one line starts at the
/// center and immediately splits to the far left and far right. A dashed
/// strand runs down each edge with that side's text beside it, and ends there.
/// It is drawn as one overlay from the rows' real positions and revealed top
/// to bottom. The two sides begin as one block at the center and slide apart
/// while the curves are drawn.
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
    static let inset: CGFloat = 6          // strand distance from the outer edge
    static let textInset: CGFloat = 18     // text starts this far in from the edge
    static let stem: CGFloat = 14          // straight run before the fork
    static let gap: CGFloat = 28           // height of the fork
    static let columnSpacing: CGFloat = 14
    static let dash: [CGFloat] = [5, 4]

    /// Strand center line, measured from the nearest outer edge.
    static var x0: CGFloat { inset + width / 2 }
}

/// A row that the spine is drawn against, reported by the row's real bounds.
struct SpineNode {
    enum Kind { case stem, fork, sides }
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

/// Where the first fork sits, so the two sides can slide apart exactly while
/// the curves are being drawn.
struct SpineMeasure: Equatable {
    var top: CGFloat = 0
    var height: CGFloat = 0
    var forkTop: CGFloat = 0
    var forkBottom: CGFloat = 0
    /// Distance between the two columns' origins. Each side travels half of it.
    var slideDistance: CGFloat = 0
}

/// Slides a side out from the center. Animatable on `progress`, so the slide
/// follows the wipe: 0 until the wipe reaches the fork, 1 when it has crossed
/// it, whatever curve the outer animation uses.
struct ForkSlide: ViewModifier, Animatable {
    var progress: CGFloat
    let measure: SpineMeasure
    let direction: CGFloat   // +1 slides in from the right, -1 from the left
    let enabled: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var slide: CGFloat {
        guard enabled, measure.forkBottom > measure.forkTop else { return 1 }
        let revealed = measure.top + (measure.height - measure.top) * progress
        let p = min(1, max(0, (revealed - measure.forkTop) / (measure.forkBottom - measure.forkTop)))
        return 1 - (1 - p) * (1 - p)
    }

    func body(content: Content) -> some View {
        content.offset(x: direction * (1 - slide) * measure.slideDistance / 2)
    }
}

/// Not in dispute as plain lines. Then each dispute: the claim, a stem from
/// the center, a fork to the far left and far right, and a dashed strand down
/// each edge with that side's text beside it. The strands end there.
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

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(facts.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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

                Color.clear
                    .frame(height: Spine.stem)
                    .spineNode(.stem)

                Color.clear
                    .frame(height: Spine.gap)
                    .spineNode(.fork)

                let layout = stacked
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: Spine.columnSpacing))
                layout {
                    SideView(who: dispute.sideAWho, position: dispute.sideAPosition, edge: .leading)
                        .modifier(ForkSlide(progress: progress, measure: measure, direction: 1, enabled: !stacked))
                    SideView(who: dispute.sideBWho, position: dispute.sideBPosition, edge: stacked ? .leading : .trailing)
                        .modifier(ForkSlide(progress: progress, measure: measure, direction: -1, enabled: !stacked))
                        .zIndex(1)
                }
                .spineNode(.sides)
                .padding(.bottom, 6)
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
                withAnimation(.easeOut(duration: 1.0).delay(0.1)) { progress = 1 }
            }
        }
    }
}

/// Builds the solid and dashed paths from the rows' rectangles and reveals
/// them top to bottom, starting at the first stem.
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
            VStack(spacing: 0) {
                Color.clear.frame(height: paths.top)
                Rectangle().frame(height: max(0, (paths.bottom - paths.top) * progress))
            }
        }
    }

    static func measure(_ rects: [(SpineNode.Kind, CGRect)]) -> SpineMeasure {
        var m = SpineMeasure()
        m.top = rects.first(where: { $0.0 == .stem })?.1.minY ?? 0
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

    private func build() -> (solid: Path, dashed: Path, top: CGFloat, bottom: CGFloat) {
        var solid = Path()
        var dashed = Path()
        var y: CGFloat? = nil
        var top: CGFloat = .greatestFiniteMagnitude
        var bottom: CGFloat = 0

        for (kind, rect) in rects {
            let from = y ?? rect.minY
            let xc = rect.midX
            let xL = rect.minX + Spine.x0
            let xR = rect.maxX - Spine.x0
            switch kind {
            case .stem:
                solid.move(to: CGPoint(x: xc, y: from))
                solid.addLine(to: CGPoint(x: xc, y: rect.maxY))
                top = min(top, rect.minY)
            case .fork:
                solid.move(to: CGPoint(x: xc, y: from))
                solid.addCurve(
                    to: CGPoint(x: xL, y: rect.maxY),
                    control1: CGPoint(x: xc, y: rect.midY + 8),
                    control2: CGPoint(x: xL, y: rect.midY - 8)
                )
                if !stacked {
                    solid.move(to: CGPoint(x: xc, y: from))
                    solid.addCurve(
                        to: CGPoint(x: xR, y: rect.maxY),
                        control1: CGPoint(x: xc, y: rect.midY + 8),
                        control2: CGPoint(x: xR, y: rect.midY - 8)
                    )
                }
            case .sides:
                dashed.move(to: CGPoint(x: xL, y: from))
                dashed.addLine(to: CGPoint(x: xL, y: rect.maxY))
                if !stacked {
                    dashed.move(to: CGPoint(x: xR, y: from))
                    dashed.addLine(to: CGPoint(x: xR, y: rect.maxY))
                }
            }
            // The strands end with the sides. A following dispute starts fresh.
            y = kind == .sides ? nil : rect.maxY
            bottom = max(bottom, rect.maxY)
        }
        if top == .greatestFiniteMagnitude { top = 0 }
        return (solid, dashed, top, bottom)
    }
}

struct SideView: View {
    let who: String
    let position: String
    let edge: HorizontalAlignment

    private var textAlignment: TextAlignment { edge == .trailing ? .trailing : .leading }
    private var frameAlignment: Alignment { edge == .trailing ? .trailing : .leading }

    var body: some View {
        VStack(alignment: edge, spacing: 4) {
            Text(who)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
            Text(position)
                .font(.subheadline)
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.leading, edge == .trailing ? 10 : Spine.textInset)
        .padding(.trailing, edge == .trailing ? Spine.textInset : 10)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
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
