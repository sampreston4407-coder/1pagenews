"""Pipeline tests with a fake Claude client. No network, no key."""

from datetime import date, datetime, timezone

import pytest

from app.models import Lean, Topic
from app.pipeline.build import BuildFailed, build_edition
from app.pipeline.ingest import Article, parse_feed
from app.pipeline.plan import ClusterPlan, EditionPlan, clusters_from_plan
from app.pipeline.sources import Feed
from app.pipeline.writer import DraftCoverage, DraftDispute, DraftFraming, DraftStory, to_story, write_story
from app.storage import Store


def article(i: int, lean: Lean = Lean.center, topics=(Topic.general,)) -> Article:
    return Article(outlet=f"Outlet {i}", lean=lean, title=f"Title {i}", summary=f"Summary {i}", url=f"https://example.org/{i}", published=datetime.now(timezone.utc), topics=topics)


ARTICLES = [article(0, Lean.left), article(1, Lean.center), article(2, Lean.right)]

GOOD = DraftStory(
    headline="Fed holds rates, third time this year",
    what_happened="The Fed left interest rates unchanged Wednesday. That's the third hold in a row. Powell said they want two more months of inflation data before moving.",
    not_in_dispute=["Rate stays at 4.25%.", "Vote was 11-1.", "Powell said a cut is still on the table for December."],
    disputed=[DraftDispute(claim="whether the Fed is waiting too long", side_a_position="WSJ editorial board says holding this long risks a hiring slowdown", side_a_who="WSJ editorial board", side_b_position="Bloomberg's economics team says cutting early would restart price growth", side_b_who="Bloomberg economics team")],
    framing=[DraftFraming(article_index=0, how_they_put_it="Fed keeps squeezing borrowers"), DraftFraming(article_index=2, how_they_put_it="Fed bows to pressure")],
    why_it_matters="Mortgage and car loan rates stay about where they are through December.",
    sources=[DraftCoverage(article_index=1, covers=["what_happened", "not_in_dispute.0", "not_in_dispute.1", "not_in_dispute.2", "disputed.0", "why_it_matters"]), DraftCoverage(article_index=0, covers=["what_happened"])],
)

BAD = GOOD.model_copy(update={"what_happened": "The Fed held rates Wednesday, underscoring caution amid inflation. Critics say it waited too long."})


class FakeResponse:
    def __init__(self, parsed):
        self.parsed_output = parsed


class FakeMessages:
    def __init__(self, outputs):
        self.outputs = list(outputs)
        self.calls = []

    def parse(self, **kwargs):
        self.calls.append(kwargs)
        out = self.outputs.pop(0)
        return FakeResponse(out() if callable(out) else out)


class FakeClient:
    def __init__(self, outputs):
        self.messages = FakeMessages(outputs)


def test_to_story_uses_article_metadata_for_sources():
    story = to_story(GOOD, ARTICLES, Topic.general, date(2026, 9, 3))
    assert story.id == "2026-09-03-fed-holds-rates-third-time-this-year"
    assert {s.outlet for s in story.sources} == {"Outlet 1", "Outlet 0"}
    assert story.framing[0].lean == Lean.left
    assert story.framing[1].lean == Lean.right


def test_write_story_retries_with_feedback_and_logs_failures():
    client = FakeClient([BAD, GOOD])
    store = Store("sqlite://")
    story = write_story(client, ARTICLES, "Fed decision", Topic.general, date(2026, 9, 3), store=store)
    assert story is not None
    assert len(client.messages.calls) == 2
    retry_prompt = client.messages.calls[1]["messages"][0]["content"]
    assert "failed the voice check" in retry_prompt
    assert "underscoring" in retry_prompt
    failures = store.recent_lint_failures()
    assert len(failures) == 1 and failures[0]["attempt"] == "1"


def test_write_story_gives_up_after_max_retries():
    client = FakeClient([BAD, BAD, BAD])
    assert write_story(client, ARTICLES, "x", Topic.general, date(2026, 9, 3), max_retries=3) is None


def test_clusters_drop_invented_indices():
    plan = EditionPlan(general=[ClusterPlan(event="a", article_indices=[0, 99]), ClusterPlan(event="b", article_indices=[42])])
    clusters = clusters_from_plan(plan, ARTICLES)
    assert len(clusters[Topic.general]) == 1
    assert clusters[Topic.general][0].articles == [ARTICLES[0]]


def test_build_edition_needs_seven_general_stories():
    plan = EditionPlan(general=[ClusterPlan(event=f"e{i}", article_indices=[0, 1, 2]) for i in range(3)])
    client = FakeClient([plan] + [GOOD] * 3)
    with pytest.raises(BuildFailed):
        build_edition(date(2026, 9, 3), client, ARTICLES)


def test_build_edition_publishes_seven_plus_topics():
    ai_articles = [article(3, topics=(Topic.ai,))]
    articles = ARTICLES + ai_articles
    plan = EditionPlan(
        general=[ClusterPlan(event=f"e{i}", article_indices=[0, 1, 2]) for i in range(9)],
        ai=[ClusterPlan(event="ai", article_indices=[3])],
    )
    ai_good = GOOD.model_copy(update={
        "headline": "New AI rules take effect",
        "framing": [DraftFraming(article_index=0, how_they_put_it="Rules land")],
        "sources": [DraftCoverage(article_index=0, covers=GOOD.sources[0].covers)],
    })
    client = FakeClient([plan] + [GOOD] * 7 + [ai_good])
    edition = build_edition(date(2026, 9, 3), client, articles)
    assert len(edition.stories) == 7
    assert list(edition.topic_stories) == [Topic.ai]
    assert len(client.messages.calls) == 1 + 7 + 1  # backups 8 and 9 never drafted


def test_parse_feed_strips_html_and_keeps_links():
    raw = b"""<?xml version="1.0"?><rss version="2.0"><channel><title>t</title>
    <item><title>Fed &amp; rates</title><link>https://example.org/a</link><description><![CDATA[<p>Held <b>steady</b></p>]]></description><pubDate>Wed, 03 Sep 2026 10:00:00 GMT</pubDate></item>
    <item><title>No link</title></item>
    </channel></rss>"""
    items = parse_feed(Feed("X", Lean.center, "https://example.org/rss"), raw)
    assert len(items) == 1
    assert items[0].title == "Fed & rates"
    assert items[0].summary == "Held steady"
    assert items[0].published is not None
