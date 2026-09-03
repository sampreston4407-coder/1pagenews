# 1Page News

A native iOS app that puts everything you need to know today on one page.
Tap a story to see **the facts first**, then how the **left** and **right**
are framing it, with an **unbiased** view as the default.

## The idea

- **One page.** A short list of the stories that matter today. No feed, no scrolling forever.
- **Facts first.** Each story opens with a numbered list of what is confirmed across independent sources.
- **Three views.** A Left / Unbiased / Right switcher shows how each side frames the same story. Unbiased is selected by default and is the point of the app.
- **Your topics.** General news is always on. Add AI, Finance, Environment, Politics, World, Technology, Science, or Health in Settings.
- **Short by design.** Pick Quick (5), Standard (8), or Full (12) stories. There is no "long" option.

## Running it

Requires Xcode 15 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open OnePageNews.xcodeproj
```

Pick an iPhone simulator and run. The app ships with a bundled sample briefing
(`OnePageNews/Resources/SampleBriefing.json`) so every screen works with no
backend. The sample stories are fictional placeholders, not real news.

The generated `.xcodeproj` is git-ignored. Re-run `xcodegen generate` after
adding or removing files.

## Project layout

```
project.yml                      XcodeGen spec (app + unit test targets)
OnePageNews/
  App/OnePageNewsApp.swift       Entry point
  Models/                        Topic, Story, Perspectives, Source
  Services/                      NewsProvider protocol, sample + remote providers
  State/                         AppModel (screen state), Preferences (settings)
  Views/                         BriefingView, StoryDetailView, SettingsView, Styling
  Resources/                     Asset catalog, SampleBriefing.json
OnePageNewsTests/                Unit tests
```

## Data contract

The app reads one JSON shape, whether from the bundled file or a server.
`RemoteNewsProvider` calls `GET {serverURL}/briefing?topics=general,ai,finance`
and expects:

```json
{
  "generatedAt": "2026-09-03T12:00:00Z",
  "stories": [
    {
      "id": "unique-id",
      "headline": "…",
      "summary": "One or two sentences shown on the briefing page.",
      "topic": "general | world | politics | ai | technology | finance | environment | science | health",
      "importance": 3,
      "publishedAt": "2026-09-03T10:30:00Z",
      "whyItMatters": "…",
      "facts": ["…", "…"],
      "perspectives": {
        "left":     { "summary": "…", "keyPoints": ["…"] },
        "unbiased": { "summary": "…", "keyPoints": ["…"] },
        "right":    { "summary": "…", "keyPoints": ["…"] }
      },
      "sources": [
        { "name": "Outlet", "url": "https://…", "lean": "left | center | right" }
      ]
    }
  ]
}
```

`importance` is 1 (low), 2 (medium), or 3 (high). High stories get a
"Need to know" badge and sort to the top.

Set a server URL in Settings → Data source to switch from sample data to live
data. Leave it blank to use the bundled file.

## Roadmap

1. **Backend.** A service that pulls the same story from several outlets across
   the spectrum, extracts only the claims that appear in independent sources,
   and writes the three perspectives. This is where the "unbiased" promise is
   actually kept, so it needs to be verifiable: every fact should trace back to
   at least two sources with different leanings.
2. **Source ratings.** Use a published media-bias dataset rather than hand
   labels for `lean`.
3. **Notifications / widget.** A morning briefing widget and one push per day.
4. **Offline cache.** Keep the last briefing on device.
