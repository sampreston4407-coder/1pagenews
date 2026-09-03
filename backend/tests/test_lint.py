from datetime import datetime, timezone

import pytest

from app.models import Dispute, Framing, Lean, Source, Story, Topic
from app.voice import lint_story, lint_text


def make_story(**overrides) -> Story:
    base = dict(
        id="t-1",
        headline="Fed holds rates, third time this year",
        what_happened="The Fed left interest rates unchanged Wednesday. That's the third hold in a row. Powell said they want two more months of inflation data before moving.",
        not_in_dispute=["Rate stays at 4.25%.", "Vote was 11-1.", "Powell said a cut is still on the table for December."],
        disputed=[Dispute(
            claim="whether the Fed is waiting too long",
            side_a_position="WSJ editorial board says holding this long risks a hiring slowdown",
            side_a_who="WSJ editorial board",
            side_b_position="Bloomberg's economics team says cutting early would restart price growth",
            side_b_who="Bloomberg economics team",
        )],
        framing=[Framing(outlet="Sample Wire", lean=Lean.center, how_they_put_it="Fed stays put, again")],
        why_it_matters="Mortgage and car loan rates stay about where they are through December.",
        sources=[Source(outlet="Sample Wire", url="https://example.org/a", lean=Lean.center,
                        covers=["what_happened", "not_in_dispute.0", "not_in_dispute.1", "not_in_dispute.2", "disputed.0", "why_it_matters"])],
        updated_at=datetime(2026, 9, 3, tzinfo=timezone.utc),
        topic=Topic.general,
    )
    base.update(overrides)
    return Story(**base)


def rules_of(findings):
    return {f.rule for f in findings}


def test_clean_story_passes():
    result = lint_story(make_story())
    assert result.ok, [str(f) for f in result.findings]


@pytest.mark.parametrize("text,rule", [
    ("The bill underscores a shift.", "banned_word"),
    ("Prices fell amid concerns.", "banned_word"),
    ("Companies in the AI space are hiring.", "banned_word"),
    ("It's worth noting the vote was close.", "banned_phrase"),
    ("The deal is dead — for now.", "dash"),
    ("The deal is dead; talks ended.", "semicolon"),
    ("One thing is clear: the deal is dead.", "setup_colon_payoff"),
    ("The bill (a long one) passed.", "parenthetical"),
    ("The bill passed 54-46, marking the first bipartisan vote.", "trailing_participle"),
    ("Critics say the plan is too slow.", "vague_attribution"),
    ("This may potentially suggest a slowdown.", "hedge_stack"),
    ("It is not just a bill, but a message.", "not_just_but"),
])
def test_text_rules(text, rule):
    assert rule in rules_of(lint_text(text, "what_happened")), text


def test_allowed_ing_words_pass():
    findings = lint_text("The bill passed, according to the clerk. Talks continue this morning, including on funding.", "x")
    assert "trailing_participle" not in rules_of(findings)


def test_times_with_colons_are_fine():
    assert "setup_colon_payoff" not in rules_of(lint_text("Polls close at 8:00 p.m.", "x"))


def test_headline_rules():
    assert "headline_colon" in rules_of(lint_text("Fed holds: what it means", "headline", headline=True))
    assert "headline_question" in rules_of(lint_text("Will the Fed cut?", "headline", headline=True))


def test_long_quote_flagged():
    text = 'He said "we are going to take our time and look at every single piece of data before we decide anything at all".'
    assert "long_quote" in rules_of(lint_text(text, "x"))


def test_rule_of_three_is_a_warning():
    findings = lint_text("The plan is clear, concise, and compelling.", "x")
    triads = [f for f in findings if f.rule == "rule_of_three"]
    assert triads and triads[0].severity == "warning"


def test_model_rejects_over_budget_headline():
    with pytest.raises(ValueError):
        make_story(headline="Federal Reserve holds rates steady for a third consecutive meeting")


def test_model_rejects_untraced_item():
    with pytest.raises(ValueError):
        make_story(sources=[Source(outlet="x", url="https://example.org", lean=Lean.center, covers=["what_happened"])])


def test_vague_who_in_dispute_fails():
    story = make_story(disputed=[Dispute(
        claim="whether it is too slow",
        side_a_position="Holding risks a slowdown",
        side_a_who="critics",
        side_b_position="Cutting restarts inflation",
        side_b_who="Bloomberg economics team",
    )])
    result = lint_story(story)
    assert any(f.rule == "vague_attribution" and f.field == "disputed.0.side_a_who" for f in result.findings)


def test_uniform_rhythm_warns():
    story = make_story(
        what_happened="The Fed held rates steady on Wednesday again. The vote was eleven to one this time. Powell wants two more months of data now.",
        why_it_matters="Mortgage rates stay where they are through winter.",
    )
    result = lint_story(story, min_sentence_stdev=3.0)
    assert "uniform_rhythm" in rules_of(result.warnings)
