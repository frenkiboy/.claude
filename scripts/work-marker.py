#!/usr/bin/env python3
"""
PostToolUse hook (matcher "Edit|Write|Bash"): record that *substantive work*
happened in this session, so the learn-nudge Stop hook can tell a working
session apart from a read-only / chat-only one.

Marks by touching ./Prompts/Logs/.work-<sid8> in the project working dir.

Marks when:
  - tool is Edit or Write (any file change is work), OR
  - tool is Bash and the command looks like a script run
    (same signature the RUN_LOG hook uses).

Skipped when:
  - the cwd has no ./Prompts/ directory (not a research project)

Silent on stdout (never injects context, never blocks).
"""
import json, sys, os, re

# Same script-run signature as the RUN_LOG PostToolUse hook in
# project-settings-template.json — keep the two in sync.
RUN_RE = re.compile(
    r"\b(Rscript|R45|python3?|ipython|snakemake|make)\b"
    r"|\b(bash|sh) +[^ ]+\.(sh|bash)\b"
    r"|\./[^ ]+\.(sh|R|r|py|Rmd)\b"
)

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cwd = d.get("cwd") or os.getcwd()
prompts_dir = os.path.join(cwd, "Prompts")
if not os.path.isdir(prompts_dir):
    sys.exit(0)

tool = d.get("tool_name", "")
ti = d.get("tool_input") or {}

is_work = False
if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
    is_work = True
elif tool == "Bash":
    cmd = ti.get("command", "") or ""
    is_work = bool(RUN_RE.search(cmd))

if not is_work:
    sys.exit(0)

logs_dir = os.path.join(prompts_dir, "Logs")
os.makedirs(logs_dir, exist_ok=True)
sid = (d.get("session_id") or "nosession")[:8]
marker = os.path.join(logs_dir, f".work-{sid}")
try:
    # touch (create or update mtime)
    open(marker, "a").close()
    os.utime(marker, None)
except OSError:
    pass

sys.exit(0)
