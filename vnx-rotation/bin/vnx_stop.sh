#!/usr/bin/env bash
# Stop hook. If a rotation is pending for this session, acquire a lock and
# launch the detached rotator. Runs only when the agent is idle, so /clear
# lands cleanly at the prompt.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/vnx_common.sh"

input="$(cat)"
vnx_enabled || exit 0

sid="$(VNX_J="$input" python3 - <<'PY'
import json, os
try: d = json.loads(os.environ["VNX_J"])
except Exception: d = {}
print(d.get("session_id") or "default")
PY
)"
[ -n "$sid" ] || sid=default

# Pinned session: suppress rotation (leave any pending flag for later — the
# context gate below will re-validate it once the pin is removed).
if vnx_pinned "$sid"; then
    vnx_log stop "session pinned sid=$sid — rotation suppressed"; exit 0
fi

pend="$VNX_STATE/${sid}.pending"
[ -f "$pend" ] || exit 0
hfile="$(cat "$pend" 2>/dev/null)"

# --- Final sanity gates: re-check reality at the moment of rotation. ---------
# A pending flag only says "a rotation was requested"; these confirm it is
# actually warranted before we take the irreversible /clear. Either gate
# failing clears the pending and aborts (no rotation, no lost work).

# Gate 1: the handover must be a genuine, structured handover doc.
if [ -z "$hfile" ] || [ ! -f "$hfile" ]; then
    vnx_log stop "pending but handover missing ($hfile) — abort, clear pending"; rm -f "$pend"; exit 0
fi
IFS= read -r first_line < "$hfile" 2>/dev/null || first_line=""
if [ "$first_line" != "# ROTATION-HANDOVER" ] || ! grep -q "Next Steps" "$hfile" 2>/dev/null; then
    vnx_log stop "handover failed validation ($hfile) — abort, clear pending"; rm -f "$pend"; exit 0
fi

# Gate 2: context must STILL be at/above threshold right now. A stale or
# mistakenly-set pending must never clear a low-context session (this is the
# backstop that would have caught both earlier false-trigger bugs).
pct=""
for key in "$sid" default; do
    f="$VNX_STATE/$key.env"
    if [ -f "$f" ]; then . "$f"; pct="${PCT:-}"; [ -n "$pct" ] && break; fi
done
pcti="${pct%.*}"
if [ -z "$pcti" ] || ! [ "$pcti" -ge "$VNX_THRESHOLD" ] 2>/dev/null; then
    vnx_log stop "context ${pcti:-?}% < ${VNX_THRESHOLD}% at Stop — refuse rotate, clear pending"; rm -f "$pend"; exit 0
fi

# Atomic lock (mkdir); honour a fresh lock, steal a stale one.
lock="$VNX_LOCKS/${sid}.lock"
mkdir -p "$VNX_LOCKS" 2>/dev/null || true
if ! mkdir "$lock" 2>/dev/null; then
    age=$(( $(vnx_now) - $(vnx_mtime "$lock") ))
    if [ "$age" -lt "$VNX_TTL" ]; then
        vnx_log stop "lock held sid=$sid, skip"; exit 0
    fi
    rm -rf "$lock"; mkdir "$lock" 2>/dev/null || exit 0
fi

rm -f "$pend"
vnx_log stop "launch rotator sid=$sid hfile=$hfile"
nohup bash "$DIR/vnx_rotate.sh" "$sid" "$hfile" >>"$VNX_LOG" 2>&1 &
exit 0
