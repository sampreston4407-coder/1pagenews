"""Editions, corrections, and lint failures. Postgres on Railway via
DATABASE_URL, SQLite locally. Editions are stored whole as JSON because the
unit of publication is the day, not the story."""

from __future__ import annotations

import json
from datetime import date, datetime, timezone
from pathlib import Path

from sqlalchemy import Column, Date, DateTime, MetaData, String, Table, Text, create_engine, select
from sqlalchemy.engine import Engine
from sqlalchemy.pool import StaticPool

from app import settings
from app.models import Correction, Edition

metadata = MetaData()

editions = Table(
    "editions", metadata,
    Column("date", Date, primary_key=True),
    Column("body", Text, nullable=False),
    Column("published_at", DateTime(timezone=True), nullable=False),
)

corrections = Table(
    "corrections", metadata,
    Column("id", String(64), primary_key=True),
    Column("story_id", String(128), nullable=False),
    Column("edition_date", Date, nullable=False),
    Column("corrected_at", DateTime(timezone=True), nullable=False),
    Column("what_we_said", Text, nullable=False),
    Column("what_was_true", Text, nullable=False),
    Column("how_we_found_out", Text, nullable=False),
)

lint_failures = Table(
    "lint_failures", metadata,
    Column("id", String(64), primary_key=True),
    Column("logged_at", DateTime(timezone=True), nullable=False),
    Column("story_hint", String(256), nullable=False),
    Column("attempt", String(8), nullable=False),
    Column("findings", Text, nullable=False),
)


def _normalize(url: str) -> str:
    # Railway hands out postgres://, SQLAlchemy 2 wants postgresql+psycopg://
    if url.startswith("postgres://"):
        return "postgresql+psycopg://" + url[len("postgres://"):]
    if url.startswith("postgresql://"):
        return "postgresql+psycopg://" + url[len("postgresql://"):]
    return url


class Store:
    def __init__(self, url: str | None = None):
        target = _normalize(url or settings.DATABASE_URL)
        if target.startswith("sqlite"):
            # One shared connection: FastAPI serves from a thread pool, and an
            # in-memory database would otherwise vanish between requests.
            self.engine: Engine = create_engine(
                target, future=True, poolclass=StaticPool, connect_args={"check_same_thread": False},
            )
        else:
            self.engine = create_engine(target, future=True, pool_pre_ping=True)
        metadata.create_all(self.engine)

    # Editions

    def put_edition(self, edition: Edition) -> None:
        with self.engine.begin() as conn:
            conn.execute(editions.delete().where(editions.c.date == edition.date))
            conn.execute(editions.insert().values(
                date=edition.date, body=edition.model_dump_json(), published_at=edition.published_at,
            ))

    def get_edition(self, day: date) -> Edition | None:
        with self.engine.connect() as conn:
            row = conn.execute(select(editions.c.body).where(editions.c.date == day)).first()
        return Edition.model_validate_json(row[0]) if row else None

    def latest_edition(self, on_or_before: date) -> Edition | None:
        with self.engine.connect() as conn:
            row = conn.execute(
                select(editions.c.body).where(editions.c.date <= on_or_before).order_by(editions.c.date.desc()).limit(1)
            ).first()
        return Edition.model_validate_json(row[0]) if row else None

    def edition_dates(self) -> list[date]:
        with self.engine.connect() as conn:
            return [r[0] for r in conn.execute(select(editions.c.date).order_by(editions.c.date.desc()))]

    def is_empty(self) -> bool:
        return not self.edition_dates()

    # Corrections

    def add_correction(self, c: Correction) -> None:
        with self.engine.begin() as conn:
            conn.execute(corrections.insert().values(
                id=f"{c.story_id}:{int(c.corrected_at.timestamp())}",
                story_id=c.story_id, edition_date=c.edition_date, corrected_at=c.corrected_at,
                what_we_said=c.what_we_said, what_was_true=c.what_was_true, how_we_found_out=c.how_we_found_out,
            ))

    def list_corrections(self) -> list[Correction]:
        with self.engine.connect() as conn:
            rows = conn.execute(select(corrections).order_by(corrections.c.corrected_at.desc())).mappings().all()
        return [Correction(**{k: v for k, v in row.items() if k != "id"}) for row in rows]

    # Lint failures, so the prompt can be tuned against real misses.

    def log_lint_failure(self, story_hint: str, attempt: int, findings: list[str]) -> None:
        now = datetime.now(timezone.utc)
        with self.engine.begin() as conn:
            conn.execute(lint_failures.insert().values(
                id=f"{int(now.timestamp() * 1000)}:{abs(hash(story_hint)) % 100000}",
                logged_at=now, story_hint=story_hint[:256], attempt=str(attempt), findings=json.dumps(findings),
            ))

    def recent_lint_failures(self, limit: int = 50) -> list[dict]:
        with self.engine.connect() as conn:
            rows = conn.execute(select(lint_failures).order_by(lint_failures.c.logged_at.desc()).limit(limit)).mappings().all()
        return [dict(r) | {"findings": json.loads(r["findings"])} for r in rows]


FIXTURE_PATH = Path(__file__).resolve().parent / "data" / "fixture_edition.json"


def load_fixture() -> Edition:
    return Edition.model_validate_json(FIXTURE_PATH.read_text())
