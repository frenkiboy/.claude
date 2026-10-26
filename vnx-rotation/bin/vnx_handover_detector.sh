#!/usr/bin/env bash
# PostToolUse hook (Write|Edit|MultiEdit|NotebookEdit). Records a pending
# rotation ONLY when the written file is a genuine handover: it must live
# inside $VNX_HANDOVERS *and* begin with the literal "# ROTATION-HANDOVER"
# heading line. Both guards exist because a loose substring match tripped on
# docs/memory that merely *mention* the marker in prose (self-rotation bug).
# The actual /clear is launched later by the Stop hook (agent idle = clean clear).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/vnx_common.sh"

input="$(cat)"
vnx_enabled || exit 0

IFS=$'\t' read -r tool sid fp < <(VNX_J="$input" python3 - <<'PY'
import json, os
try: d = json.loads(os.environ["VNX_J"])
except Exception: d = {}
ti = d.get("tool_input") or {}
fp = ti.get("file_path") or ti.get("path") or ""
print("\t".join([(d.get("tool_name") or ""), (d.get("session_id") or "default"), fp]))
PY
)
[ -n "$sid" ] || sid=default

case "$tool" in Write|Edit|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
[ -n "$fp" ] && [ -f "$fp" ] || exit 0

# Guard 1: the file must physically live inside the handovers directory.
# A genuine handover is always written to $VNX_HANDOVERS/<sid>.md; anything
# elsewhere (memory, docs, the install dir) may mention the marker freely.
rp="$(realpath -- "$fp" 2>/dev/null || echo "$fp")"
hroot="$(realpath -- "$VNX_HANDOVERS" 2>/dev/null || echo "$VNX_HANDOVERS")"
case "$rp" in "$hroot"/*) ;; *) exit 0 ;; esac

# Guard 2: the marker must be the anchored first line ("# ROTATION-HANDOVER"),
# as the monitor's template mandates — not the string buried anywhere in prose.
IFS= read -r first_line < "$fp" 2>/dev/null || exit 0
[ "$first_line" = "# ROTATION-HANDOVER" ] || exit 0

printf '%s' "$fp" > "$VNX_STATE/${sid}.handover"   # for SessionStart injection
printf '%s' "$fp" > "$VNX_STATE/${sid}.pending"    # consumed by Stop hook
vnx_log detector "handover marked sid=$sid file=$fp"
exit 0
