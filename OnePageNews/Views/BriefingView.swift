import SwiftUI

/// The one page. Everything the reader needs to know today, nothing more.
struct BriefingView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
                .navigationDestination(for: Story.self) { story in
                    StoryDetailView(story: story)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $isShowingSettings, onDismiss: {
                    Task { await model.refresh() }
                }) {
                    SettingsView()
                }
                .task {
                    if model.stories.isEmpty {
                        await model.refresh()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.stories.isEmpty {
            ProgressView("Building your briefing…")
        } else if let message = model.errorMessage, model.stories.isEmpty {
            ContentUnavailableView {
                Label("Couldn't load your briefing", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task { await model.refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if model.briefing.isEmpty {
            ContentUnavailableView {
                Label("Nothing to show", systemImage: "newspaper")
            } description: {
                Text("Add a few topics in Settings and pull to refresh.")
            } actions: {
                Button("Open Settings") {
                    isShowingSettings = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            storyList
        }
    }

    private var storyList: some View {
        List {
            Section {
                ForEach(model.briefing) { story in
                    NavigationLink(value: story) {
                        StoryRow(story: story)
                    }
                }
            } header: {
                BriefingHeader(
                    count: model.briefing.count,
                    updatedAt: model.generatedAt,
                    isSampleData: model.isUsingSampleData
                )
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await model.refresh()
        }
    }
}

private struct BriefingHeader: View {
    let count: Int
    let updatedAt: Date?
    let isSampleData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(count == 1 ? "1 thing to know" : "\(count) things to know")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                if let updatedAt {
                    Text("Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                }
                if isSampleData {
                    Text("·")
                    Label("Sample data", systemImage: "flask")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 6)
    }
}

struct StoryRow: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TopicTag(topic: story.topic)
                if story.importance == .high {
                    Label("Need to know", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
                Text(story.publishedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(story.headline)
                .font(.headline)
            Text(story.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BriefingView()
        .environment(AppModel(preferences: Preferences(defaults: UserDefaults(suiteName: "preview")!)))
}
