"""Build and publish one edition. Runs once a day from a Railway cron service,
or on demand through POST /v1/admin/build.

    python -m app.pipeline.build            # today
    python -m app.pipeline.build --dry-run  # build, lint, print, don't store
"""

from __future__ import annotations

import argparse
import logging
import sys
from datetime import date, datetime, time, timedelta, timezone

from app import settings
from app.models import MAX_STORIES_PER_TOPIC, OPTIONAL_TOPICS, STORIES_PER_EDITION, Edition, Story, Topic
from app.pipeline.ingest import Article, ingest
from app.pipeline.plan import Cluster, clusters_from_plan, plan_edition
from app.pipeline.writer import write_story

log = logging.getLogger(__name__)


class BuildFailed(RuntimeError):
    pass


def next_edition_time(day: date) -> datetime:
    local = datetime.combine(day + timedelta(days=1), time(hour=settings.PUBLISH_HOUR), tzinfo=settings.EDITION_TZ)
    return local.astimezone(timezone.utc)


def build_edition(day: date, client, articles: list[Article], *, store=None) -> Edition:
    if not articles:
        raise BuildFailed("no articles ingested")
    plan = plan_edition(client, articles)
    clusters = clusters_from_plan(plan, articles)

    general: list[Story] = []
    for cluster in clusters[Topic.general]:
        if len(general) == STORIES_PER_EDITION:
            break
        story = write_story(client, cluster.articles, cluster.event, Topic.general, day, store=store)
        if story:
            general.append(story)
    if len(general) < STORIES_PER_EDITION:
        raise BuildFailed(f"only {len(general)} of {STORIES_PER_EDITION} general stories passed")

    topic_stories: dict[Topic, list[Story]] = {}
    for topic in OPTIONAL_TOPICS:
        passed: list[Story] = []
        for cluster in clusters[topic]:
            if len(passed) == MAX_STORIES_PER_TOPIC:
                break
            story = write_story(client, cluster.articles, cluster.event, topic, day, store=store)
            if story:
                passed.append(story)
        if passed:
            topic_stories[topic] = passed

    return Edition(
        date=day,
        published_at=datetime.now(timezone.utc),
        next_edition_at=next_edition_time(day),
        stories=general,
        topic_stories=topic_stories,
    )


def build_and_publish(day: date, dry_run: bool = False) -> Edition | None:
    import anthropic

    from app.storage import Store

    store = Store()
    client = anthropic.Anthropic()
    try:
        edition = build_edition(day, client, ingest(), store=store)
    except BuildFailed as exc:
        log.error("build failed for %s: %s", day, exc)
        return None
    if dry_run:
        print(edition.model_dump_json(indent=2))
    else:
        store.put_edition(edition)
        log.info("published %s with %d stories", day, len(edition.stories))
    return edition


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", type=date.fromisoformat, default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    day = args.date or datetime.now(settings.EDITION_TZ).date()
    return 0 if build_and_publish(day, args.dry_run) else 1


if __name__ == "__main__":
    sys.exit(main())
