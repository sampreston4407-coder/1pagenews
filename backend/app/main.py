"""The API the iOS app talks to. Small on purpose."""

from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import date, datetime

from fastapi import BackgroundTasks, Depends, FastAPI, Header, HTTPException, Query
from pydantic import BaseModel

from app import content, settings
from app.models import Correction, Edition, SourceInfo, Topic
from app.storage import Store, load_fixture

_store: Store | None = None


def get_store() -> Store:
    global _store
    if _store is None:
        _store = Store()
    return _store


@asynccontextmanager
async def lifespan(app: FastAPI):
    store = get_store()
    if settings.SEED_FIXTURE and store.is_empty():
        store.put_edition(load_fixture())
    yield


app = FastAPI(title="1Page News API", version="0.1.0", lifespan=lifespan)


def parse_topics(raw: str | None) -> set[Topic]:
    topics = {Topic.general}
    if raw:
        for part in raw.split(","):
            part = part.strip().lower()
            if not part:
                continue
            try:
                topics.add(Topic(part))
            except ValueError:
                raise HTTPException(400, f"unknown topic: {part}")
    return topics


def local_today() -> date:
    return datetime.now(settings.EDITION_TZ).date()


@app.get("/healthz")
def healthz() -> dict:
    return {"ok": True}


@app.get("/v1/edition/today", response_model=Edition)
def edition_today(topics: str | None = Query(None), store: Store = Depends(get_store)) -> Edition:
    edition = store.latest_edition(local_today())
    if edition is None:
        raise HTTPException(404, "no edition yet")
    return edition.for_topics(parse_topics(topics))


@app.get("/v1/edition/{day}", response_model=Edition)
def edition_for(day: date, topics: str | None = Query(None), store: Store = Depends(get_store)) -> Edition:
    edition = store.get_edition(day)
    if edition is None:
        raise HTTPException(404, f"no edition for {day.isoformat()}")
    return edition.for_topics(parse_topics(topics))


@app.get("/v1/editions")
def editions(store: Store = Depends(get_store)) -> dict:
    return {"dates": [d.isoformat() for d in store.edition_dates()]}


@app.get("/v1/methodology")
def methodology() -> dict:
    return content.METHODOLOGY


@app.get("/v1/sources", response_model=list[SourceInfo])
def sources() -> list[SourceInfo]:
    return content.SOURCES


@app.get("/v1/corrections", response_model=list[Correction])
def corrections(store: Store = Depends(get_store)) -> list[Correction]:
    return store.list_corrections()


# Admin. Protected by a shared token; there is no user auth in this product.

def require_admin(x_admin_token: str = Header(default="")) -> None:
    if not settings.ADMIN_TOKEN or x_admin_token != settings.ADMIN_TOKEN:
        raise HTTPException(401, "admin token required")


class BuildRequest(BaseModel):
    day: date | None = None
    dry_run: bool = False


@app.post("/v1/admin/build", dependencies=[Depends(require_admin)])
def admin_build(req: BuildRequest, tasks: BackgroundTasks) -> dict:
    from app.pipeline.build import build_and_publish

    tasks.add_task(build_and_publish, req.day or local_today(), req.dry_run)
    return {"queued": True, "day": (req.day or local_today()).isoformat()}


@app.post("/v1/admin/corrections", dependencies=[Depends(require_admin)])
def admin_add_correction(c: Correction, store: Store = Depends(get_store)) -> dict:
    store.add_correction(c)
    return {"ok": True}


@app.get("/v1/admin/lint-failures", dependencies=[Depends(require_admin)])
def admin_lint_failures(store: Store = Depends(get_store)) -> list[dict]:
    return store.recent_lint_failures()
