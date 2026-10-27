#!/usr/bin/env bash
# Remove the context-rotation hooks from settings.json and the sensor block
# from statusline.sh. Idempotent. Does not delete the vnx-rotation directory.
set -euo pipefail
SETTINGS="$HOME/.claude/settings.json"
STATUSLINE="$HOME/.claude/statusline.sh"

# 1) Drop our four hook entries from settings.json (match by command path).
python3 - "$SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
hooks = d.get("hooks", {})
def strip(event):
    arr = hooks.get(event)
    if not isinstance(arr, list): return
    kept = []
    for grp in arr:
        grp.setdefault("hooks", [])
        grp["hooks"] = [h for h in grp["hooks"]
                        if "vnx-rotation/bin/" not in (h.get("command") or "")]
        if grp["hooks"]:
            kept.append(grp)
    if kept: hooks[event] = kept
    else: hooks.pop(event, None)
for e in ("PreToolUse", "PostToolUse", "Stop", "SessionStart"):
    strip(e)
d["hooks"] = hooks
json.dump(d, open(p, "w"), indent=2)
open(p, "a").write("\n")
print("settings.json: vnx hooks removed")
PY

# 2) Remove the sensor block from statusline.sh (between the marker comments).
if grep -q 'VNX context-rotation sensor' "$STATUSLINE" 2>/dev/null; then
    python3 - "$STATUSLINE" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n# --- VNX context-rotation sensor.*?\n\} 2>/dev/null \|\| true\n",
           "\n", s, flags=re.S)
open(p, "w").write(s)
print("statusline.sh: sensor block removed")
PY
else
    echo "statusline.sh: no sensor block found"
fi

# 3) Remove the vnx CLI symlink if it points back into this install.
VNXLINK="$HOME/bin/vnx"
if [ -L "$VNXLINK" ] && readlink "$VNXLINK" 2>/dev/null | grep -q 'vnx-rotation/bin/vnx'; then
    rm -f "$VNXLINK" && echo "~/bin/vnx symlink removed"
fi

echo "Done. Restart Claude Code to reload settings."
