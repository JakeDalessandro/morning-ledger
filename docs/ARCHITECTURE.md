# Architecture

## Execution paths

The brief has exactly one procedure and two ways to reach it. Keeping the
procedure in one place is deliberate — the fallback path invokes the skill
rather than carrying its own copy of the steps, so there is no second version
to drift.

### Path 1 — SessionStart hook (primary)

Registered in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "shell": "bash",
            "timeout": 10,
            "command": "$HOME/.claude/hooks/morning-ledger-trigger.sh"
          }
        ]
      }
    ]
  }
}
```

The script emits `hookSpecificOutput.additionalContext` — instructions injected
into the session — or nothing at all. It never runs the brief itself; it only
asks for it.

### Path 2 — Scheduled fallback

Runs late afternoon. Its prompt checks the `PUBLISHED` marker first and
hard-stops before reading any state or calling any tool if a brief already went
out. It deliberately does **not** contain the procedure.

---

## State files

| File | Meaning | Written by |
|---|---|---|
| `.morning-ledger-last-run` | The hook fired today | Hook, before emitting |
| `.morning-ledger-published` | A brief was published today | Skill, as its final step |

Both hold a single `YYYY-MM-DD` line. Comparison is a string equality check
against `date +%Y-%m-%d`.

### Failure mode if the publish stamp is dropped

If the skill ever fails to stamp `PUBLISHED` as its last step, the scheduled
fallback will publish a duplicate — and because the fallback runs in degraded
mode, it publishes a *worse* brief over a good one at the same URL. The stamp is
the last line of the procedure for this reason.

---

## Decision framing by clock

The fallback cannot assume it is running after market close. An early misfire
on a market holiday produced a brief framed as a completed session when no
session had occurred.

The run now reads the actual clock and picks framing from it:

| Condition | Framing |
|---|---|
| Past close on a trading day | Completed session |
| Not a trading day | Holiday / weekend mode |
| Before close on a trading day | Mid-session |

---

## Known races

**Concurrent start.** A session opened within a few minutes of the fallback's
scheduled time can start both paths before either stamps `PUBLISHED`.

- Probability: low, requires a narrow window
- Worst case: fallback republishes over the attended brief at the same URL
- Mitigation: none. A lockfile was considered and rejected as more machinery
  than the failure justifies.

---

## Output encoding

Hook output must be pure ASCII. An em-dash round-tripped through the hook pipe
rendered as mojibake in testing and was replaced with a plain hyphen. The pipe
between the hook process and the session does not reliably preserve UTF-8.
