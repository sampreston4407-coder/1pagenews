import SwiftUI
import WidgetKit

struct HeadlinesEntry: TimelineEntry {
    let date: Date
    let edition: Edition?
}

/// Reads the edition the app last cached. Refreshes when the next edition is
/// due, never more often than every 15 minutes.
struct HeadlinesProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeadlinesEntry {
        HeadlinesEntry(date: .now, edition: EditionCache.bundled())
    }

    func getSnapshot(in context: Context, completion: @escaping (HeadlinesEntry) -> Void) {
        completion(HeadlinesEntry(date: .now, edition: EditionCache.loadOrBundled()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeadlinesEntry>) -> Void) {
        let edition = EditionCache.loadOrBundled()
        let due = edition?.nextEditionAt ?? Date().addingTimeInterval(3600)
        let refresh = max(due, Date().addingTimeInterval(15 * 60))
        completion(Timeline(entries: [HeadlinesEntry(date: .now, edition: edition)], policy: .after(refresh)))
    }
}

struct HeadlinesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HeadlinesEntry

    private var stories: [Story] { entry.edition?.stories ?? [] }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(stories.first?.headline ?? "1Page")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("1Page")
                    .font(.caption2.weight(.bold))
                    .widgetAccentable()
                Text(stories.first?.headline ?? "Open the app for today's seven.")
                    .font(.caption)
                    .lineLimit(2)
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(stories.first?.headline ?? "Open the app for today's seven.")
                    .font(.headline)
                    .lineLimit(4)
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                header
                ForEach(Array(stories.prefix(family == .systemLarge ? 7 : 3).enumerated()), id: \.element.id) { index, story in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.tint)
                        Text(story.headline)
                            .font(family == .systemLarge ? .subheadline : .caption)
                            .lineLimit(family == .systemLarge ? 2 : 1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Today's seven")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let day = entry.edition?.day {
                Text(day.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct HeadlinesWidget: Widget {
    let kind = "HeadlinesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeadlinesProvider()) { entry in
            HeadlinesWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today's seven")
        .description("The day's headlines. Tap to read.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}

@main
struct OnePageWidgetBundle: WidgetBundle {
    var body: some Widget {
        HeadlinesWidget()
    }
}
