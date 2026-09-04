"""Feeds we pull from. RSS only: headline, summary, link. We never fetch or
store article bodies. Lean labels follow AllSides ratings at the time of
writing and should move to a maintained dataset (roadmap).

Check each outlet's terms before adding it here. RSS is published for
syndication with a link back, which is exactly what we do with it."""

from __future__ import annotations

from dataclasses import dataclass

from app.models import Lean, Topic


@dataclass(frozen=True)
class Feed:
    outlet: str
    lean: Lean
    url: str
    topics: tuple[Topic, ...] = (Topic.general,)


FEEDS: list[Feed] = [
    # General news, across the spectrum
    Feed("BBC News", Lean.center, "https://feeds.bbci.co.uk/news/world/rss.xml"),
    Feed("BBC News", Lean.center, "https://feeds.bbci.co.uk/news/world/us_and_canada/rss.xml"),
    Feed("The Hill", Lean.center, "https://thehill.com/feed/"),
    Feed("CBS News", Lean.center, "https://www.cbsnews.com/latest/rss/main"),
    Feed("NPR", Lean.left, "https://feeds.npr.org/1001/rss.xml"),
    Feed("The Guardian", Lean.left, "https://www.theguardian.com/us-news/rss"),
    Feed("Fox News", Lean.right, "https://moxie.foxnews.com/google-publisher/latest.xml"),
    Feed("Washington Examiner", Lean.right, "https://www.washingtonexaminer.com/feed"),
    Feed("New York Post", Lean.right, "https://nypost.com/feed/"),
    # Topic feeds
    Feed("MIT Technology Review", Lean.center, "https://www.technologyreview.com/feed/", (Topic.ai,)),
    Feed("Ars Technica", Lean.center, "https://feeds.arstechnica.com/arstechnica/technology-lab", (Topic.ai,)),
    Feed("CNBC", Lean.center, "https://www.cnbc.com/id/100003114/device/rss/rss.html", (Topic.finance,)),
    Feed("NPR", Lean.left, "https://feeds.npr.org/1017/rss.xml", (Topic.finance,)),
    Feed("The Guardian", Lean.left, "https://www.theguardian.com/environment/rss", (Topic.environment,)),
    Feed("ESPN", Lean.center, "https://www.espn.com/espn/rss/news", (Topic.sports,)),
    Feed("NPR", Lean.left, "https://feeds.npr.org/1128/rss.xml", (Topic.health,)),
    Feed("NPR", Lean.left, "https://feeds.npr.org/1007/rss.xml", (Topic.science,)),
    Feed("ScienceDaily", Lean.center, "https://www.sciencedaily.com/rss/all.xml", (Topic.science,)),
    # Local needs the reader's city. Add a feed per city before enabling the topic.
]
