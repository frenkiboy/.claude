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

# Choose the handover to inject. Primary: the claim for THIS tmux pane — the
# deterministic match when several sessions rotate at once. Fallback (no pane,
# or no claim for it): newest-wins among handovers NOT claimed by any pane, so
# fallback can never steal a handover meant for another pane.
best=""; best_ptr=""; pane_claim=""
now="$(vnx_now)"
fresh() { [ -f "$1" ] && [ $(( now - $(vnx_mtime "$1") )) -lt "$VNX_TTL" ]; }

if [ -n "${TMUX_PANE:-}" ]; then
    pkey="$(printf '%s' "$TMUX_PANE" | tr -c 'A-Za-z0-9' '_')"
    pc="$VNX_STATE/pane-${pkey}.handover"
    if fresh "$pc"; then
        hf="$(cat "$pc" 2>/dev/null)"
        if [ -n "$hf" ] && fresh "$hf"; then best="$hf"; pane_claim="$pc"; fi
    fi
fi

if [ -z "$best" ]; then
    # Handover files currently claimed by some (fresh) pane — off-limits here.
    claimed=""
    for pc in "$VNX_STATE"/pane-*.handover; do
        fresh "$pc" || continue
        cf="$(cat "$pc" 2>/dev/null)"; [ -n "$cf" ] && claimed="${claimed}|${cf}|"
    done
    bestt=0
    for ptr in "$VNX_STATE"/*.handover; do
        [ -f "$ptr" ] || continue
        case "$ptr" in "$VNX_STATE"/pane-*) continue ;; esac   # skip pane claims
        hf="$(cat "$ptr" 2>/dev/null)"
        [ -n "$hf" ] && fresh "$hf" || continue
        case "$claimed" in *"|${hf}|"*) continue ;; esac       # skip pane-claimed
        m="$(vnx_mtime "$hf")"
        if [ "$m" -gt "$bestt" ]; then bestt="$m"; best="$hf"; best_ptr="$ptr"; fi
    done
fi
[ -n "$best" ] || exit 0

# Consume every pointer that could re-inject this handover: the pane claim, the
# per-sid pointer (filename is <sid>.md), and the fallback pointer if used.
[ -n "$pane_claim" ] && rm -f "$pane_claim" 2>/dev/null || true
rm -f "$VNX_STATE/$(basename "$best" .md).handover" 2>/dev/null || true
[ -n "$best_ptr" ] && rm -f "$best_ptr" 2>/dev/null || true
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
