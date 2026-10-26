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

# If a fresh handover already exists, rotation is in-flight — don't keep blocking.
ptr="$VNX_STATE/${sid}.handover"
if [ -f "$ptr" ]; then
    hf="$(cat "$ptr" 2>/dev/null)"
    if [ -n "$hf" ] && [ -f "$hf" ]; then
        age=$(( $(vnx_now) - $(vnx_mtime "$hf") ))
        [ "$age" -lt "$VNX_TTL" ] && exit 0
    fi
fi

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

After you write this file and end your turn, the session will AUTOMATICALLY clear and resume with this handover injected. Be concrete — vague handovers lose work. Write the file now, then stop."

vnx_log monitor "deny ${pcti}% tool=$tool sid=$sid -> expect $hpath"

VNX_R="$reason" python3 - <<'PY'
import json, os
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": os.environ["VNX_R"],
}}))
PY
exit 0
