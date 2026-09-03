"""Static content served by the API: the methodology page and the source list.
Written in the same voice as the stories. Edit here, not in the app."""

from __future__ import annotations

from app.models import Lean, SourceInfo

METHODOLOGY = {
    "title": "How this works",
    "sections": [
        {
            "heading": "Seven stories",
            "body": "Every morning we pull the day's coverage from outlets across the spectrum. We pick the seven events that most people would want to know about. Not the seven loudest. Then we stop. There is no eighth.",
        },
        {
            "heading": "Not in dispute",
            "body": "A line goes in this section only if every outlet we checked reports it the same way. Numbers, dates, names, who said what on the record. If two outlets disagree about it, even slightly, it does not go here. It goes in disputed, with both sides named.",
        },
        {
            "heading": "Disputed",
            "body": "This is where the argument lives. We name the specific claim and the specific people or outlets on each side. We never write 'critics say'. If we can't name who is arguing, we don't run the dispute.",
        },
        {
            "heading": "Framing",
            "body": "Same event, different words. We show how a left, center, and right outlet each put it, in our paraphrase. We don't tell you which one is right. You can see the pattern yourself.",
        },
        {
            "heading": "Sources",
            "body": "Every line traces back to at least one source you can tap. We paraphrase everything and link to the original. We don't reproduce articles.",
        },
        {
            "heading": "Writing",
            "body": "A machine drafts each story. Every draft runs through a checker that fails it for hedging, padding, filler words, and the other habits of generated text. A draft that fails gets rewritten. A draft that fails three times gets thrown out.",
        },
        {
            "heading": "Mistakes",
            "body": "When we get something wrong we fix it and log it. The log is public and permanent. To report an error, tap a story's sources and use the report link, or email corrections@1page.news.",
        },
    ],
}

SOURCES: list[SourceInfo] = [
    SourceInfo(outlet="BBC News", lean=Lean.center, homepage="https://www.bbc.com/news", why="Wire-style world coverage with a public editorial code."),
    SourceInfo(outlet="The Hill", lean=Lean.center, homepage="https://thehill.com", why="Straight coverage of Congress and the White House."),
    SourceInfo(outlet="CBS News", lean=Lean.center, homepage="https://www.cbsnews.com", why="Broadcast network newsroom, national desk."),
    SourceInfo(outlet="NPR", lean=Lean.left, homepage="https://www.npr.org", why="Public radio news desk. Rated lean left by AllSides."),
    SourceInfo(outlet="The Guardian", lean=Lean.left, homepage="https://www.theguardian.com", why="UK daily with a large US desk. Rated left by AllSides."),
    SourceInfo(outlet="Fox News", lean=Lean.right, homepage="https://www.foxnews.com", why="Largest right-leaning US newsroom. Rated right by AllSides."),
    SourceInfo(outlet="Washington Examiner", lean=Lean.right, homepage="https://www.washingtonexaminer.com", why="Right-leaning political daily. Rated lean right by AllSides."),
    SourceInfo(outlet="New York Post", lean=Lean.right, homepage="https://nypost.com", why="Right-leaning tabloid with a large national desk."),
]
