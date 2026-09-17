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
4 graded predictions, 1 correct. That is not a track record — it is a sample far
too small to distinguish skill from a coin flip, and it is published here
unedited for exactly that reason. The point of the loop is that the misses get
written down and diagnosed, not that the calls are good.

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
- **Portfolio history is partly reconstructed.** Of the logged rows, roughly
  two-thirds were back-filled from historical closes when logging began; only
  the remainder were captured live. Rows carry a `source` column marking which.

---

## License

MIT
