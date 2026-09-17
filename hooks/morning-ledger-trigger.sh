#!/usr/bin/env bash
# Morning Ledger daily trigger.
#
# Runs on SessionStart. Emits the "run the brief" instruction ONLY on the first
# Claude session of each calendar day; every later session that day stays silent.
# The datestamp marker is what makes this safe regardless of whether SessionStart
# also fires on resume, /clear, or compaction.
#
# Wired up in ~/.claude/settings.json under hooks.SessionStart.
# To disable: remove that hooks block, or delete this file.
# To force a re-run today: rm ~/.claude/.morning-ledger-last-run

set -u

FIRED="$HOME/.claude/.morning-ledger-last-run"
PUBLISHED="$HOME/.claude/.morning-ledger-published"
TODAY="$(date +%Y-%m-%d)"

# Already fired today -> stay silent (don't nag across repeated sessions).
if [ -f "$FIRED" ] && [ "$(cat "$FIRED" 2>/dev/null)" = "$TODAY" ]; then
  exit 0
fi

# A brief was already published today (e.g. by the scheduled fallback) -> stay
# silent. This is what stops the hook and the fallback both publishing.
if [ -f "$PUBLISHED" ] && [ "$(cat "$PUBLISHED" 2>/dev/null)" = "$TODAY" ]; then
  exit 0
fi

# Stamp BEFORE emitting, so a failure downstream can't cause a repeat loop.
printf '%s\n' "$TODAY" > "$FIRED" 2>/dev/null || exit 0

DOW="$(date +%A)"

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"DAILY MORNING LEDGER TRIGGER - first session of $DOW $TODAY.\n\nThe Morning Ledger has not run yet today. Run it now by invoking the 'morning-ledger' skill with the Skill tool, which carries the full procedure. If that skill name does not resolve for any reason, do NOT improvise the brief - read the procedure directly from \$HOME/.claude/skills/morning-ledger/SKILL.md and follow it.\n\nThis is an ATTENDED run (the user is present), so interactive browser tools should connect - use them for the live sources rather than falling back to degraded ones.\n\nOne exception: if the user's first message is clearly about something else, handle that first and offer the Ledger in a single line instead of running it unprompted."},"systemMessage":"Morning Ledger - first session of $TODAY. Triggering the daily brief."}
EOF

exit 0
