#!/usr/bin/env bash
# Detached rotator. Clears the Claude pane and pastes a continuation prompt.
# Args: <session_id> <handover_file>
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/vnx_common.sh"

sid="${1:-default}"
hfile="${2:-}"

cleanup() { rm -rf "$VNX_LOCKS/${sid}.lock" 2>/dev/null || true; }
trap cleanup EXIT

# Resolve the tmux pane the statusline captured for this session.
pane=""
for key in "$sid" default; do
    f="$VNX_STATE/$key.env"
    if [ -f "$f" ]; then . "$f"; pane="${PANE:-}"; [ -n "$pane" ] && break; fi
done
if [ -z "$pane" ]; then
    vnx_log rotate "no tmux pane for sid=$sid — cannot auto-clear, aborting"
    exit 0
fi

# Let the just-ended turn settle, then clear. Record a baseline so we can
# detect the SessionStart that /clear produces.
sleep 1
t0="$(vnx_now)"
vnx_log rotate "sending /clear to pane=$pane sid=$sid"
tmux send-keys -t "$pane" "/clear" Enter 2>>"$VNX_LOG" || {
    vnx_log rotate "send-keys /clear failed (pane gone?)"; exit 0;
}

# Wait up to 15s for SessionStart hook to signal the clear completed.
marker="$VNX_STATE/sessionstart.last"
seen=0
for _ in $(seq 1 30); do
    if [ -f "$marker" ] && [ "$(vnx_mtime "$marker")" -ge "$t0" ]; then seen=1; break; fi
    sleep 0.5
done
[ "$seen" = 1 ] || vnx_log rotate "SessionStart marker not seen in 15s; proceeding"
sleep 1

# Best-effort skill reactivation (state is lost on /clear).
skill=""
if [ -n "$hfile" ] && [ -f "$hfile" ]; then
    skill="$(grep -iE '^\*\*Active-Skill\*\*:' "$hfile" 2>/dev/null | head -1 \
            | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]')"
fi
case "$skill" in ""|none|None|NONE|n/a|N/A|'<none>'|'<the') skill="" ;; esac
if [ -n "$skill" ]; then
    vnx_log rotate "reactivating skill /$skill"
    tmux send-keys -t "$pane" "/$skill" Enter 2>>"$VNX_LOG" || true
    sleep 2
fi

# Paste the continuation prompt (load-buffer avoids send-keys escaping issues).
cont="Resume the previous task. A rotation handover from the prior context has been injected into this fresh session: it lists Completed Work, Remaining Tasks, and Next Steps for Incoming Context. Continue from 'Next Steps' and finish the remaining tasks. Do not repeat work already marked completed."
buf="$(mktemp)"
printf '%s' "$cont" >"$buf"
tmux load-buffer -b vnx_rot "$buf" 2>>"$VNX_LOG" || true
tmux paste-buffer -b vnx_rot -t "$pane" 2>>"$VNX_LOG" || true
tmux send-keys -t "$pane" Enter 2>>"$VNX_LOG" || true
tmux delete-buffer -b vnx_rot 2>/dev/null || true
rm -f "$buf"

vnx_log rotate "continuation submitted sid=$sid — rotation complete"

# Opportunistic cleanup so handovers/log don't grow unbounded.
bash "$DIR/vnx_prune.sh" >/dev/null 2>&1 || true
exit 0
