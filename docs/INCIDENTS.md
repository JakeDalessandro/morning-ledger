# Incidents

Two errors reached a published brief. Both were confident, well written, and
wrong. That is why they are written down here: in this system, fluent output is
not evidence of accurate output.

Each entry covers what happened, the impact, the root cause, why nothing caught
it, and the guard now built into the procedure. The two smaller log errors the
system caught on its own are in the [README](../README.md#two-bookkeeping-failures-the-loop-caught-on-itself).

---

## 1. An invented market holiday (2026-08-30)

**What happened.** The week-ahead section assumed September 1 fell on a Monday.
It was a Tuesday. Everything built on that assumption moved with it:

- It said markets were closed that Monday for Labor Day. They were open; Labor
  Day was September 7.
- It put the jobs report on "Friday, September 5", which was a Saturday. The
  release was Friday, September 4.
- It put the FOMC meeting on September 17. The meeting ran September 15–16.

**Impact.** The whole week-ahead timeline was off by one day, in a section read
to plan around those releases.

**Root cause.** The weekday was inferred instead of read from the clock. One bad
anchor date, and every date derived from it was wrong in the same direction.

**Why it wasn't caught.** Nothing checked a written date against its weekday,
and the prose read naturally, so the error didn't look like one.

**Guard.** Date discipline in the procedure: take the weekday from the system
clock, never infer a holiday, confirm release dates against the publishing body
(BLS, the Fed, the exchange calendar), and check every written date against its
weekday before publishing.

---

## 2. A futures session that hadn't happened (2026-09-06)

**What happened.** A Sunday brief built at 11:22 AM Pacific led with fed funds
futures having "reopened Sunday evening", with the odds of a rate hike jumping
from 58% to 66–68%. CME futures reopen at 3:00 PM Pacific on Sunday, hours after
the build, so the session had not happened yet. The 66% figure came from an
article dated August 31, six days earlier, and later reporting had the odds
drifting back down toward 58%.

**Impact.** The invented move drove the sub-headline, the summary, the top
"what to watch" item, a timeline entry, and a resized scenario in the analysis.
One wrong number became five wrong conclusions.

**Root cause.** A search result was treated as current because it was found
today, and an event was narrated forward past the moment the brief was built.

**Why it wasn't caught.** The build time was on the page, but nothing compared
it to the trading hours of the market being described.

**Guard.** Market-clock discipline in the procedure: get the real time first,
know the session hours of any market cited, stamp the build time honestly,
check the date on every sourced figure, and write "no reading yet" rather than a
plausible guess. Since 2026-09-25 the price strip also carries an as-of time and
source for every number, so a stale one is visible on the page itself.

---

## The pattern

Both errors were **fabricated freshness**: a stale or not-yet-existent number
presented as a live move, because a daily brief reads better when it has
something new to say. That pressure comes from the format itself, so the fix
has to live in the format too. On a day with no new market story, the correct
brief says so.
