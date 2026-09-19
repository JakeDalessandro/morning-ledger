# State log schemas

The logs themselves are not published — they contain personal financial and
academic data. The schemas are, so the design is legible without the contents.

## `portfolio-log.csv`

Daily position snapshot.

| Column | Type | Notes |
|---|---|---|
| `date` | date | `YYYY-MM-DD` |
| `voo_close`, `qqqm_close` | float | Daily closes |
| `voo_shares`, `qqqm_shares` | float | Fractional shares held |
| `value` | float | Market value |
| `cost_basis` | float | Total contributed |
| `gain`, `gain_pct` | float | Derived |
| `source` | enum | `logged` (captured live) or `reconstructed` (back-filled) |

The `source` column exists so back-filled history is never silently treated as
measured. Of 35 current rows, 20 are reconstructed and 15 were captured live.

**Invariant:** `voo_close` / `qqqm_close` come from the settled daily bar for
that date, never from a live or delayed quote endpoint. An evening run once
logged an after-hours print 4 cents off the official close; each run now
re-checks the prior day's row against the daily series.

**Weekend and holiday rule:** one row per *trading* day. A non-trading day writes
no row at all rather than repeating the previous close, so a gap in the dates is
meaningful rather than ambiguous.

## `prediction-log.csv`

Directional calls, one row per prediction.

| Column | Type | Notes |
|---|---|---|
| `date_predicted` | date | When the call was made |
| `predicted_for_date` | date | The session being called |
| `direction` | enum | `up` / `down` |
| `reasoning` | text | Full rationale, written before the outcome |
| `graded` | bool | Has the horizon passed |
| `prior_close`, `actual_close` | float | Filled at grading |
| `actual_direction` | enum | Filled at grading |
| `correct` | bool | Derived at grading |

`reasoning` is captured before the outcome is known, which is what makes the
grade meaningful rather than reconstructed after the fact. It is a free-text
field containing commas, so it is written through an RFC 4180 writer — see the
rotation-log note below.

**Grading invariant:** every ungraded row whose `predicted_for_date` is on or
before the last completed session is graded, as a backward scan rather than an
exact-match lookup — an exact match orphans a row forever if a run is ever
skipped for more than a day. `actual_close` must be the close **on that row's
own `predicted_for_date`**, and a row whose session has not finished is never
graded.

**Revision rule:** a call may be revised while it is still ungraded — the
natural key is `predicted_for_date`, so the row is updated in place and never
duplicated. One call has been reversed after publication; the reasoning field
records both the original argument and what changed it.

## `reads-log.csv`

Sized scenarios with a horizon — the wordier sibling of the prediction log.

| Column | Type | Notes |
|---|---|---|
| `date_written` | date | |
| `horizon` | text | The event being waited on |
| `horizon_date` | date | When it becomes checkable |
| `scenario` | text | The claim, with a dollar or percent size attached |
| `graded` | bool | |
| `outcome` | text | Retrospective: claim vs. reality, and the mechanism missed |

## `rotation-log.csv`

Anti-repetition state.

| Column | Type | Notes |
|---|---|---|
| `kind` | enum | `block` / `term` / `stock` |
| `item` | text | Identifier |
| `last_used` | date | Drives the cooldown window; blank means never used |
| `notes` | text | Angle used, so a re-run varies rather than repeats |

**Natural key: `(kind, item)`, and it must be unique.** This file corrupted
itself once by being appended to with string concatenation: an unquoted comma
inside `notes` split 17 rows, and repeated appends accumulated duplicate keys.
Because the selection rule picks the eligible item with the *oldest* `last_used`,
a stale duplicate could be chosen while a fresher row for the same item existed —
so an item reappeared inside its own cooldown window, defeating the only thing
the file is for.

Writes must therefore: parse the whole file, mutate the parsed rows, write the
whole file back; quote any field containing a comma, quote or newline (RFC 4180,
inner quotes doubled); update an existing key rather than appending; and stamp
exactly one row per item.
