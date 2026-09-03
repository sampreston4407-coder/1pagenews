"""Copy the fixture edition, methodology, and source list into the iOS app
bundle so every screen works offline and in previews.

    .venv/bin/python scripts/export_ios_fixtures.py
"""

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))

from app import content  # noqa: E402
from app.storage import FIXTURE_PATH  # noqa: E402

OUT = ROOT / "OnePageNews" / "Resources"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copy(FIXTURE_PATH, OUT / "FixtureEdition.json")
    (OUT / "Methodology.json").write_text(json.dumps(content.METHODOLOGY, indent=2) + "\n")
    (OUT / "Sources.json").write_text(json.dumps([s.model_dump(mode="json") for s in content.SOURCES], indent=2) + "\n")
    print(f"exported to {OUT}")


if __name__ == "__main__":
    main()
