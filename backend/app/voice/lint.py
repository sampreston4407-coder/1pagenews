"""The voice linter. Runs on every story before it can be published.

An error fails the story. A warning is logged and the story still ships, but
the pipeline reports it so the prompt can be tuned against real misses.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from typing import Iterable

from app.voice import rules

try:
    from app.models import Story
except ImportError:  # pragma: no cover
    Story = object  # type: ignore[assignment,misc]


@dataclass(frozen=True)
class Finding:
    rule: str
    field: str
    phrase: str
    message: str
    severity: str = "error"  # "error" or "warning"

    def __str__(self) -> str:
        return f"[{self.severity}] {self.field}: {self.rule} -> {self.phrase!r} ({self.message})"


@dataclass
class LintResult:
    findings: list[Finding] = field(default_factory=list)
    sentence_lengths: list[int] = field(default_factory=list)

    @property
    def errors(self) -> list[Finding]:
        return [f for f in self.findings if f.severity == "error"]

    @property
    def warnings(self) -> list[Finding]:
        return [f for f in self.findings if f.severity == "warning"]

    @property
    def ok(self) -> bool:
        return not self.errors

    @property
    def sentence_length_stdev(self) -> float:
        n = len(self.sentence_lengths)
        if n < 2:
            return 0.0
        mean = sum(self.sentence_lengths) / n
        return math.sqrt(sum((x - mean) ** 2 for x in self.sentence_lengths) / n)


_BANNED_WORD_RE = re.compile(r"\b(" + "|".join(map(re.escape, rules.BANNED_WORDS)) + r")\b", re.IGNORECASE)
_BANNED_PHRASE_RE = re.compile(
    r"\b(" + "|".join(re.escape(p).replace(r"\ ", r"\s+") for p in rules.BANNED_PHRASES) + r")\b",
    re.IGNORECASE,
)
_FIG_SPACE_RE = re.compile(rules.FIGURATIVE_SPACE, re.IGNORECASE)
_VAGUE_RE = re.compile(rules.VAGUE_ATTRIBUTION, re.IGNORECASE)
_HEDGE_RE = re.compile(rules.HEDGE_STACK, re.IGNORECASE)
_NOT_JUST_RE = re.compile(rules.NOT_JUST_BUT, re.IGNORECASE)
_TRAILING_PARTICIPLE_RE = re.compile(r",\s+([A-Za-z]+ing)\b")
_PROSE_COLON_RE = re.compile(r"[A-Za-z]:\s")
_PAREN_RE = re.compile(r"\([^)]*\)")
_QUOTE_RE = re.compile(r"[\"“]([^\"”]{3,})[\"”]")
_SENTENCE_SPLIT_RE = re.compile(r"(?<!\d)[.!?]+(?=\s|$)")
_RULE_OF_THREE_RE = re.compile(r"\b([A-Za-z]+), ([A-Za-z]+),? and ([A-Za-z]+)\b")


def split_sentences(text: str) -> list[str]:
    parts = [p.strip() for p in _SENTENCE_SPLIT_RE.split(text)]
    return [p for p in parts if p]


def lint_text(text: str, field_name: str, *, headline: bool = False) -> list[Finding]:
    """Voice checks on a single string. Structural budgets are checked by the
    model and by lint_story, not here."""
    out: list[Finding] = []

    def add(rule: str, phrase: str, message: str, severity: str = "error") -> None:
        out.append(Finding(rule, field_name, phrase, message, severity))

    for m in _BANNED_WORD_RE.finditer(text):
        add("banned_word", m.group(0), "on the hard ban list")
    for m in _BANNED_PHRASE_RE.finditer(text):
        add("banned_phrase", m.group(0), "on the hard ban list")
    for m in _FIG_SPACE_RE.finditer(text):
        add("banned_word", m.group(0), "figurative 'space'")

    if "—" in text or "–" in text or "--" in text:
        add("dash", "—", "no em-dashes or en-dashes, use a period or a comma")
    if ";" in text:
        add("semicolon", ";", "two sentences instead")

    if headline:
        if ":" in text:
            add("headline_colon", ":", "no colons in headlines")
        if "?" in text:
            add("headline_question", "?", "no question marks in headlines")
    else:
        for m in _PROSE_COLON_RE.finditer(text):
            add("setup_colon_payoff", text[max(0, m.start() - 20): m.end() + 20].strip(), "no setup-colon-payoff")

    for m in _PAREN_RE.finditer(text):
        add("parenthetical", m.group(0), "if it matters say it in a sentence, if not cut it")

    for m in _TRAILING_PARTICIPLE_RE.finditer(text):
        word = m.group(1)
        if word.lower() not in rules.PARTICIPLE_ALLOWLIST:
            add("trailing_participle", text[max(0, m.start() - 20): m.end() + 30].strip(), "comma then -ing clause, split it or cut it")

    for m in _VAGUE_RE.finditer(text):
        add("vague_attribution", m.group(0), "name a person or an outlet")
    for m in _HEDGE_RE.finditer(text):
        add("hedge_stack", m.group(0), "pick one level of certainty")
    for m in _NOT_JUST_RE.finditer(text):
        add("not_just_but", m.group(0), "banned construction")

    for m in _QUOTE_RE.finditer(text):
        quoted = m.group(1)
        if len(quoted.split()) > rules.MAX_QUOTE_WORDS:
            add("long_quote", quoted, f"direct quotes stay under {rules.MAX_QUOTE_WORDS} words")

    for m in _RULE_OF_THREE_RE.finditer(text):
        add("rule_of_three", m.group(0), "machines love triads, use two or four", severity="warning")

    return out


def _who_is_named(who: str) -> bool:
    """A named party has at least one capitalized token that is not the first
    word of the string. Crude, but it catches 'critics' and 'many economists'."""
    tokens = who.split()
    if len(tokens) == 1:
        return tokens[0][:1].isupper() and tokens[0].lower() not in {"critics", "experts", "analysts", "observers"}
    return any(t[:1].isupper() for t in tokens[1:]) or tokens[0][:1].isupper()


def _prose_fields(story: Story) -> Iterable[tuple[str, str]]:
    yield "what_happened", story.what_happened
    for i, item in enumerate(story.not_in_dispute):
        yield f"not_in_dispute.{i}", item
    for i, d in enumerate(story.disputed):
        yield f"disputed.{i}.claim", d.claim
        yield f"disputed.{i}.side_a_position", d.side_a_position
        yield f"disputed.{i}.side_b_position", d.side_b_position
    for i, f in enumerate(story.framing):
        yield f"framing.{i}.how_they_put_it", f.how_they_put_it
    yield "why_it_matters", story.why_it_matters


def lint_story(story: Story, *, min_sentence_stdev: float = 3.0) -> LintResult:
    result = LintResult()
    result.findings += lint_text(story.headline, "headline", headline=True)

    for name, text in _prose_fields(story):
        result.findings += lint_text(text, name)

    # Shape checks the model can't express.
    sentences = split_sentences(story.what_happened)
    if not 2 <= len(sentences) <= 3:
        result.findings.append(Finding("sentence_count", "what_happened", story.what_happened, f"2 to 3 sentences, got {len(sentences)}"))
    if len(split_sentences(story.why_it_matters)) != 1:
        result.findings.append(Finding("sentence_count", "why_it_matters", story.why_it_matters, "one sentence"))

    for i, d in enumerate(story.disputed):
        for side in ("side_a_who", "side_b_who"):
            who = getattr(d, side)
            if _VAGUE_RE.search(who + " say") or not _who_is_named(who):
                result.findings.append(Finding("vague_attribution", f"disputed.{i}.{side}", who, "name the outlet or the person"))

    # Rhythm. Uniform sentence length is the tell that survives every word filter.
    for name, text in _prose_fields(story):
        if name.startswith("what_happened") or name.startswith("why_it_matters") or name.startswith("disputed"):
            result.sentence_lengths += [len(s.split()) for s in split_sentences(text)]
    if len(result.sentence_lengths) >= 4 and result.sentence_length_stdev < min_sentence_stdev:
        result.findings.append(Finding(
            "uniform_rhythm", "story", f"stdev={result.sentence_length_stdev:.1f}",
            "sentence lengths barely vary, let some run short and one run long", severity="warning",
        ))

    return result


def format_report(story_id: str, result: LintResult) -> str:
    lines = [f"{story_id}: {'ok' if result.ok else 'FAIL'} ({len(result.errors)} errors, {len(result.warnings)} warnings, rhythm stdev {result.sentence_length_stdev:.1f})"]
    lines += [f"  {f}" for f in result.findings]
    return "\n".join(lines)
