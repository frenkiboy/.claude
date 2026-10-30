#!/usr/bin/env bash
# Dry-run the whole rotation pipeline against an isolated SELFTEST session, with
# NO real tmux pane (so nothing is ever cleared). Prints PASS/FAIL per stage;
# exits non-zero if any stage fails. Run after editing any hook.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/vnx_common.sh"

# Force-enable for the duration regardless of the ENABLED toggle.
export VNX_CONTEXT_ROTATION_ENABLED=1
SID="SELFTEST-$$"
HF="$VNX_HANDOVERS/${SID}.md"
PFAKE="%VNXST$$"                                             # unique fake pane
PFKEY="$(printf '%s' "$PFAKE" | tr -c 'A-Za-z0-9' '_')"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }

cleanup() {
    rm -f "$VNX_HANDOVERS/${SID}"*.md "$VNX_STATE/${SID}."* 2>/dev/null
    rm -f "$VNX_STATE"/pane-*STA"$$".handover "$VNX_STATE"/pane-*STB"$$".handover 2>/dev/null
    rm -f "$VNX_STATE/pane-${PFKEY}.handover" 2>/dev/null
    rm -rf "$VNX_LOCKS/${SID}.lock" 2>/dev/null
    # Drop the SELFTEST line(s) this run appended to the ledger. grep -v exits 1
    # when it removes every line (empty result) — that is success here, so accept
    # exit 0 or 1 and only bail on a real error (>=2).
    if [ -f "$VNX_HANDOVERS/ledger.jsonl" ]; then
        tmp="$VNX_HANDOVERS/ledger.jsonl.$$"
        grep -v "$SID" "$VNX_HANDOVERS/ledger.jsonl" > "$tmp" 2>/dev/null; rc=$?
        if [ "$rc" -le 1 ]; then mv -f "$tmp" "$VNX_HANDOVERS/ledger.jsonl" 2>/dev/null || rm -f "$tmp"
        else rm -f "$tmp"; fi
    fi
}
trap cleanup EXIT

mkdir -p "$VNX_STATE" "$VNX_HANDOVERS" "$VNX_LOCKS" 2>/dev/null || true
inp() { printf '{"session_id":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$SID" "${1:-}" "${2:-}"; }
set_pct() { printf 'PCT=%s\nPANE=%s\nTS=1\n' "$1" "$PFAKE" > "$VNX_STATE/${SID}.env"; }

echo "vnx self-test (sid=$SID, no real pane)"

# 1. Monitor denies a non-write tool at high context.
set_pct 90
out="$(inp Bash | bash "$DIR/vnx_context_monitor.sh" 2>/dev/null)"
echo "$out" | grep -q '"permissionDecision": "deny"' && ok "monitor denies at 90%" || bad "monitor should deny at 90%"

# 1b. Deny-once: a second over-threshold turn is allowed (no livelock).
rm -f "$VNX_STATE/${SID}.handover_requested"
set_pct 90
o1="$(inp Bash | bash "$DIR/vnx_context_monitor.sh" 2>/dev/null)"
o2="$(inp Bash | bash "$DIR/vnx_context_monitor.sh" 2>/dev/null)"
if echo "$o1" | grep -q '"permissionDecision": "deny"' && [ -z "$o2" ]; then
    ok "deny-once then bypass (no re-block loop)"
else
    bad "deny-once bypass failed (o1 deny / o2 empty expected)"
fi
rm -f "$VNX_STATE/${SID}.handover_requested" "$VNX_HANDOVERS/${SID}.md"

# 2. Monitor allows when below threshold.
set_pct 10
rm -f "$VNX_STATE/${SID}.handover_requested"
out="$(inp Bash | bash "$DIR/vnx_context_monitor.sh" 2>/dev/null)"
[ -z "$out" ] && ok "monitor allows at 10%" || bad "monitor should allow at 10%"

# 3. Monitor respects a pin even at high context.
set_pct 90; touch "$VNX_STATE/${SID}.pin"
out="$(inp Bash | bash "$DIR/vnx_context_monitor.sh" 2>/dev/null)"
[ -z "$out" ] && ok "monitor honors pin" || bad "monitor should honor pin"
rm -f "$VNX_STATE/${SID}.pin"

# 4. Detector ignores a marker-bearing file OUTSIDE handovers/.
decoy="$VNX_STATE/${SID}.decoy.md"; printf '# ROTATION-HANDOVER\nNext Steps\n' > "$decoy"
inp Write "$decoy" | bash "$DIR/vnx_handover_detector.sh" 2>/dev/null
[ ! -f "$VNX_STATE/${SID}.pending" ] && ok "detector ignores file outside handovers/" || bad "detector should ignore decoy"
rm -f "$decoy" "$VNX_STATE/${SID}.pending" "$VNX_STATE/${SID}.handover"

# 5. Detector ignores a handovers/ file whose marker isn't the first line.
printf 'notes\n# ROTATION-HANDOVER\n## Next Steps\n' > "$HF"
inp Write "$HF" | bash "$DIR/vnx_handover_detector.sh" 2>/dev/null
[ ! -f "$VNX_STATE/${SID}.pending" ] && ok "detector requires anchored marker" || bad "detector matched non-anchored marker"
rm -f "$VNX_STATE/${SID}.pending" "$VNX_STATE/${SID}.handover"

# 6. Detector accepts a genuine handover.
cat > "$HF" <<EOF
# ROTATION-HANDOVER
**Session-ID**: ${SID}
**Context-Used**: 66%
**Created-At**: 2026-01-01T00:00:00Z
**Threshold**: 55%
**Active-Skill**: none

## Completed Work
- x
## Next Steps for Incoming Context
1. y
EOF
inp Write "$HF" | bash "$DIR/vnx_handover_detector.sh" 2>/dev/null
[ -f "$VNX_STATE/${SID}.pending" ] && ok "detector accepts genuine handover" || bad "detector missed genuine handover"

# 7. Stop gate refuses when context is low.
set_pct 10
printf '%s' "$HF" > "$VNX_STATE/${SID}.pending"
inp | bash "$DIR/vnx_stop.sh" 2>/dev/null
[ ! -f "$VNX_STATE/${SID}.pending" ] && ok "stop refuses rotation at 10% (pending cleared)" || bad "stop should refuse at 10%"

# 8. Stop proceeds at high context (pane=none -> rotator aborts harmlessly).
set_pct 90
printf '%s' "$HF" > "$VNX_STATE/${SID}.pending"
inp | bash "$DIR/vnx_stop.sh" 2>/dev/null
sleep 1
[ ! -f "$VNX_STATE/${SID}.pending" ] && ok "stop passes gates at 90% (rotator launched)" || bad "stop blocked a valid rotation"
rm -rf "$VNX_LOCKS/${SID}.lock"
rm -f "$VNX_STATE/pane-${PFKEY}.handover"   # drop the claim its failed /clear left

# 9. Stop suppresses rotation for a pinned session.
set_pct 90; touch "$VNX_STATE/${SID}.pin"
printf '%s' "$HF" > "$VNX_STATE/${SID}.pending"
inp | bash "$DIR/vnx_stop.sh" 2>/dev/null
[ -f "$VNX_STATE/${SID}.pending" ] && ok "stop honors pin (pending preserved)" || bad "stop ignored pin"
rm -f "$VNX_STATE/${SID}.pin" "$VNX_STATE/${SID}.pending"

# 10. SessionStart injects the handover and writes a provenance ledger line.
printf '%s' "$HF" > "$VNX_STATE/${SID}.handover"; touch "$HF"
out="$(printf '{"session_id":"%s-NEW"}' "$SID" | bash "$DIR/vnx_session_start.sh" 2>/dev/null)"
echo "$out" | python3 -c 'import sys,json; json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]' >/dev/null 2>&1 \
    && ok "session_start emits valid injection JSON" || bad "session_start injection JSON invalid"
if [ -f "$VNX_HANDOVERS/ledger.jsonl" ] && grep -q "\"${SID}-NEW\"" "$VNX_HANDOVERS/ledger.jsonl"; then
    ok "provenance ledger line written (to_sid recorded)"
else
    bad "provenance ledger line missing"
fi

# 11. Concurrent rotations route by pane (no swap between two sessions).
hA="$VNX_HANDOVERS/${SID}-A.md"; hB="$VNX_HANDOVERS/${SID}-B.md"
printf '# ROTATION-HANDOVER\n**Session-ID**: %s-A\n**Context-Used**: 50%%\n**Threshold**: 45%%\n## Next Steps for Incoming Context\n1. AAA\n' "$SID" > "$hA"
printf '# ROTATION-HANDOVER\n**Session-ID**: %s-B\n**Context-Used**: 50%%\n**Threshold**: 45%%\n## Next Steps for Incoming Context\n1. BBB\n' "$SID" > "$hB"
paneA='%STA'"$$"; paneB='%STB'"$$"
keyA="$(printf '%s' "$paneA" | tr -c 'A-Za-z0-9' '_')"; keyB="$(printf '%s' "$paneB" | tr -c 'A-Za-z0-9' '_')"
printf '%s' "$hA" > "$VNX_STATE/pane-${keyA}.handover"
printf '%s' "$hB" > "$VNX_STATE/pane-${keyB}.handover"
outA="$(printf '{"session_id":"%s-rA"}' "$SID" | TMUX_PANE="$paneA" bash "$DIR/vnx_session_start.sh" 2>/dev/null)"
outB="$(printf '{"session_id":"%s-rB"}' "$SID" | TMUX_PANE="$paneB" bash "$DIR/vnx_session_start.sh" 2>/dev/null)"
if echo "$outA" | grep -q "${SID}-A" && ! echo "$outA" | grep -q "${SID}-B" \
   && echo "$outB" | grep -q "${SID}-B" && ! echo "$outB" | grep -q "${SID}-A"; then
    ok "concurrent: each pane injects its own handover (no swap)"
else
    bad "concurrent rotations crossed handovers"
fi

echo "----"
echo "vnx self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
