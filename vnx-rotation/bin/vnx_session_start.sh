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

VNX_J="$input" VNX_HFILE="$best" VNX_LEDGER="$VNX_HANDOVERS/ledger.jsonl" python3 - <<'PY'
import json, os, re, hashlib, datetime

hfile = os.environ["VNX_HFILE"]
with open(hfile, "rb") as f:
    raw = f.read()
content = raw.decode("utf-8", "replace")

# Primary job: inject the handover as additional context (stdout = hook output).
ctx = ("A context rotation just occurred. The following handover describes the "
       "work in progress — resume from it:\n\n" + content)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ctx,
}}))

# Provenance ledger: one line per resume, linking origin -> new session, with a
# content hash so a later edit/clobber of the handover is detectable. Best
# effort — a failure here must never break context injection.
try:
    def field(name):
        m = re.search(r"(?mi)^\*\*%s\*\*:\s*(.+?)\s*$" % re.escape(name), content)
        return m.group(1).strip() if m else None
    def num(name):
        v = field(name)
        return int(re.sub(r"[^0-9]", "", v)) if v and re.search(r"\d", v) else None
    try:
        d = json.loads(os.environ.get("VNX_J") or "{}")
    except Exception:
        d = {}
    rec = {
        "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "from_sid": field("Session-ID") or os.path.basename(hfile)[:-3],
        "to_sid": d.get("session_id") or "",
        "handover": hfile,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "context_pct": num("Context-Used"),
        "threshold": num("Threshold"),
        "created_at": field("Created-At"),
        "status": "resumed",
    }
    with open(os.environ["VNX_LEDGER"], "a") as lf:
        lf.write(json.dumps(rec) + "\n")
except Exception:
    pass
PY
exit 0
