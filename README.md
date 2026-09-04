# 1Page News

Seven stories a day, written plainly, with the disputed parts clearly marked,
and an ending.

Native iOS app plus the backend that builds each day's edition. The brief in
the project history is the source of truth. The writing is the product.

## What's here

```
project.yml           XcodeGen spec: app, widget extension, unit tests
OnePageNews/          The app (SwiftUI, iOS 17+)
  App/                Entry point, text size floor
  Views/              Today, story detail with the spine, settings, methodology
  Intents/            Siri read-aloud intent, Focus filter
  Resources/          Fixture edition, methodology, sources, string catalog
OnePageWidget/        Home and Lock Screen widgets
Shared/               Content model and app-group cache, used by app and widget
OnePageNewsTests/     Unit tests
backend/              FastAPI service and the daily edition pipeline (see backend/README.md)
```

## Run the app

Requires Xcode 15 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open OnePageNews.xcodeproj
```

Pick an iPhone simulator and run. The app loads today's edition from the
Railway API and falls back to a saved copy, then to the bundled fixture, so
every screen works offline. Change the server in Settings.

App Groups: the app and widget share `group.com.sampreston.onepagenews`.
Xcode will ask you to register it against your team the first time.

## The one screen that matters

Story detail, top to bottom:

1. What happened. Two or three sentences.
2. Not in dispute. Only what every outlet reports the same way.
3. Disputed. The claim, then a stem that forks to the far left and far right. A dashed strand runs down each edge beside that side's position, and ends there.
4. How each outlet put it. Collapsed.
5. Why it matters. One sentence.
6. Sources. Always visible, every one a link to the original.

Then the Today page ends. Seven stories, a done screen, no eighth.

## Backend

Deployed on Railway from the `backend/` directory of this branch:

- **api** serves editions at `https://api-production-50ff.up.railway.app`
- **builder** runs `python -m app.pipeline.build` on a daily cron
- **Postgres** stores editions, corrections, and linter rejections

The builder needs `ANTHROPIC_API_KEY` set on the Railway service before it
can write a real edition. Until then the API serves the fixture.

The voice linter (`backend/app/voice/`) runs on every generated story. A story
that fails three times is thrown out. See `backend/README.md`.

## Non-goals

No feed. No comments. No sharing streaks. No ads. No chatbot. One
notification a day, at a time the reader picks.
