"""Runtime configuration, all from environment variables."""

from __future__ import annotations

import os
from zoneinfo import ZoneInfo


def _bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./onepage.db")
SEED_FIXTURE = _bool("SEED_FIXTURE", True)
ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN", "")
EDITION_TZ = ZoneInfo(os.environ.get("EDITION_TZ", "America/New_York"))
PUBLISH_HOUR = int(os.environ.get("PUBLISH_HOUR", "7"))
WRITER_MODEL = os.environ.get("WRITER_MODEL", "claude-opus-5")
MAX_LINT_RETRIES = int(os.environ.get("MAX_LINT_RETRIES", "3"))
CORRECTIONS_URL = os.environ.get("CORRECTIONS_URL", "")
