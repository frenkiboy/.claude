#!/usr/bin/env bash
# PreToolUse hook. At >= threshold context-used, denies non-write tools and
# instructs the agent to write a ROTATION-HANDOVER document first.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/vnx_common.sh"

input="$(cat)"
vnx_enabled || exit 0

# Parse session_id + tool_name in one shot.
IFS=$'\t' read -r sid tool < <(VNX_J="$input" python3 - <<'PY'
import json, os
try: d = json.loads(os.environ["VNX_J"])
except Exception: d = {}
print((d.get("session_id") or "default") + "\t" + (d.get("tool_name") or ""))
PY
)
[ -n "$sid" ] || sid=default

# Pinned session: never interrupt it to force a handover.
vnx_pinned "$sid" && exit 0

# Current context-used % written by the statusline sensor.
pct=""
for key in "$sid" default; do
    f="$VNX_STATE/$key.env"
    if [ -f "$f" ]; then . "$f"; pct="${PCT:-}"; [ -n "$pct" ] && break; fi
done
[ -n "$pct" ] || exit 0
pcti="${pct%.*}"
[ "$pcti" -ge "$VNX_THRESHOLD" ] 2>/dev/null || exit 0

# Loop prevention: always let handover-writing / read tools through.
case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit|Read|TodoWrite) exit 0 ;;
esac

# Bounded nudging. Blocking forever livelocks (the user keeps messaging before
# the /clear fires); blocking exactly once gives rotation a single shot at the
# race. So nudge up to VNX_MAX_NUDGES times, each at least VNX_NUDGE_COOLDOWN
# seconds apart, then fail open. Each nudge forces a handover + idle = one more
# rotation attempt; the cooldown lets the current work finish (and the rotation
# fire) without re-blocking the very next message. Counter is per-sid, so it's
# gone after a /clear (fresh sid) and nudging re-arms for the next session.
df="$VNX_STATE/${sid}.deny"
dcount=0; dlast=0
[ -f "$df" ] && read -r dcount dlast < "$df" 2>/dev/null
[ -n "$dcount" ] || dcount=0; [ -n "$dlast" ] || dlast=0
nowt="$(vnx_now)"
[ "$dcount" -ge "$VNX_MAX_NUDGES" ] 2>/dev/null && exit 0          # nudged enough → fail open
[ $(( nowt - dlast )) -lt "$VNX_NUDGE_COOLDOWN" ] 2>/dev/null && exit 0  # within cooldown → let it run

hpath="$VNX_HANDOVERS/${sid}.md"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
reason="CONTEXT ROTATION TRIGGERED at ${pcti}% (threshold ${VNX_THRESHOLD}%). Before any more tool calls, STOP and write a rotation handover with the Write tool to exactly: ${hpath}

The file MUST begin with the literal marker line and follow this structure:

# ROTATION-HANDOVER
**Session-ID**: ${sid}
**Context-Used**: ${pcti}%
**Created-At**: ${created_at}
**Threshold**: ${VNX_THRESHOLD}%
**Active-Skill**: <the /skill currently active, or none>

## Completed Work
- <specific finished items>

## Remaining Tasks
- <specific unfinished items>

## Next Steps for Incoming Context
1. <concrete next action: exact file paths, PIDs, ports, commands>

After you write this file and end your turn, the session will AUTOMATICALLY clear and resume with this handover injected. Be concrete — vague handovers lose work. Write the file now, then stop.

The system nudges at most ${VNX_MAX_NUDGES} times per session (this is nudge $((dcount + 1))), spaced out, then stops blocking — you will not be stuck in a loop. After you write the handover and end your turn the rotation fires on idle; if more messages arrive first, just continue the work. If it still has not rotated, tell the user they can run /clear to rotate immediately."

# Record this nudge (count + timestamp) so we bound retries and honour cooldown.
printf '%s %s' "$((dcount + 1))" "$nowt" > "$df" 2>/dev/null || true
vnx_log monitor "deny ${pcti}% tool=$tool sid=$sid nudge=$((dcount + 1))/${VNX_MAX_NUDGES}"

VNX_R="$reason" python3 - <<'PY'
import json, os
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": os.environ["VNX_R"],
}}))
PY
exit 0
