"""Turn a pile of headlines into the day's plan: which events run, and which
articles back each one."""

from __future__ import annotations

from dataclasses import dataclass

from pydantic import BaseModel, Field

from app import settings
from app.models import Topic
from app.pipeline.ingest import Article
from app.pipeline.prompts import PLANNER_SYSTEM


class ClusterPlan(BaseModel):
    event: str = Field(description="One line naming the event")
    article_indices: list[int]


class EditionPlan(BaseModel):
    general: list[ClusterPlan]
    ai: list[ClusterPlan] = Field(default_factory=list)
    finance: list[ClusterPlan] = Field(default_factory=list)
    environment: list[ClusterPlan] = Field(default_factory=list)
    sports: list[ClusterPlan] = Field(default_factory=list)
    health: list[ClusterPlan] = Field(default_factory=list)
    science: list[ClusterPlan] = Field(default_factory=list)
    local: list[ClusterPlan] = Field(default_factory=list)

    def for_topic(self, topic: Topic) -> list[ClusterPlan]:
        return getattr(self, topic.value)


@dataclass
class Cluster:
    topic: Topic
    event: str
    articles: list[Article]


def listing(articles: list[Article]) -> str:
    lines = []
    for i, a in enumerate(articles):
        tags = ",".join(t.value for t in a.topics)
        lines.append(f"{a.line(i)} [topics: {tags}]")
    return "\n".join(lines)


def plan_edition(client, articles: list[Article]) -> EditionPlan:
    response = client.messages.parse(
        model=settings.WRITER_MODEL,
        max_tokens=16000,
        system=[{"type": "text", "text": PLANNER_SYSTEM, "cache_control": {"type": "ephemeral"}}],
        messages=[{"role": "user", "content": f"Today's headlines:\n\n{listing(articles)}"}],
        output_format=EditionPlan,
    )
    return response.parsed_output


def clusters_from_plan(plan: EditionPlan, articles: list[Article]) -> dict[Topic, list[Cluster]]:
    """Resolve indices to articles, dropping anything the model made up."""
    out: dict[Topic, list[Cluster]] = {}
    for topic in Topic:
        clusters = []
        for cp in plan.for_topic(topic):
            picked = [articles[i] for i in cp.article_indices if 0 <= i < len(articles)]
            if picked:
                clusters.append(Cluster(topic=topic, event=cp.event, articles=picked))
        out[topic] = clusters
    return out
