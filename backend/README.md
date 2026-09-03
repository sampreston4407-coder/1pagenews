# 1Page News backend

Two jobs. Serve today's edition to the app, and build tomorrow's.

## Run locally

```sh
cd backend
python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"
.venv/bin/uvicorn app.main:app --reload
```

On first start with an empty database the fixture edition is seeded, so
`GET http://127.0.0.1:8000/v1/edition/today` works right away.

Tests: `.venv/bin/pytest`. Lint any story or edition file:
`.venv/bin/python -m app.voice.cli app/data/fixture_edition.json`.

## Endpoints

| Method | Path | What |
|---|---|---|
| GET | `/v1/edition/today?topics=ai,finance` | Latest edition. Seven general stories plus up to two per requested topic. |
| GET | `/v1/edition/2026-09-03?topics=...` | A specific day. |
| GET | `/v1/editions` | Dates we have. |
| GET | `/v1/methodology` | The methodology page, as sections. |
| GET | `/v1/sources` | Outlets we pull from, with lean and why. |
| GET | `/v1/corrections` | Public corrections log. |
| POST | `/v1/admin/build` | Build an edition now. Needs `x-admin-token`. |
| POST | `/v1/admin/corrections` | Add a correction. Needs `x-admin-token`. |
| GET | `/v1/admin/lint-failures` | Recent linter rejections, for prompt tuning. |

## Pipeline

`python -m app.pipeline.build` runs once a day:

1. **Ingest.** RSS from the feeds in `app/pipeline/sources.py`. Headline,
   summary, link. We never fetch or store article bodies.
2. **Plan.** One Claude call ranks the day's events and maps articles to them.
   Nine general candidates, up to two per optional topic.
3. **Write.** One Claude call per event drafts the story as structured output.
   Sources come from the article indices we handed it, never from the model.
4. **Lint.** `app/voice/lint.py` runs every rule from the brief. A failing draft
   goes back with the findings, up to three attempts, then it is thrown out.
   Every failure is logged in `lint_failures` with the offending phrase.
5. **Publish.** Seven general stories or nothing. Stored as one row per day.

## Environment

| Variable | Default | Notes |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./onepage.db` | Railway Postgres URL works as is. |
| `ANTHROPIC_API_KEY` | | Needed by the pipeline only. |
| `ADMIN_TOKEN` | empty | Empty disables every admin route. |
| `SEED_FIXTURE` | `true` | Seed the fixture edition into an empty database. |
| `EDITION_TZ` | `America/New_York` | What "today" means. |
| `PUBLISH_HOUR` | `7` | Local hour the next edition is promised for. |
| `WRITER_MODEL` | `claude-opus-5` | |
| `MAX_LINT_RETRIES` | `3` | |

## Railway layout

Two services from this directory, both with root directory `backend`:

- **api**: the Dockerfile default command. Public domain, healthcheck `/healthz`.
- **builder**: same image, start command `python -m app.pipeline.build`,
  cron schedule `0 11 * * *` (07:00 New York in summer). Needs
  `ANTHROPIC_API_KEY`.

Both share one Postgres service through `DATABASE_URL`.

## Sourcing

Read section 8 of the brief before touching `sources.py`. RSS feeds are
published for syndication with a link back, which is all we do. Check each
outlet's terms before adding it. The lean labels are hand-set from AllSides
and should move to a maintained dataset.
