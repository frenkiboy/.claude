# Automatic context rotation for Claude Code

Adapted from https://vincentvandeth.nl/blog/context-rot-claude-code-automatic-rotation

When context-used crosses a threshold (default **45%**), the agent is forced to
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
| `bin/vnx_handover_detector.sh` | **PostToolUse** — marks rotation pending only for a genuine handover (file **inside `handovers/`** whose first line is `# ROTATION-HANDOVER`) |
| `bin/vnx_stop.sh` | **Stop** — when idle + pending, re-checks the handover is valid **and context is still ≥ threshold**, then locks and launches the rotator |
| `bin/vnx_rotate.sh` | detached — `tmux send-keys /clear`, waits for SessionStart, pastes continuation |
| `bin/vnx_session_start.sh` | **SessionStart** — injects newest fresh handover as `additionalContext` and appends a provenance line to `handovers/ledger.jsonl` |
| `bin/vnx_common.sh` | shared paths / enable check / pin check / logging |
| `bin/vnx` | CLI: `status`, `selftest`, `prune`, `pin`/`unpin`, `log` (symlinked to `~/bin/vnx`) |
| `bin/vnx_selftest.sh` | dry-runs the full pipeline in isolation (no real pane); PASS/FAIL per stage |
| `bin/vnx_prune.sh` | retention: keep newest N handovers, cap the log |

Hooks are registered in `~/.claude/settings.json`.

## Inspecting & controlling (`vnx`)

`vnx` is on your `PATH` (symlink in `~/bin`). From a terminal — or `! vnx …`
inside a Claude prompt:

```
vnx status      # armed?, current context %, rotation chain, orphans
vnx selftest    # exercise deny -> detect -> gates -> inject -> ledger; PASS/FAIL
vnx prune       # enforce retention now
vnx pin         # suppress rotation for THIS session (matched by $TMUX_PANE)
vnx unpin       # lift the pin
vnx log [n]     # tail the rotation log
```

Run `vnx selftest` after editing any hook — it confirms the whole pipeline is
healthy without touching your real pane. A **pin** is the safety valve for
delicate work: `state/<sid>.pin` makes both the monitor (no forced handover) and
the Stop hook (no `/clear`) skip that one session until you `vnx unpin`.

## Enable / disable

- **On:** `touch ~/.claude/vnx-rotation/ENABLED`  (present by default)
- **Off:** `rm ~/.claude/vnx-rotation/ENABLED`  (every component no-ops instantly)
- Env override: `VNX_CONTEXT_ROTATION_ENABLED=0` forces off, `=1` forces on.

## Tuning (env vars, set before launching `claude`)

- `VNX_ROTATION_THRESHOLD` — percent to rotate at (default `45`)
- `VNX_ROTATION_TTL` — seconds for lock/handover freshness (default `300`)
- `VNX_KEEP_HANDOVERS` — handover docs to retain when pruning (default `50`)
- `VNX_LOG_MAXLINES` — `rotation.log` line cap when pruning (default `2000`)

## Safety gates (why a false rotation can't `/clear` you)

A pending flag only *requests* a rotation; the Stop hook confirms it before the
irreversible `/clear`:

1. The handover must be a real structured doc (first line `# ROTATION-HANDOVER`,
   has a Next Steps section).
2. Context must **still** be ≥ threshold right now — a stale or mis-set flag on a
   low-context session is refused and cleared.

The detector is likewise scoped: it only reacts to files **inside `handovers/`**
whose first line is the marker, so docs/memory that merely mention the marker in
prose can't trigger a rotation.

## Multiple sessions at once

Nothing is keyed by project folder — everything is keyed by **session id**, so
two Claude sessions in the same folder never collide: each has its own
`handovers/<sid>.md`, `<sid>.pending`, and `<sid>.lock`, and its `/clear` goes
to its own captured pane. Session ids are unique per rotation (a `/clear` yields
a fresh id), so handover docs are never clobbered across rotations.

Which handover a resumed session injects is decided **by tmux pane**, not by
"newest": the rotator records `state/pane-<pane>.handover → <file>` before the
`/clear`, and `SessionStart` reads its own `$TMUX_PANE` and injects exactly that
claim. So even if several sessions rotate within the same TTL window, each pane
resumes with its *own* handover — no swapping. Without a pane match (non-tmux, or
a failed clear) it falls back to newest-wins among handovers **not** claimed by
any pane. Stale claims (a rotation whose `/clear` never resumed) expire after the
TTL and are swept by `vnx prune`.

## Provenance

Each resume appends one JSON line to `handovers/ledger.jsonl`:

```json
{"ts":"…","from_sid":"…","to_sid":"…","handover":"handovers/<sid>.md",
 "sha256":"…","context_pct":66,"threshold":55,"created_at":"…","status":"resumed"}
```

- `from_sid → to_sid` reconstructs the full rotation chain across sessions.
- `sha256` is the hash of the exact injected content — re-hash the file later to
  detect any edit/clobber.
- A handover file on disk with **no** matching `resumed` ledger line is an orphan
  (rotation launched but the session never came back).

Handover docs are keyed by session id (`handovers/<sid>.md`) and never deleted,
so they accumulate; `handovers/`, `state/`, `locks/`, and `ENABLED` are
git-ignored (per-machine runtime, not version-controlled).

## Operational notes / limitations

- **Requires tmux.** If the status line didn't capture a pane, the rotator logs
  and aborts (no auto-clear) — the handover is still written and injected on your
  next manual `/clear`.
- ~1–2s tmux timing race remains possible right after `/clear`.
- **Deny-once (no livelock).** The monitor blocks and demands a handover only the
  FIRST time a session crosses the threshold (it drops a `state/<sid>.handover_requested`
  marker). After that the session is never blocked again, so sending another
  message before the `/clear` fires lets the work continue instead of looping on
  re-written handovers. The rotation still fires when the agent next goes idle;
  if it hasn't, `/clear` manually. The marker is per-sid, so blocking re-arms for
  the fresh session after a rotation.
- Active skill state is lost on `/clear`; the rotator re-runs `/<skill>` if the
  handover has an `**Active-Skill**:` line (else skips).
- Multi-terminal: state is keyed by `session_id`; a `default.env` fallback exists
  for the rare case the hook's session id hasn't been seen by the status line yet.
- Debug log: `state/rotation.log`.

## Uninstall

Run `bin/uninstall.sh` (removes hooks from settings.json and the sensor block
from statusline.sh; leaves this directory in place — delete it manually if you
want it gone).
