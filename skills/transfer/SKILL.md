---
name: transfer
description: Cross-pollinate knowledge between projects. Scans sibling projects' Prompts/learnings.md (and findings) for insights that generalize beyond one project, and promotes them UP into the global Claude memory so every future session benefits. Use when you want to harvest accumulated project learnings into durable cross-project memory, or to surface relevant global memory into the current project.
argument-hint: [push (default) | pull | <project-path or glob>]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls *), Bash(date *), Bash(find *), Bash(cat *), Bash(head *)
---

# Transfer — Cross-Project Knowledge Promotion

Bridges the two tiers of the user's memory system:

- **Project tier** — `Prompts/learnings.md` and `Prompts/findings/` inside each
  project under `~/Projects/`. Captured by the learn-nudge Stop hook and `/finding`.
- **Global tier** — `~/.claude/projects/-home-vfranke-Utils/memory/*.md` with the
  index `MEMORY.md`. Loaded into context at the start of EVERY session.

The job of `/transfer` is to move **generalizable** project learnings up to the
global tier (push), and optionally surface relevant global memory down into a
project (pull). It never moves project-specific facts up — those stay local.

## Modes

- **push** (default): harvest project learnings → global memory.
- **pull**: list global memories relevant to the current project and offer to
  drop pointers into the project's `Prompts/learnings.md`.
- A path/glob argument scopes the scan (e.g. `~/Projects/AAkalin_Urine`,
  `~/Projects/APombo_*`). Default scope is all of `~/Projects/`.

---

## Mode: push  (default)

### 1. Collect candidate learnings
Find learnings files:
```
find ~/Projects -maxdepth 3 -name learnings.md -path '*/Prompts/*'
```
(restrict to the path/glob argument if given). Read each. Also scan
`Prompts/findings/*.md` only if the user asks to include findings — by default
findings stay project-local (they're evidence, not transferable conventions).

### 2. Classify each learning
For every learning entry, decide: **does this generalize beyond its project?**

PROMOTE (generalizable) — applies to future unrelated work:
- tool / library / environment quirks (R, Python, Guix, conda, samtools, cluster)
- method pitfalls that recur across datasets (a normalization that fails on sparse
  data, a stat test assumption, a file-format gotcha)
- workflow conventions the user reinforces

KEEP LOCAL (project-specific) — do NOT promote:
- facts about one dataset / cohort / sample sheet
- one project's parameter choices or biological results (those are *findings*)
- anything only meaningful with this project's context

When an entry is marked "Beyond this project? yes" trust it as a strong signal,
but still apply judgment.

### 3. Dedup against existing memory
Read `~/.claude/projects/-home-vfranke-Utils/memory/MEMORY.md` and the memory
files. Skip candidates already covered; if a candidate refines an existing
memory, plan an UPDATE to that file rather than a new one.

### 4. Present candidates and get approval
Show a concise numbered list: each candidate's proposed memory `name`, `type`
(`feedback` / `reference` / `project`), one-line description, and source project.
Ask the user which to promote (default: all that are clearly generalizable). Do
NOT write anything until the user confirms. This is an outward, durable change —
confirm first.

### 5. Write approved memories
For each approved candidate, follow the global memory format exactly:
- Create `~/.claude/projects/-home-vfranke-Utils/memory/<slug>.md` with frontmatter
  (`name`, `description`, `metadata.type`). For `feedback`/`project` types, follow
  the body with **Why:** and **How to apply:** lines. Link related memories with
  `[[other-slug]]`.
- Add a one-line pointer to `MEMORY.md` under the right heading
  (`- [Title](file.md) — hook`).
- Prefer updating an existing file over creating a near-duplicate.

### 6. Mark as transferred (light touch)
In each source `Prompts/learnings.md`, append ` (→ global memory: <slug>)` to the
promoted entry so it isn't re-promoted next run. Do not delete the local entry.

### 7. Report
Summarize: N scanned, M promoted (with slugs), K updated, and which were kept
local and why.

---

## Mode: pull

1. Determine the current project (cwd must contain `Prompts/`; else ask which).
2. Read global `MEMORY.md` + memory files; select those relevant to this
   project's domain/stack (infer from `research_plan.md` / `CLAUDE.md`).
3. Present the relevant memories. On approval, add a short
   "## Relevant global memory" pointer block near the top of the project's
   `Prompts/learnings.md` (links by slug + one-line hook) — pointers only, do not
   copy memory bodies into the project.

---

## Guardrails
- Treat every write to the global memory dir as durable and outward-facing —
  confirm the batch with the user before writing.
- Never fabricate a learning to fill the list; if nothing generalizes, say so.
- Keep global memories atomic (one fact per file), per the memory conventions.
