import AppIntents
import Foundation

/// "Read my 1Page brief." Siri and Shortcuts read the seven out loud from the
/// cached edition, no network needed.
struct ReadBriefIntent: AppIntent {
    static var title: LocalizedStringResource = "Read today's seven"
    static var description = IntentDescription("Reads today's seven headlines out loud.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let edition = EditionCache.loadOrBundled(), !edition.stories.isEmpty else {
            return .result(dialog: "Nothing loaded yet. Open 1Page first.")
        }
        let lines = edition.stories.enumerated().map { index, story in
            "\(index + 1). \(story.headline). \(story.oneLine)"
        }
        let text = lines.joined(separator: " ") + " That's it. You're caught up."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct OnePageShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadBriefIntent(),
            phrases: [
                "Read my \(.applicationName) brief",
                "What's in \(.applicationName) today",
                "Read today's seven in \(.applicationName)",
            ],
            shortTitle: "Read today's seven",
            systemImageName: "newspaper"
        )
    }
}

/// Focus filter. The only thing it controls is whether the one daily
/// notification arrives during that Focus.
struct DailyNotificationFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "1Page notification"
    static var description: IntentDescription? = "Choose whether the daily notification arrives during this Focus."

    @Parameter(title: "Daily notification", default: true)
    var allowNotification: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: allowNotification ? "Notification on" : "Notification off")
    }

    func perform() async throws -> some IntentResult {
        FocusMute.isMuted = !allowNotification
        DailyNotification.apply(Preferences(), muted: FocusMute.isMuted)
        return .result()
    }
}

enum FocusMute {
    private static let key = "focusMuted"

    static var isMuted: Bool {
        get { SharedDefaults.suite.bool(forKey: key) }
        set { SharedDefaults.suite.set(newValue, forKey: key) }
    }
}
