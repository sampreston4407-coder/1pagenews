"""The ban lists from the brief, section 6.2. Keep these in one place so a
prompt tweak and a linter tweak always see the same list."""

BANNED_WORDS = [
    "delve", "delves", "delved", "delving",
    "underscore", "underscores", "underscored", "underscoring",
    "showcase", "showcases", "showcased", "showcasing",
    "highlight", "highlights", "highlighted", "highlighting",
    "navigate", "navigates", "navigated", "navigating",
    "leverage", "leverages", "leveraged", "leveraging",
    "foster", "fosters", "fostered", "fostering",
    "robust", "comprehensive", "crucial", "pivotal", "significant", "significantly",
    "notable", "notably", "myriad", "tapestry", "landscape", "realm",
    "testament", "nuanced", "multifaceted", "intricate", "seamless", "seamlessly",
    "vital", "profound", "profoundly",
    "garner", "garners", "garnered", "garnering",
    "bolster", "bolsters", "bolstered", "bolstering",
    "spearhead", "spearheads", "spearheaded", "spearheading",
    "unprecedented", "stark", "starkly",
    "grapple", "grapples", "grappled", "grappling",
    "amid", "amidst", "poised", "seismic", "watershed",
]

BANNED_PHRASES = [
    "it's worth noting", "it is worth noting",
    "it's important to remember", "it is important to remember",
    "that said", "in essence", "essentially", "ultimately", "arguably",
    "indeed", "moreover", "furthermore", "in conclusion", "at the end of the day",
    "only time will tell", "remains to be seen", "the debate continues",
    "sparked debate", "sparks debate", "raises questions", "raised questions",
    "marks a turning point", "marked a turning point",
    "sends a signal", "sent a signal",
    "here's what happened", "here is what happened",
    "let's break it down", "let us break it down",
    "both sides have valid", "both sides make valid", "both sides have a point",
    "in a major development", "in a move that", "in a surprise move",
    "in a development that",
]

# Figurative "space". Literal space (the probe, the launch) is fine.
FIGURATIVE_SPACE = r"\b(?:in|into|within) the [\w-]+ space\b"

# "critics say", "experts warn", "many believe". Always name someone.
VAGUE_ATTRIBUTION = (
    r"\b(?:critics|experts|observers|analysts|many|some|supporters|opponents|"
    r"officials|sources|insiders|pundits|commentators)\s+"
    r"(?:say|said|says|argue|argued|argues|believe|believed|warn|warned|note|noted|"
    r"suggest|suggested|claim|claimed|fear|feared|contend|contended|point out|pointed out)\b"
)

# Words ending in -ing that are not participles opening a clause.
PARTICIPLE_ALLOWLIST = {
    "according", "including", "during", "morning", "evening", "something",
    "nothing", "everything", "anything", "thing", "king", "ring", "wing",
    "string", "spring", "bring", "sing", "swing", "cling", "sting", "fling",
    "boeing", "beijing", "wyoming", "reading", "building", "meeting", "funding",
    "spending", "housing", "hearing", "briefing", "ruling", "filing", "opening",
    "closing", "training", "earnings", "warning", "ceiling", "wedding", "morning",
    "beginning", "ending", "landing", "sitting", "standing", "voting",
    "coming", "following", "existing", "ongoing", "leading", "remaining",
    "pending", "outstanding", "willing", "trading", "banking", "mining",
    "lending", "borrowing", "polling", "shipping", "farming", "fishing",
    "writing", "printing", "clothing", "wiring", "plumbing", "cooling", "heating",
}

# "may potentially", "could possibly suggest"
HEDGE_STACK = r"\b(?:may|might|could|would)\s+(?:potentially|possibly|perhaps|conceivably|arguably)\b"

# "not just X, but Y"
NOT_JUST_BUT = r"\bnot\s+(?:just|only|merely|simply)\b[^.!?]{1,80}\bbut\b"

MAX_QUOTE_WORDS = 15
