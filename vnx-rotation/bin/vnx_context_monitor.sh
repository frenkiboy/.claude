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

# Deny ONCE per session. We force a handover the first time a session crosses
# the threshold, then never block it again. Otherwise, if the user keeps sending
# messages before the /clear fires, every turn is denied and the agent re-writes
# the handover with no progress — a livelock. One handover is the safety net;
# the rotation still happens whenever the agent next goes idle (Stop hook), or
# the user can /clear manually. The marker is keyed by sid, so it's gone after a
# /clear (fresh sid) and blocking correctly arms again for the next session.
req="$VNX_STATE/${sid}.handover_requested"
[ -f "$req" ] && exit 0
# Belt-and-suspenders: if a handover file already exists for this sid (marker
# lost, or detector tagged it), treat the rotation as in flight and don't block.
[ -f "$VNX_HANDOVERS/${sid}.md" ] && exit 0

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

This block fires ONCE per session: after the handover is written you will not be blocked again, so if more messages arrive before the rotation fires, just continue the work normally. If it still has not rotated, tell the user they can run /clear to rotate immediately."

# Mark that we've forced a handover for this session, so we never block it again.
touch "$req" 2>/dev/null || true
vnx_log monitor "deny ${pcti}% tool=$tool sid=$sid -> expect $hpath (deny-once armed)"

VNX_R="$reason" python3 - <<'PY'
import json, os
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": os.environ["VNX_R"],
}}))
PY
exit 0
