# Automatic context rotation for Claude Code

Adapted from https://vincentvandeth.nl/blog/context-rot-claude-code-automatic-rotation

When context-used crosses a threshold (default **65%**), the agent is forced to
write a handover document, the session is automatically `/clear`-ed, and the
fresh session resumes with the handover injected — so work continues with a full
context budget but no lost state.

## Why this differs from the blog

The blog reads a `remaining_pct` field from the PreToolUse hook. **That field
does not exist** — no Claude Code hook receives context-window usage. The real
signal is only available to the **status line**. So here the status line is the
sensor: it mirrors `context_window.used_percentage` (and the live `$TMUX_PANE`)
to a state file that the hooks poll. Two other changes:

- Pane resolution uses `$TMUX_PANE` captured by the status line — no guessing.
- `/clear` is launched from the **Stop** hook (agent idle), not mid-turn, which
  avoids the worst of the keystroke race the blog warns about.

## Pieces

| File | Role |
|------|------|
| `~/.claude/statusline.sh` (sensor block) | writes `state/<sid>.env` = PCT, PANE, TS |
| `bin/vnx_context_monitor.sh` | **PreToolUse** — at ≥threshold, denies non-write tools and demands a handover |
| `bin/vnx_handover_detector.sh` | **PostToolUse** — marks rotation pending when a file with `ROTATION-HANDOVER` is written |
| `bin/vnx_stop.sh` | **Stop** — when idle + pending, locks and launches the rotator |
| `bin/vnx_rotate.sh` | detached — `tmux send-keys /clear`, waits for SessionStart, pastes continuation |
| `bin/vnx_session_start.sh` | **SessionStart** — injects newest fresh handover as `additionalContext` |
| `bin/vnx_common.sh` | shared paths / enable check / logging |

Hooks are registered in `~/.claude/settings.json`.

## Enable / disable

- **On:** `touch ~/.claude/vnx-rotation/ENABLED`  (present by default)
- **Off:** `rm ~/.claude/vnx-rotation/ENABLED`  (every component no-ops instantly)
- Env override: `VNX_CONTEXT_ROTATION_ENABLED=0` forces off, `=1` forces on.

## Tuning (env vars, set before launching `claude`)

- `VNX_ROTATION_THRESHOLD` — percent to rotate at (default `65`)
- `VNX_ROTATION_TTL` — seconds for lock/handover freshness (default `300`)

## Operational notes / limitations

- **Requires tmux.** If the status line didn't capture a pane, the rotator logs
  and aborts (no auto-clear) — the handover is still written and injected on your
  next manual `/clear`.
- ~1–2s tmux timing race remains possible right after `/clear`.
- Active skill state is lost on `/clear`; the rotator re-runs `/<skill>` if the
  handover has an `**Active-Skill**:` line (else skips).
- Multi-terminal: state is keyed by `session_id`; a `default.env` fallback exists
  for the rare case the hook's session id hasn't been seen by the status line yet.
- Debug log: `state/rotation.log`.

## Uninstall

Run `bin/uninstall.sh` (removes hooks from settings.json and the sensor block
from statusline.sh; leaves this directory in place — delete it manually if you
want it gone).
