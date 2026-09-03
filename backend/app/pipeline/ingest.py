"""Pull the last day and a half of headlines from every feed."""

from __future__ import annotations

import html
import logging
import re
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

import feedparser
import httpx

from app.models import Lean, Topic
from app.pipeline.sources import FEEDS, Feed

log = logging.getLogger(__name__)

_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")


@dataclass
class Article:
    outlet: str
    lean: Lean
    title: str
    summary: str
    url: str
    published: datetime | None
    topics: tuple[Topic, ...] = field(default_factory=lambda: (Topic.general,))

    def line(self, index: int, max_summary: int = 220) -> str:
        summary = self.summary[:max_summary].rstrip()
        return f"[{index}] {self.outlet} ({self.lean.value}): {self.title}. {summary}"


def clean(text: str | None) -> str:
    if not text:
        return ""
    text = html.unescape(_TAG_RE.sub(" ", text))
    return _WS_RE.sub(" ", text).strip()


def parse_feed(feed: Feed, raw: bytes) -> list[Article]:
    parsed = feedparser.parse(raw)
    out: list[Article] = []
    for entry in parsed.entries:
        title = clean(entry.get("title"))
        link = entry.get("link") or ""
        if not title or not link.startswith("http"):
            continue
        published = None
        stamp = entry.get("published_parsed") or entry.get("updated_parsed")
        if stamp:
            published = datetime.fromtimestamp(time.mktime(stamp), tz=timezone.utc)
        out.append(Article(
            outlet=feed.outlet, lean=feed.lean, title=title,
            summary=clean(entry.get("summary") or entry.get("description")),
            url=link, published=published, topics=feed.topics,
        ))
    return out


def ingest(feeds: list[Feed] | None = None, since_hours: int = 36, timeout: float = 15.0) -> list[Article]:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=since_hours)
    articles: list[Article] = []
    seen: set[str] = set()
    with httpx.Client(timeout=timeout, follow_redirects=True, headers={"User-Agent": "1PageNews/0.1 (+https://github.com/sampreston4407-coder/1pagenews)"}) as client:
        for feed in feeds or FEEDS:
            try:
                response = client.get(feed.url)
                response.raise_for_status()
            except httpx.HTTPError as exc:
                log.warning("feed failed %s: %s", feed.url, exc)
                continue
            for article in parse_feed(feed, response.content):
                if article.published and article.published < cutoff:
                    continue
                if article.url in seen:
                    continue
                seen.add(article.url)
                articles.append(article)
    log.info("ingested %d articles from %d feeds", len(articles), len(feeds or FEEDS))
    return articles
