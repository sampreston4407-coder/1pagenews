import SwiftUI

/// Tap-in view for one story. The facts come first and are always visible;
/// the Left / Unbiased / Right switcher sits below them.
struct StoryDetailView: View {
    let story: Story
    @State private var selectedTab: PerspectiveTab = .unbiased

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                FactsCard(facts: story.facts)
                whyItMatters
                perspectives
                SourcesList(sources: story.sources)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TopicTag(topic: story.topic)
                Text(story.publishedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(story.headline)
                .font(.title2.weight(.bold))
            Text(story.summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var whyItMatters: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why it matters", systemImage: "lightbulb")
                .font(.headline)
            Text(story.whyItMatters)
        }
        .card()
    }

    private var perspectives: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it's being covered")
                .font(.headline)
            Picker("Perspective", selection: $selectedTab) {
                ForEach(PerspectiveTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            PerspectiveCard(tab: selectedTab, perspective: story.perspectives[selectedTab])
                .id(selectedTab)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.15), value: selectedTab)
    }
}

struct FactsCard: View {
    let facts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("The facts", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            Text("Only what is confirmed across independent sources. No framing, no opinion.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                    Text(fact)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }
}

struct PerspectiveCard: View {
    let tab: PerspectiveTab
    let perspective: Perspective

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label(tab.title, systemImage: tab.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tab.color)
                Text(tab.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(perspective.summary)
                .fixedSize(horizontal: false, vertical: true)
            if !perspective.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(perspective.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(tab.color)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(point)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .card()
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tab.color)
                .frame(width: 4)
                .padding(.vertical, 12)
        }
    }
}

struct SourcesList: View {
    let sources: [Source]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.headline)
            ForEach(sources) { source in
                Link(destination: source.url) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
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
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
    }
}
