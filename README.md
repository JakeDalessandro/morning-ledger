# Morning Ledger

An automated daily market brief that runs itself, degrades gracefully when its
data sources are unreachable, and grades its own predictions against what
actually happened.

Built as a personal tool and kept running daily since August 2026. This repo
documents the system design and publishes the trigger mechanism; the brief's
content procedure and my personal financial data are deliberately excluded.

---

## What it does

Once per day, on the first session I open, it assembles an eight-section brief:
market movements, portfolio position, metals and the dollar, watch items,
analysis, stocks of note, finance terminology, and personal action items. It
publishes to a standing URL and fires a push notification.

The interesting part isn't the brief. It's the machinery that makes a
once-per-day job reliable when the runtime is a chat session that can start,
resume, clear, and compact unpredictably.

---

## The problem that shaped the design

The first version ran on a 9am cron. It worked, and the output was quietly
worse every single day.

Unattended runs couldn't connect to the browser automation layer, so every
source that needed an authenticated session silently fell back to a degraded
substitute. The brief still published. It still looked complete. It was just
consistently thinner than it should have been, and nothing in the output said so.

**The fix wasn't better error handling — it was changing when the job runs.**
Moving the trigger to a `SessionStart` hook means the run happens while I'm
present, which is exactly the condition the browser layer needs. The scheduled
job stayed on as a fallback, but guarded, and it now labels its own output as
the degraded edition.

That's the design lesson the rest of the system is built around: a fallback that
doesn't announce itself is worse than a visible failure.

---

## Architecture

Two execution paths, two independent markers, one source of truth.

```
SessionStart hook ──┐
                    ├──> morning-ledger skill ──> publish ──> stamp PUBLISHED
Scheduled fallback ─┘         (the only procedure)
```

| Path | Fires when | Guard |
|---|---|---|
| `SessionStart` hook | First session of the calendar day | Silent if *either* marker is today |
| Scheduled fallback | Late afternoon | Runs only if `PUBLISHED` is not today |

### Why two markers and not one

They answer different questions, and one flag cannot do both jobs:

- **`FIRED`** — "the hook already fired today." Stops it nagging on every
  subsequent session of the same day.
- **`PUBLISHED`** — "a brief actually made it out today." Covers the case where
  the hook fired but I deferred it to do something else.

Collapsing them into one flag breaks whichever case it wasn't chosen for.

### Why the marker is stamped before the work, not after

```bash
printf '%s\n' "$TODAY" > "$FIRED" 2>/dev/null || exit 0
```

Stamping first means a downstream failure can't produce a retry loop. The
tradeoff is deliberate: a crashed run loses that day's brief rather than
risking the hook re-firing on every session until something succeeds. For a
daily brief, a missed day is cheap and a nag loop is expensive.

### Why SessionStart firing multiple times doesn't matter

`SessionStart` also fires on resume, `/clear`, and context compaction. Every one
of those hits the already-stamped branch and exits silently. The datestamp makes
the hook idempotent without any matcher logic to special-case the event type.

---

## The self-grading loop

Any prediction specific enough to be checkable gets logged with a horizon date
and the reasoning behind it. When a later run passes that horizon, it writes one
retrospective line: what was claimed, what happened, and — when they differ —
the mechanism that was misjudged.

This exists because a system that only ever forecasts forward has no way to be
wrong, and a tool that can't be wrong isn't telling you anything.

A representative entry, after grading:

> **HALF RIGHT.** Direction was right, magnitude was badly wrong: predicted
> −1% to −2%, actual −0.05% — a 20–40× overestimate. Cause: sized the print as
> if it landed into an unchanged backdrop, but dovish comments 24h earlier had
> already moved the odds, and the strong print only moved them back. The two
> events largely cancelled. **Lesson: size the delta versus what is already
> priced, not the absolute surprise.**

**On the record itself:** at the time of writing, the directional call log holds
6 graded predictions, 3 correct. That is not a track record — it is a sample far
too small to distinguish skill from a coin flip, and it is published here
unedited for exactly that reason. The point of the loop is that the misses get
written down and diagnosed, not that the calls are good.

### Two bookkeeping failures the loop caught on itself

Both were found by the next day's run re-reading what the previous one wrote,
which is the only reason they are documented rather than compounding:

- **A row graded against the wrong session.** A mid-session run read the grading
  rule as "grade the newest pending row" and scored it with the most recent close
  it happened to be holding, rather than the close on that row's own target date.
  The displayed record stayed correct; only the log was mislabeled.
  **Guard:** the close written to a row must be the close *on that row's target
  date*, and a row whose session has not finished is never graded.
- **An after-hours quote logged as an official close.** An evening run recorded
  701.82 where the settled daily bar said 701.78 — 4 cents, which moved the
  portfolio total by 38 cents and would have compounded silently in a log that is
  never re-derived. **Guard:** closes come from the daily time series, never from
  a live quote endpoint, and each run re-checks the prior day's row against it.

---

## Anti-repetition state

A daily brief decays into boilerplate fast. Every teaching block, defined term,
and featured stock is tracked with a `last_used` date:

| Item type | Rule |
|---|---|
| Teaching blocks | One per run, no repeat within 7 days |
| Terms | No reuse within 14 days |
| Stocks | At most 2 carried over from the prior run |

The governing test: **if a section would read the same tomorrow, cut it today.**

### The state files are written by a real CSV writer, not string concatenation

This rule exists because the rotation log corrupted itself. Rows were being
appended by joining fields with commas; one `notes` value contained a comma,
nothing quoted it, and 17 rows silently split into extra fields. Worse, repeated
appends accumulated **duplicate `(kind, item)` keys** — and since the rotation
rule picks the eligible item with the *oldest* `last_used`, a stale duplicate
could win while a fresher row for the same item existed, defeating the cooldown
it was there to enforce. One ticker reappeared four times inside its own 7-day
window before anyone noticed.

The fix is boring and absolute: **read the whole file, parse it, mutate the
parsed rows, write the whole file back.** Quote any field containing a comma,
quote, or newline (RFC 4180). Enforce uniqueness on the natural key before
writing — update the existing row, never append a second one. Stamp exactly one
row per item.

The general lesson: a log that is only ever appended to and never read back is a
log nobody is validating.

---

## Repo contents

```
hooks/morning-ledger-trigger.sh   The daily trigger. Idempotent, path-generic.
docs/ARCHITECTURE.md              Execution paths, failure modes, known races.
schemas/                          Column definitions for the state logs.
```

### What is deliberately not here

- **The brief procedure itself** — it's densely personal (coursework, work
  schedule, job search, account details) and can't be meaningfully scrubbed.
- **Portfolio data** — real balances, share counts, and cost basis.
- **The state logs themselves** — same reason.

The schemas are published so the design is legible without the contents.

---

## Known limitations

- **The scheduled fallback needs the machine on.** It runs locally, so a
  fallback with the laptop asleep simply doesn't happen. That day gets no brief.
  A cloud-scheduled version would survive a powered-off machine but couldn't
  reach local state, so it isn't a substitute.
- **A narrow race exists.** Opening a session within a few minutes of the
  fallback's scheduled time can start both paths. Worst case is the fallback
  republishing over the attended brief at the same URL. Judged not worth more
  machinery for the frequency it occurs.
- **Portfolio history is partly reconstructed.** Of 35 rows, 20 were back-filled
  from historical closes when logging began and 15 were captured live. Rows carry
  a `source` column marking which, so the two are never conflated. The live share
  grows by one per trading day and will pass the reconstructed share around the
  end of October 2026.

---

## License

MIT
