"""Draft one story from a cluster of articles, then make it pass the linter.

The model writes text. It never writes URLs, leans, or outlet names for
sources: those come from the articles we handed it, by index. That is what
keeps every line traceable."""

from __future__ import annotations

import logging
import re
from datetime import date, datetime, timezone

from pydantic import BaseModel, ValidationError

from app import settings
from app.models import Dispute, Framing, Source, Story, Topic
from app.pipeline.ingest import Article
from app.pipeline.prompts import WRITER_SYSTEM
from app.voice.lint import LintResult, lint_story

log = logging.getLogger(__name__)


class DraftDispute(BaseModel):
    claim: str
    side_a_position: str
    side_a_who: str
    side_b_position: str
    side_b_who: str


class DraftFraming(BaseModel):
    article_index: int
    how_they_put_it: str


class DraftCoverage(BaseModel):
    article_index: int
    covers: list[str]


class DraftStory(BaseModel):
    headline: str
    what_happened: str
    not_in_dispute: list[str]
    disputed: list[DraftDispute]
    framing: list[DraftFraming]
    why_it_matters: str
    sources: list[DraftCoverage]


def slugify(text: str, limit: int = 40) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:limit].rstrip("-") or "story"


def to_story(draft: DraftStory, articles: list[Article], topic: Topic, day: date) -> Story:
    """May raise ValidationError: the model's budgets are checked here."""
    def article(i: int) -> Article | None:
        return articles[i] if 0 <= i < len(articles) else None

    sources: list[Source] = []
    for cov in draft.sources:
        a = article(cov.article_index)
        if a is None:
            continue
        sources.append(Source(outlet=a.outlet, url=a.url, lean=a.lean, covers=cov.covers))

    framing: list[Framing] = []
    for f in draft.framing:
        a = article(f.article_index)
        if a is None:
            continue
        framing.append(Framing(outlet=a.outlet, lean=a.lean, how_they_put_it=f.how_they_put_it))

    return Story(
        id=f"{day.isoformat()}-{slugify(draft.headline)}",
        headline=draft.headline,
        what_happened=draft.what_happened,
        not_in_dispute=draft.not_in_dispute,
        disputed=[Dispute(**d.model_dump()) for d in draft.disputed],
        framing=framing,
        why_it_matters=draft.why_it_matters,
        sources=sources,
        updated_at=datetime.now(timezone.utc),
        topic=topic,
    )


def _articles_block(articles: list[Article]) -> str:
    return "\n".join(a.line(i, max_summary=600) for i, a in enumerate(articles))


def draft_story(client, articles: list[Article], event: str, feedback: list[str] | None = None) -> DraftStory:
    user = f"Event: {event}\n\nArticles (use the index numbers for sources and framing):\n{_articles_block(articles)}"
    if feedback:
        user += "\n\nYour last draft failed the voice check. Fix every one of these and rewrite the whole story:\n- " + "\n- ".join(feedback)
    response = client.messages.parse(
        model=settings.WRITER_MODEL,
        max_tokens=16000,
        system=[{"type": "text", "text": WRITER_SYSTEM, "cache_control": {"type": "ephemeral"}}],
        messages=[{"role": "user", "content": user}],
        output_format=DraftStory,
    )
    return response.parsed_output


def _validation_findings(exc: ValidationError) -> list[str]:
    return [f"{'.'.join(str(p) for p in err['loc'])}: {err['msg']}" for err in exc.errors()]


def write_story(client, articles: list[Article], event: str, topic: Topic, day: date, *, store=None, max_retries: int | None = None) -> Story | None:
    """Draft, lint, retry with the findings, up to max_retries attempts. Every
    failure is logged with the offending phrases. Returns None if it never
    passes: a story that fails three times gets thrown out."""
    attempts = max_retries if max_retries is not None else settings.MAX_LINT_RETRIES
    feedback: list[str] | None = None
    for attempt in range(1, attempts + 1):
        draft = draft_story(client, articles, event, feedback)
        try:
            story = to_story(draft, articles, topic, day)
        except ValidationError as exc:
            feedback = _validation_findings(exc)
            _log_failure(store, event, attempt, feedback)
            continue
        result: LintResult = lint_story(story)
        for warning in result.warnings:
            log.info("warning %s: %s", story.id, warning)
        if result.ok:
            return story
        feedback = [str(f) for f in result.errors]
        _log_failure(store, event, attempt, feedback)
    log.warning("gave up on %r after %d attempts", event, attempts)
    return None


def _log_failure(store, event: str, attempt: int, findings: list[str]) -> None:
    log.info("lint fail attempt %d for %r: %s", attempt, event, findings)
    if store is not None:
        store.log_lint_failure(event, attempt, findings)
