# vnx_common.sh — shared paths/helpers for context rotation. Sourced, not run.
VNX_DIR="${VNX_DIR:-$HOME/.claude/vnx-rotation}"
VNX_BIN="$VNX_DIR/bin"
VNX_STATE="$VNX_DIR/state"
VNX_HANDOVERS="$VNX_DIR/handovers"
VNX_LOCKS="$VNX_DIR/locks"
VNX_LOG="$VNX_STATE/rotation.log"
VNX_THRESHOLD="${VNX_ROTATION_THRESHOLD:-55}"   # % context-used at which to rotate
VNX_TTL="${VNX_ROTATION_TTL:-300}"              # seconds: lock/handover freshness

# Enabled unless env explicitly disables. On if ENABLED file present OR env==1.
vnx_enabled() {
    [ "${VNX_CONTEXT_ROTATION_ENABLED:-}" = "0" ] && return 1
    [ -f "$VNX_DIR/ENABLED" ] || [ "${VNX_CONTEXT_ROTATION_ENABLED:-}" = "1" ]
}

vnx_log() {
    # vnx_log <component> <message>
    mkdir -p "$VNX_STATE" 2>/dev/null || true
    printf '%s [%s] %s\n' "$(date '+%F %T')" "${1:-?}" "${2:-}" >>"$VNX_LOG" 2>/dev/null || true
}

vnx_mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }
vnx_now()   { date +%s; }
