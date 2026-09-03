import SwiftUI

/// What happened. Not in dispute. Disputed. Framing, collapsed. Why it matters.
/// Sources, always visible.
///
/// The signature move is the spine: one solid line runs down the facts, forks
/// into two dashed strands through each dispute, and joins again after.
struct StoryDetailView: View {
    let story: Story

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                Text(story.whatHappened)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                NotInDisputeSection(items: story.notInDispute, forksBelow: !story.disputed.isEmpty)

                if !story.disputed.isEmpty {
                    DisputedSection(disputes: story.disputed)
                }

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

// MARK: - Spine geometry

enum Spine {
    static let width: CGFloat = 3
    static let inset: CGFloat = 6        // x of the main strand
    static let forkHeight: CGFloat = 28
    static let dash: [CGFloat] = [5, 4]
}

struct NotInDisputeSection: View {
    let items: [String]
    let forksBelow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Not in dispute", symbol: "checkmark.seal.fill")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 16)
                }
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: Spine.width)
                    .padding(.leading, Spine.inset)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct DisputedSection: View {
    let disputes: [Dispute]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var drawn: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForkShape()
                .trim(from: 0, to: drawn)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: Spine.width, lineCap: .round))
                .frame(height: Spine.forkHeight)
                .accessibilityHidden(true)

            SectionLabel(title: "Disputed", symbol: "arrow.triangle.branch")
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(disputes.enumerated()), id: \.offset) { _, dispute in
                    DisputeView(dispute: dispute, stacked: typeSize.isAccessibilitySize)
                }
            }

            JoinShape()
                .trim(from: 0, to: drawn)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: Spine.width, lineCap: .round))
                .frame(height: Spine.forkHeight)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .onAppear {
            if reduceMotion {
                drawn = 1
            } else {
                withAnimation(.easeOut(duration: 0.7).delay(0.15)) { drawn = 1 }
            }
        }
    }
}

/// One line becomes two. Starts at the main strand, one branch goes straight
/// down, the other sweeps to the right column.
struct ForkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let x0 = rect.minX + Spine.inset + Spine.width / 2
        let x1 = rect.midX + Spine.inset + Spine.width / 2
        p.move(to: CGPoint(x: x0, y: rect.minY))
        p.addLine(to: CGPoint(x: x0, y: rect.maxY))
        p.move(to: CGPoint(x: x0, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: x1, y: rect.maxY),
            control1: CGPoint(x: x0, y: rect.midY + 6),
            control2: CGPoint(x: x1, y: rect.midY - 6)
        )
        return p
    }
}

/// Two lines become one again.
struct JoinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let x0 = rect.minX + Spine.inset + Spine.width / 2
        let x1 = rect.midX + Spine.inset + Spine.width / 2
        p.move(to: CGPoint(x: x0, y: rect.minY))
        p.addLine(to: CGPoint(x: x0, y: rect.maxY))
        p.move(to: CGPoint(x: x1, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: x0, y: rect.maxY),
            control1: CGPoint(x: x1, y: rect.midY + 6),
            control2: CGPoint(x: x0, y: rect.midY - 6)
        )
        return p
    }
}

struct DisputeView: View {
    let dispute: Dispute
    let stacked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dispute.claim)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)
                .accessibilityLabel(Text("The claim in dispute: \(dispute.claim)"))

            let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                SideView(who: dispute.sideAWho, position: dispute.sideAPosition)
                SideView(who: dispute.sideBWho, position: dispute.sideBPosition)
            }
        }
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
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            DashedStrand()
                .padding(.leading, Spine.inset)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(who) says: \(position)"))
    }
}

/// The dashed strand: same line, argued instead of settled.
struct DashedStrand: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: Spine.width / 2, y: 0))
                p.addLine(to: CGPoint(x: Spine.width / 2, y: geo.size.height))
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: Spine.width, lineCap: .round, dash: Spine.dash))
        }
        .frame(width: Spine.width)
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
