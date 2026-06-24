#!/usr/bin/env python3
"""
Stop hook: a SOFT, one-time nudge to capture a learning before the session ends.

If substantive work happened this session (a .work-<sid8> marker exists, dropped
by work-marker.py) but Prompts/learnings.md was not touched since that work, this
hook asks Claude — exactly once — to consider recording a one-line learning.

Design goals (per user choice "soft nudge"):
  - Never forces an entry. Claude is told NOT to fabricate; if nothing is worth
    keeping it should just stop again.
  - Fires at most once per session: it clears the marker before nudging, and the
    second Stop (stop_hook_active=True) is always allowed through. No loops.
  - Stays out of the way of read-only / chat-only sessions (no marker => silent).

Stop hooks can only surface text to Claude by blocking once, so this blocks a
single time with an explicitly-optional reason, then lets the session end.

Skipped when:
  - stop_hook_active is true (we already nudged this stop cycle)
  - the cwd has no ./Prompts/ directory
  - no .work-<sid8> marker (no substantive work this session)
  - learnings.md was modified at/after the work marker (already reflected)
"""
import json, sys, os, time

NUDGE_REASON = (
    "Optional, one-time learning check (you may decline and stop again):\n"
    "This session did substantive work but Prompts/learnings.md wasn't updated.\n"
    "If you hit a non-obvious gotcha, surprise, dead-end, or hard-won insight "
    "worth the next session, append ONE concise entry to Prompts/learnings.md "
    "using its entry format. If it's broadly useful beyond this project, note "
    "that so it can later be promoted with /transfer.\n"
    "Do NOT invent a learning — if nothing is genuinely worth keeping, just stop."
)


def sweep_stale(logs_dir, keep_days=7):
    """Remove orphaned markers from crashed sessions."""
    cutoff = time.time() - keep_days * 86400
    try:
        for name in os.listdir(logs_dir):
            if name.startswith(".work-"):
                p = os.path.join(logs_dir, name)
                try:
                    if os.path.getmtime(p) < cutoff:
                        os.remove(p)
                except OSError:
                    pass
    except OSError:
        pass


def allow():
    sys.exit(0)


def main():
    try:
        d = json.load(sys.stdin)
    except Exception:
        allow()

    if d.get("stop_hook_active"):
        allow()

    cwd = d.get("cwd") or os.getcwd()
    prompts_dir = os.path.join(cwd, "Prompts")
    if not os.path.isdir(prompts_dir):
        allow()

    logs_dir = os.path.join(prompts_dir, "Logs")
    sweep_stale(logs_dir)

    sid = (d.get("session_id") or "nosession")[:8]
    marker = os.path.join(logs_dir, f".work-{sid}")
    if not os.path.exists(marker):
        allow()  # no substantive work this session

    learnings = os.path.join(prompts_dir, "learnings.md")
    try:
        work_t = os.path.getmtime(marker)
    except OSError:
        allow()

    if os.path.exists(learnings):
        try:
            if os.path.getmtime(learnings) >= work_t:
                # already captured a learning after the work happened
                try:
                    os.remove(marker)
                except OSError:
                    pass
                allow()
        except OSError:
            pass

    # Clear the marker now so we never nudge twice for this session, even if
    # Claude declines to record anything.
    try:
        os.remove(marker)
    except OSError:
        pass

    print(json.dumps({"decision": "block", "reason": NUDGE_REASON}))
    sys.exit(0)


if __name__ == "__main__":
    main()
