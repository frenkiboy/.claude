#!/usr/bin/env bash
# Bound runtime growth: keep the newest VNX_KEEP_HANDOVERS handover docs and
# cap rotation.log at VNX_LOG_MAXLINES. Best-effort; safe to run anytime.
# Called manually (`vnx prune`) and opportunistically by the rotator.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/vnx_common.sh"

pruned=0

# --- Handover docs: keep newest N (ledger.jsonl is never a handover). --------
if [ -d "$VNX_HANDOVERS" ]; then
    mapfile -t _hs < <(find "$VNX_HANDOVERS" -maxdepth 1 -type f -name '*.md' -printf '%T@\t%p\n' 2>/dev/null \
                       | sort -rn | cut -f2-)
    i=0
    for f in "${_hs[@]}"; do
        i=$((i+1))
        [ "$i" -le "$VNX_KEEP_HANDOVERS" ] && continue
        rm -f "$f" 2>/dev/null && pruned=$((pruned+1))
    done
fi

# --- Stale pane claims: a rotation that never resumed leaves a claim behind. --
if [ -d "$VNX_STATE" ]; then
    now="$(vnx_now)"
    for pc in "$VNX_STATE"/pane-*.handover; do
        [ -f "$pc" ] || continue
        [ $(( now - $(vnx_mtime "$pc") )) -ge "$VNX_TTL" ] && rm -f "$pc" 2>/dev/null
    done
fi

# --- Deny-once markers: drop them for sessions with no sensor file (dead). ---
if [ -d "$VNX_STATE" ]; then
    for m in "$VNX_STATE"/*.handover_requested; do
        [ -f "$m" ] || continue
        sid="$(basename "$m" .handover_requested)"
        [ -f "$VNX_STATE/${sid}.env" ] || rm -f "$m" 2>/dev/null
    done
fi

# --- rotation.log: keep the last N lines. ------------------------------------
if [ -f "$VNX_LOG" ]; then
    lines="$(wc -l < "$VNX_LOG" 2>/dev/null || echo 0)"
    if [ "$lines" -gt "$VNX_LOG_MAXLINES" ] 2>/dev/null; then
        tmp="$VNX_LOG.$$"
        if tail -n "$VNX_LOG_MAXLINES" "$VNX_LOG" > "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$VNX_LOG" 2>/dev/null || rm -f "$tmp"
        fi
    fi
fi

[ "$pruned" -gt 0 ] && vnx_log prune "removed $pruned old handover(s), kept $VNX_KEEP_HANDOVERS"
exit 0
