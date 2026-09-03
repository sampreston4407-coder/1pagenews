import SwiftUI

/// Seven stories, then you are done.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

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
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showSettings, onDismiss: {
                    Task { await model.refresh() }
                }) {
                    SettingsView()
                }
                .task {
                    await model.refresh()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let edition = model.edition {
            editionList(edition)
        } else if model.isLoading {
            ProgressView("Getting today's seven…")
        } else {
            ContentUnavailableView {
                Label("Nothing loaded", systemImage: "newspaper")
            } description: {
                Text(model.lastError ?? "Pull down to try again.")
            } actions: {
                Button("Try again") { Task { await model.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func editionList(_ edition: Edition) -> some View {
        List {
            Section {
                ForEach(Array(model.seven.enumerated()), id: \.element.id) { index, story in
                    NavigationLink(value: story) {
                        StoryRow(number: index + 1, story: story, showTopic: false)
                    }
                }
            } header: {
                EditionHeader(edition: edition, source: model.loadSource, error: model.lastError)
                    .textCase(nil)
            }

            ForEach(model.topicSections) { section in
                Section {
                    ForEach(section.stories) { story in
                        NavigationLink(value: story) {
                            StoryRow(number: nil, story: story, showTopic: false)
                        }
                    }
                } header: {
                    Label(section.topic.title, systemImage: section.topic.symbol)
                        .textCase(nil)
                }
            }

            Section {
                DoneView(nextEditionAt: edition.nextEditionAt)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 40, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await model.refresh()
        }
    }
}

private struct EditionHeader: View {
    let edition: Edition
    let source: LoadSource
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let day = edition.day {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 6) {
                Text("\(edition.stories.count) stories, then you're done.")
                switch source {
                case .network:
                    EmptyView()
                case .cache:
                    Text("·")
                    Text("Saved copy")
                case .bundled:
                    Text("·")
                    Text("Sample edition")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let error, source != .network {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 6)
    }
}

struct StoryRow: View {
    let number: Int?
    let story: Story
    let showTopic: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let number {
                Text("\(number)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 18, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(story.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(story.oneLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if showTopic, story.topic != .general {
                    TopicTag(topic: story.topic)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        if let number {
            return Text("Story \(number). \(story.headline). \(story.oneLine)")
        }
        return Text("\(story.topic.title). \(story.headline). \(story.oneLine)")
    }
}

/// The product thesis in one screen. It should feel good to reach.
struct DoneView: View {
    let nextEditionAt: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                .opacity(shown || reduceMotion ? 1 : 0)
                .accessibilityHidden(true)
            Text("That's it. You're caught up.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(nextLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.respectful(reduceMotion, .spring(duration: 0.5, bounce: 0.35))) {
                shown = true
            }
        }
    }

    private var nextLine: String {
        let time = nextEditionAt.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInTomorrow(nextEditionAt) {
            return String(localized: "Next edition tomorrow at \(time).")
        }
        if Calendar.current.isDateInToday(nextEditionAt), nextEditionAt > Date() {
            return String(localized: "Next edition today at \(time).")
        }
        return String(localized: "Next edition at \(time).")
    }
}

#Preview {
    TodayView()
        .environment(AppModel(preferences: Preferences(defaults: UserDefaults(suiteName: "preview")!)))
}
