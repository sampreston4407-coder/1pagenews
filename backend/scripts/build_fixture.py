"""Builds the fixture edition: seven general stories plus one per optional
topic, all fictional, all written to the brief's voice. Writes
app/data/fixture_edition.json and runs the linter on the result.

Everything here is placeholder content. Outlets, people, and companies are
made up so nothing reads as a real claim about a real person.
"""

from __future__ import annotations

import json
import sys
from datetime import date, datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.models import Dispute, Edition, Framing, Lean, Source, Story, Topic  # noqa: E402
from app.voice.lint import format_report, lint_story  # noqa: E402

EDITION_DATE = date(2026, 9, 3)
PUBLISHED = datetime(2026, 9, 3, 11, 0, tzinfo=timezone.utc)
NEXT = datetime(2026, 9, 4, 11, 0, tzinfo=timezone.utc)

LEDGER = ("Capital Ledger", Lean.left)
WIRE = ("Sample Wire", Lean.center)
STANDARD = ("The Standard", Lean.right)


def sources(slug: str, story_keys: list[str]) -> list[Source]:
    """Three outlets across the spectrum. The wire covers everything, the
    other two back the event and the dispute."""
    partial = [k for k in story_keys if k == "what_happened" or k.startswith("disputed")]
    return [
        Source(outlet=WIRE[0], lean=WIRE[1], url=f"https://example.org/wire/{slug}", covers=story_keys),
        Source(outlet=LEDGER[0], lean=LEDGER[1], url=f"https://example.org/ledger/{slug}", covers=partial),
        Source(outlet=STANDARD[0], lean=STANDARD[1], url=f"https://example.org/standard/{slug}", covers=partial),
    ]


def story(slug: str, topic: Topic, headline: str, what: str, nid: list[str], dispute: tuple, framing: tuple[str, str, str], why: str) -> Story:
    keys = ["what_happened", "why_it_matters", "disputed.0"] + [f"not_in_dispute.{i}" for i in range(len(nid))]
    claim, a_pos, a_who, b_pos, b_who = dispute
    return Story(
        id=f"{EDITION_DATE.isoformat()}-{slug}",
        headline=headline,
        what_happened=what,
        not_in_dispute=nid,
        disputed=[Dispute(claim=claim, side_a_position=a_pos, side_a_who=a_who, side_b_position=b_pos, side_b_who=b_who)],
        framing=[
            Framing(outlet=LEDGER[0], lean=LEDGER[1], how_they_put_it=framing[0]),
            Framing(outlet=WIRE[0], lean=WIRE[1], how_they_put_it=framing[1]),
            Framing(outlet=STANDARD[0], lean=STANDARD[1], how_they_put_it=framing[2]),
        ],
        why_it_matters=why,
        sources=sources(slug, keys),
        updated_at=PUBLISHED,
        topic=topic,
    )


GENERAL = [
    story(
        "budget", Topic.general,
        "Budget talks stall, shutdown four weeks out",
        "Negotiators walked out Wednesday with no deal. Government funding runs out at midnight on September 30. Nobody has scheduled the next meeting.",
        [
            "Funding expires at midnight on September 30.",
            "The two sides are about $40 billion apart on discretionary spending.",
            "No follow-up meeting is on the calendar.",
            "A short-term extension has been floated but not filed.",
        ],
        (
            "who walked away from the table",
            "Speaker Dana Whitfield said Wednesday the minority refused to put a number in writing",
            "Speaker Dana Whitfield",
            "Minority Leader Ray Okafor said his side offered a number and the Speaker rejected it within the hour",
            "Minority Leader Ray Okafor",
        ),
        ("Majority walks out, benefits on the line", "Budget talks break off with four weeks left", "Minority stalls as deficit climbs"),
        "A lapse would pause paychecks for about two million federal workers.",
    ),
    story(
        "rail-strike", Topic.general,
        "Rail strike set for Tuesday",
        "The rail union set a strike for just after midnight Tuesday. Members voted down the latest contract 71 to 29. Talks continue through the weekend.",
        [
            "Strike starts at 12:01 Tuesday morning unless a deal is reached.",
            "Members rejected the offer 71 percent to 29.",
            "Commuter and freight service on the main corridor would stop.",
            "The last strike on the corridor, in 2019, lasted three days.",
        ],
        (
            "whether the pay offer beats inflation",
            "Union president Marta Ruiz said the offer trails prices once the two-tier scale kicks in for new hires",
            "Union president Marta Ruiz",
            "Railway CEO Tom Beck said the offer is 4 percent a year, above inflation, and the union knows it",
            "Railway CEO Tom Beck",
        ),
        ("Workers push back on two-tier pay", "Rail strike set for Tuesday after members reject offer", "Union threatens commute chaos over 4 percent raise"),
        "If you ride the corridor, plan another way in from Tuesday.",
    ),
    story(
        "peace-talks", Topic.general,
        "Peace talks restart after two-week pause",
        "Both delegations sat down again Wednesday in Geneva. On the table is a 60-day ceasefire and a prisoner swap. Neither side has signed off on the draft.",
        [
            "Talks resumed Wednesday morning in Geneva with mediators present.",
            "The draft proposes a 60-day ceasefire and a prisoner exchange.",
            "The previous round ended August 19 with no deal.",
            "A further session is set for Friday.",
        ],
        (
            "whether a ceasefire now locks in territorial gains",
            "Foreign minister Ilse Brandt said a pause without withdrawal rewards the invasion",
            "Foreign minister Ilse Brandt",
            "UN mediator Samuel Adeyemi said the pause is the only way to get aid through before winter",
            "UN mediator Samuel Adeyemi",
        ),
        ("Aid corridor hinges on ceasefire deal", "Peace talks resume in Geneva", "Ceasefire draft would freeze front lines in place"),
        "A ceasefire would reopen the main aid route and could ease grain prices.",
    ),
    story(
        "fed-hold", Topic.general,
        "Fed holds rates, hints at December cut",
        "The Fed left rates at 4.25 percent Wednesday. The vote was 10 to 2. The statement dropped the line about further increases, which is the closest it has come to promising a cut.",
        [
            "Rate stays at 4.25 percent.",
            "Vote was 10 to 2, with two members wanting a cut now.",
            "Inflation was 2.6 percent in July, down from 3.1 in January.",
            "Next decision is October 29.",
        ],
        (
            "whether waiting risks a hiring slowdown",
            "The Capital Ledger editorial board said rates this high are already pushing up youth unemployment",
            "Capital Ledger editorial board",
            "Standard columnist Pete Marlow said services inflation is still sticky and a cut now repeats 2021",
            "Standard columnist Pete Marlow",
        ),
        ("Fed keeps squeezing borrowers", "Fed holds, signals cut may come", "Fed bows to pressure, drops rate-hike language"),
        "Mortgage and car loan rates stay about where they are until at least October.",
    ),
    story(
        "voter-id", Topic.general,
        "Statehouse passes photo ID law for November",
        "The statehouse passed a photo ID requirement Tuesday on a party-line vote. The governor signed it the same day. A lawsuit was filed within hours.",
        [
            "Voters will need a government photo ID to vote in person.",
            "A free state voter card counts.",
            "The law applies to the November 3 election unless a court blocks it.",
            "The League of Voters filed suit in state court Wednesday.",
        ],
        (
            "how many registered voters lack an accepted ID",
            "The League of Voters said its count is about 180,000, mostly older and rural voters",
            "League of Voters",
            "Secretary of State Carla Nunes said fewer than 40,000, and all of them can get the free card",
            "Secretary of State Carla Nunes",
        ),
        ("New ID law puts 180,000 votes at risk", "Photo ID law signed, lawsuit filed same day", "Voter ID becomes law with free card for all"),
        "If you vote in person in November, bring a photo ID or get the free card.",
    ),
    story(
        "grid-heat", Topic.general,
        "Heat pushes power grid to record demand",
        "Three grid operators asked people to cut power use Tuesday evening. Demand set a record, 4 percent above last summer's peak. Nobody has lost power yet.",
        [
            "Peak demand Tuesday was about 4 percent above last summer's record.",
            "Three operators issued voluntary conservation notices for 4 to 9 in the evening.",
            "No forced outages have been reported.",
            "Temperatures are forecast to drop from Saturday.",
        ],
        (
            "why the evening gap is getting worse",
            "Grid operator chief Ana Ferreira said retired gas plants have not been replaced with anything that runs after sunset",
            "Grid operator chief Ana Ferreira",
            "Energy secretary Mark Doyle said transmission approvals, not plant closures, are the bottleneck",
            "Energy secretary Mark Doyle",
        ),
        ("Climate heat tests an underbuilt grid", "Grid holds under record heat demand", "Green transition leaves grid short after dark"),
        "Rolling outages are possible through Friday if you are in the three affected states.",
    ),
    story(
        "phone-repair", Topic.general,
        "Phone maker to sell parts and manuals",
        "Helix will sell screens, batteries, cameras, and charging ports for its last four phone generations from October 6. Official repair manuals come with them. Self-repairs with official parts keep the warranty.",
        [
            "Parts and manuals go on sale October 6 in the US and EU.",
            "Covers phones from the last four years.",
            "A screen kit costs $119, about 40 percent under the store repair price.",
            "Using official parts does not void the warranty.",
        ],
        (
            "whether new repair laws forced the change",
            "Representative Lena Ostrowski, who wrote the state repair bill, said Helix fought it for three years and folded once it passed",
            "Representative Lena Ostrowski",
            "Helix hardware chief Devin Cole said the program was in the works before any bill and the timing is a coincidence",
            "Helix hardware chief Devin Cole",
        ),
        ("Right-to-repair pressure pays off", "Helix opens parts sales to customers", "Helix beats regulators to the punch on repairs"),
        "A cracked Helix screen costs about $119 to fix yourself from next month.",
    ),
]

TOPICAL = {
    Topic.ai: [story(
        "ai-rules", Topic.ai,
        "New AI safety rules take effect",
        "Rules for the largest AI models took effect Monday. Developers must file safety test results 30 days before release. Fines run up to 3 percent of global revenue.",
        [
            "Applies to models trained with more than 10^26 operations.",
            "Safety filings are due 30 days before public release.",
            "Maximum fine is 3 percent of global annual revenue.",
            "Fewer than a dozen current models meet the threshold.",
        ],
        (
            "whether the compute threshold is the right line",
            "Commissioner Ines Vogel said compute is the only number regulators can verify from outside",
            "Commissioner Ines Vogel",
            "Anthem Labs CEO Raj Mehta said capability, not compute, is what matters and the line will be obsolete in a year",
            "Anthem Labs CEO Raj Mehta",
        ),
        ("AI rules land, but nothing on jobs or copyright", "Safety filing rules begin for largest AI models", "New AI rules hand a head start to overseas rivals"),
        "Model releases from the biggest labs will now come with a public safety report.",
    )],
    Topic.finance: [story(
        "jobs-august", Topic.finance,
        "Jobs report shows slowest hiring since 2020",
        "Employers added 41,000 jobs in August. That is the weakest month since the pandemic. Unemployment ticked up to 4.6 percent.",
        [
            "August payrolls grew by 41,000.",
            "Unemployment rose to 4.6 percent from 4.4.",
            "June and July were revised down by a combined 58,000.",
            "Average hourly pay rose 3.4 percent over the year.",
        ],
        (
            "whether this is a slowdown or a blip",
            "Treasury secretary Joan Feld said one soft month after a hot summer is noise",
            "Treasury secretary Joan Feld",
            "Bank of Meridian chief economist Hal Yee said three months of downward revisions is a trend, not noise",
            "Bank of Meridian chief economist Hal Yee",
        ),
        ("Hiring stalls as rates stay high", "August job growth slows to 41,000", "Jobs miss shows the economy needs tax relief"),
        "A weak report makes an October rate cut more likely.",
    )],
    Topic.environment: [story(
        "offshore-wind", Topic.environment,
        "Court blocks offshore wind permit",
        "A federal judge paused the permit for the 80-turbine Cape Bell wind farm Tuesday. The ruling says the agency skipped a required whale survey. Construction was due to start in October.",
        [
            "Judge Ellen Park issued the stay on Tuesday.",
            "The project is 80 turbines about 15 miles offshore.",
            "The agency must complete a marine mammal survey before the permit returns.",
            "Construction had been set to begin in October.",
        ],
        (
            "how long the delay will last",
            "Northwind Energy said the survey is already half done and the project slips by months, not years",
            "Northwind Energy",
            "Fishermen's Alliance lawyer Sam Trask said a proper survey takes two seasons and the project is dead for 2027",
            "Fishermen's Alliance lawyer Sam Trask",
        ),
        ("Wind farm stalled by fishing lobby lawsuit", "Judge pauses offshore wind permit over whale survey", "Court reins in rushed wind approval"),
        "The state's 2030 clean power target depends on this project coming online.",
    )],
    Topic.sports: [story(
        "league-expansion", Topic.sports,
        "League adds two teams for 2028",
        "The league voted Wednesday to add franchises in Austin and Portland. Both start play in 2028. Each ownership group paid $1.2 billion.",
        [
            "Owners voted 28 to 2 to expand.",
            "Austin and Portland begin play in the 2028 season.",
            "Expansion fee was $1.2 billion per team.",
            "Rosters will be filled by an expansion draft in 2027.",
        ],
        (
            "whether the fee is fair to existing owners",
            "Commissioner Lou Barrett said the fee is split evenly and every owner gets about $85 million",
            "Commissioner Lou Barrett",
            "Owner Rita Alvarez, one of the two no votes, said the fee undervalues teams by a third",
            "Owner Rita Alvarez",
        ),
        ("Public asked to fund stadiums for billion-dollar teams", "League expands to Austin and Portland", "Two new markets, $2.4 billion in private money"),
        "The expansion draft in 2027 means every current roster loses a player.",
    )],
    Topic.health: [story(
        "otc-pill", Topic.health,
        "Blood pressure pill goes over the counter",
        "Regulators approved a 10 milligram version of amlodine for sale without a prescription. Buyers answer a short screening quiz at the register. It reaches shelves early next year.",
        [
            "Approval covers a 10 milligram daily dose for adults.",
            "A screening questionnaire is required at purchase.",
            "The drug has been prescription-only for over twenty years.",
            "Higher doses stay prescription-only.",
        ],
        (
            "whether insurers will stop covering it",
            "Patient group Heart Forward said insurers dropped coverage the last two times a drug went over the counter",
            "Heart Forward",
            "Insurer trade group head Neil Sato said members have no plans to change coverage",
            "Insurer trade group head Neil Sato",
        ),
        ("Easier access, but the bill may shift to patients", "Blood pressure drug approved for over-the-counter sale", "Regulator cuts red tape on 20-year-old drug"),
        "From next year you can buy a low-dose blood pressure pill without seeing a doctor.",
    )],
    Topic.science: [story(
        "asteroid-sample", Topic.science,
        "Asteroid sample capsule lands on target",
        "The Iris capsule landed in the Utah desert Sunday with about 250 grams of asteroid rock. It launched seven years ago. Labs in ten countries get pieces this month.",
        [
            "Capsule landed inside the recovery zone Sunday morning.",
            "Sample mass is estimated at 250 grams.",
            "The mission launched seven years ago.",
            "Samples will be shared with labs in more than ten countries.",
        ],
        (
            "whether the mission proves mining is viable",
            "Mission lead Priya Nair said this is science, and the economics of mining are decades off",
            "Mission lead Priya Nair",
            "Astra Metals founder Cal Reyes said the same guidance system gets a mining probe to a target for under $200 million",
            "Astra Metals founder Cal Reyes",
        ),
        ("Public science mission returns first metal-asteroid sample", "Asteroid sample capsule lands in Utah", "Asteroid return opens door to space mining"),
        "First results on what a metal asteroid is made of are due by December.",
    )],
    Topic.local: [story(
        "bus-lane", Topic.local,
        "City council approves bus lane on Main",
        "The council voted 6 to 3 Tuesday for a bus-only lane on Main Street between 5th and 20th. Work starts in spring. About 40 parking spaces go.",
        [
            "Vote was 6 to 3.",
            "The lane runs on Main between 5th and 20th.",
            "Construction starts in spring.",
            "Roughly 40 street parking spaces will be removed.",
        ],
        (
            "whether the lane slows car traffic",
            "Transit director Owen Hale said the city's model shows car trips on Main get two minutes slower",
            "Transit director Owen Hale",
            "Main Street Merchants president Dee Larkin said the model ignores delivery trucks and it will be closer to ten",
            "Main Street Merchants president Dee Larkin",
        ),
        ("Council picks buses over parking", "Main Street bus lane approved 6 to 3", "Council cuts 40 parking spots for a bus lane"),
        "Parking on Main between 5th and 20th disappears in spring.",
    )],
}


def main() -> int:
    edition = Edition(date=EDITION_DATE, published_at=PUBLISHED, next_edition_at=NEXT, stories=GENERAL, topic_stories=TOPICAL)
    out = Path(__file__).resolve().parents[1] / "app" / "data" / "fixture_edition.json"
    out.write_text(edition.model_dump_json(indent=2) + "\n")
    print(f"wrote {out}")

    failed = 0
    for story in list(edition.stories) + [s for group in edition.topic_stories.values() for s in group]:
        result = lint_story(story)
        print(format_report(story.id, result))
        failed += not result.ok
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
