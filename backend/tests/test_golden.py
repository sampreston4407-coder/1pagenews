"""Every story in the fixture and the golden set must pass the linter with
zero errors. Any prompt or rule change gets checked against these."""

from pathlib import Path

import pytest

from app.models import Edition, Story
from app.voice.lint import format_report, lint_story

DATA = Path(__file__).resolve().parents[1] / "app" / "data"


def all_stories() -> list[Story]:
    stories: list[Story] = []
    fixture = DATA / "fixture_edition.json"
    if fixture.exists():
        edition = Edition.model_validate_json(fixture.read_text())
        stories += edition.stories
        for group in edition.topic_stories.values():
            stories += group
    for path in sorted((DATA / "golden").glob("*.json")):
        stories.append(Story.model_validate_json(path.read_text()))
    return stories


@pytest.mark.parametrize("story", all_stories(), ids=lambda s: s.id)
def test_story_passes_voice_lint(story: Story):
    result = lint_story(story)
    assert result.ok, "\n" + format_report(story.id, result)


def test_fixture_has_seven_general_stories():
    edition = Edition.model_validate_json((DATA / "fixture_edition.json").read_text())
    assert len(edition.stories) == 7
    assert all(s.topic.value == "general" for s in edition.stories)
