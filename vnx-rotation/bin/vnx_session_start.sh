#!/usr/bin/env bash
# SessionStart hook (fires on startup|resume|clear|compact|fork). Touches a
# marker the rotator waits on, and injects the newest fresh handover as
# additionalContext so the cleared session resumes with full task awareness.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/vnx_common.sh"

input="$(cat)"
vnx_enabled || exit 0

# Signal the rotator that a clear happened.
touch "$VNX_STATE/sessionstart.last" 2>/dev/null || true

# Find the newest handover pointer whose target is still fresh.
best=""; best_ptr=""; bestt=0
now="$(vnx_now)"
for ptr in "$VNX_STATE"/*.handover; do
    [ -f "$ptr" ] || continue
    hf="$(cat "$ptr" 2>/dev/null)"
    [ -n "$hf" ] && [ -f "$hf" ] || continue
    m="$(vnx_mtime "$hf")"
    [ $(( now - m )) -lt "$VNX_TTL" ] || continue
    if [ "$m" -gt "$bestt" ]; then bestt="$m"; best="$hf"; best_ptr="$ptr"; fi
done
[ -n "$best" ] || exit 0

# Consume the pointer so we don't re-inject on later restarts.
rm -f "$best_ptr" 2>/dev/null || true
vnx_log session_start "inject handover $best"

VNX_C="$(cat "$best")" python3 - <<'PY'
import json, os
ctx = ("A context rotation just occurred. The following handover describes the "
       "work in progress — resume from it:\n\n" + os.environ["VNX_C"])
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ctx,
}}))
PY
exit 0
