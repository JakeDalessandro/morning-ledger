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
measured. Roughly two-thirds of current rows are reconstructed.

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
grade meaningful rather than reconstructed after the fact.

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
| `last_used` | date | Drives the cooldown window |
| `notes` | text | Angle used, so a re-run varies rather than repeats |
