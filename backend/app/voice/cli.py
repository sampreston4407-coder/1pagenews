"""Lint a story or edition JSON file from the command line.

    python -m app.voice.cli app/data/fixture_edition.json

Exit code 1 if any story fails. Every finding is printed with the offending
phrase so the prompt can be tuned against real misses.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from app.models import Edition, Story
from app.voice.lint import format_report, lint_story


def stories_in(path: Path) -> list[Story]:
    data = json.loads(path.read_text())
    if "stories" in data:
        edition = Edition.model_validate(data)
        out = list(edition.stories)
        for stories in edition.topic_stories.values():
            out += stories
        return out
    return [Story.model_validate(data)]


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    failed = 0
    for arg in argv:
        for story in stories_in(Path(arg)):
            result = lint_story(story)
            print(format_report(story.id, result))
            if not result.ok:
                failed += 1
    print(f"\n{failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
