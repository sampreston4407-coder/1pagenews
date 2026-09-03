"""The content model. This is the whole vocabulary of the product.

Every constraint from the brief that can be checked structurally lives here as a
pydantic validator. Voice rules live in app.voice and run separately, because a
story can be well-formed and still sound like a machine wrote it.
"""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, Field, HttpUrl, field_validator, model_validator


class Lean(str, Enum):
    left = "left"
    center = "center"
    right = "right"


class Topic(str, Enum):
    general = "general"
    ai = "ai"
    finance = "finance"
    environment = "environment"
    sports = "sports"
    health = "health"
    science = "science"
    local = "local"


OPTIONAL_TOPICS = [t for t in Topic if t is not Topic.general]

STORIES_PER_EDITION = 7
MAX_STORIES_PER_TOPIC = 2


def _word_count(text: str) -> int:
    return len(text.split())


class Source(BaseModel):
    outlet: str = Field(min_length=1)
    url: HttpUrl
    lean: Lean
    # Which parts of the story this source backs. Keys: "what_happened",
    # "not_in_dispute.<i>", "disputed.<i>", "why_it_matters".
    covers: list[str] = Field(default_factory=list)


class Dispute(BaseModel):
    claim: str = Field(min_length=1)
    side_a_position: str = Field(min_length=1)
    side_a_who: str = Field(min_length=1)
    side_b_position: str = Field(min_length=1)
    side_b_who: str = Field(min_length=1)

    @field_validator("side_a_position", "side_b_position")
    @classmethod
    def _position_budget(cls, value: str) -> str:
        if _word_count(value) > 25:
            raise ValueError(f"position over 25 words: {value!r}")
        return value


class Framing(BaseModel):
    outlet: str = Field(min_length=1)
    lean: Lean
    how_they_put_it: str = Field(min_length=1)

    @field_validator("how_they_put_it")
    @classmethod
    def _budget(cls, value: str) -> str:
        if _word_count(value) > 20:
            raise ValueError(f"framing over 20 words: {value!r}")
        return value


class Story(BaseModel):
    id: str = Field(min_length=1)
    headline: str = Field(min_length=1)
    what_happened: str = Field(min_length=1)
    not_in_dispute: list[str] = Field(min_length=3, max_length=5)
    disputed: list[Dispute] = Field(default_factory=list)
    framing: list[Framing] = Field(default_factory=list)
    why_it_matters: str = Field(min_length=1)
    sources: list[Source] = Field(min_length=1)
    updated_at: datetime
    topic: Topic

    @field_validator("headline")
    @classmethod
    def _headline(cls, value: str) -> str:
        if _word_count(value) > 8:
            raise ValueError(f"headline over 8 words: {value!r}")
        if ":" in value or "?" in value:
            raise ValueError(f"headline has a colon or question mark: {value!r}")
        return value

    @field_validator("what_happened")
    @classmethod
    def _what_happened(cls, value: str) -> str:
        if _word_count(value) > 45:
            raise ValueError(f"what_happened over 45 words ({_word_count(value)})")
        return value

    @field_validator("not_in_dispute")
    @classmethod
    def _not_in_dispute(cls, items: list[str]) -> list[str]:
        for item in items:
            if _word_count(item) > 15:
                raise ValueError(f"not_in_dispute item over 15 words: {item!r}")
        return items

    @field_validator("why_it_matters")
    @classmethod
    def _why(cls, value: str) -> str:
        if _word_count(value) > 20:
            raise ValueError(f"why_it_matters over 20 words: {value!r}")
        return value

    @model_validator(mode="after")
    def _traceable(self) -> "Story":
        """Every factual item maps to at least one source."""
        covered = {key for source in self.sources for key in source.covers}
        required = ["what_happened", "why_it_matters"]
        required += [f"not_in_dispute.{i}" for i in range(len(self.not_in_dispute))]
        required += [f"disputed.{i}" for i in range(len(self.disputed))]
        missing = [key for key in required if key not in covered]
        if missing:
            raise ValueError(f"no source covers: {', '.join(missing)}")
        return self


class Edition(BaseModel):
    """One day. Seven general stories, plus a short list per optional topic that
    the app appends when the reader has that topic on. Topics add, they never
    subtract from the seven."""

    date: date
    published_at: datetime
    next_edition_at: datetime
    stories: list[Story] = Field(min_length=STORIES_PER_EDITION, max_length=STORIES_PER_EDITION)
    topic_stories: dict[Topic, list[Story]] = Field(default_factory=dict)

    @model_validator(mode="after")
    def _topics(self) -> "Edition":
        for story in self.stories:
            if story.topic is not Topic.general:
                raise ValueError(f"main story {story.id} is not general")
        for topic, stories in self.topic_stories.items():
            if topic is Topic.general:
                raise ValueError("general does not belong in topic_stories")
            if len(stories) > MAX_STORIES_PER_TOPIC:
                raise ValueError(f"{topic.value} has more than {MAX_STORIES_PER_TOPIC} stories")
            for story in stories:
                if story.topic is not topic:
                    raise ValueError(f"story {story.id} filed under {topic.value} but tagged {story.topic.value}")
        return self

    def for_topics(self, topics: set[Topic]) -> "Edition":
        keep = {t: s for t, s in self.topic_stories.items() if t in topics}
        return self.model_copy(update={"topic_stories": keep})


class Correction(BaseModel):
    story_id: str
    edition_date: date
    corrected_at: datetime
    what_we_said: str
    what_was_true: str
    how_we_found_out: str


class SourceInfo(BaseModel):
    """An outlet we pull from, as shown on the Settings source list."""

    outlet: str
    lean: Lean
    homepage: HttpUrl
    why: str
