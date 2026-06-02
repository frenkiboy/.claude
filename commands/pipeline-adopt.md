---
description: Retrofit an existing project into the prompt-driven canvas pipeline. Audits current state, backfills missing scaffolding, reverse-engineers canvases from existing reports, wires backlinks, reconciles implementation.md.
argument-hint: [optional: --dry-run | report-number-to-start-from]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(mkdir:*), Bash(cp:*), Bash(date:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git diff:*), Bash(find:*), Bash(wc:*), Agent]
---

# Adopt the Prompt-Driven Pipeline

You take a working analysis project that **doesn't yet have the canvas / implementation.md / PIPELINE.md infrastructure** and bring it into the prompt-driven flow. After this runs, the project is ready for `/plan-convert` → `/grill-me` → `/plan-exec` on future work, and existing work is back-linked through canvases.

This is the inverse of `/research-setup`: that command scaffolds a *new* project; this one retrofits an *existing* one without breaking anything.

If `$ARGUMENTS` is `--dry-run`: do all the auditing and proposing, but make zero file edits and zero commits. Useful for "show me what would change".

---

## Phase 1: Audit current state

Build a checklist of what's present vs missing. Launch 2-3 Explore agents in parallel to cover:

- **Folder structure**: `Scripts/{Bin,Reports}`, `Results/`, `Data/` (symlink?), `Documentation/`, `Prompts/canvases/`, `Prompts/Logs/`
- **Key files**: `CLAUDE.md`, `PIPELINE.md`, `Prompts/research_plan.md`, `Prompts/implementation.md` (or legacy `Prompts/implementation_plan.md`), `Prompts/dependencies.json`, `Scripts/INDEX.md`, `CHANGELOG.md`
- **Hooks**: `.claude/settings.json` with `UserPromptSubmit` (PROMPT_LOG) and `PostToolUse` (RUN_LOG) hooks
- **Existing artifacts**: count `Scripts/Reports/*.Rmd`, list `Scripts/Bin/*.{R,py,sh}`, count figures in `Results/`

Present a single tabular report:

    | Component                              | Status   | Action |
    |----------------------------------------|----------|--------|
    | Scripts/Reports/ (N reports)           | present  | reverse-engineer canvases |
    | Prompts/canvases/                      | missing  | create + backfill |
    | CLAUDE.md                              | present  | check vs template, ask |
    | PIPELINE.md                            | missing  | scaffold from template |
    | Prompts/implementation.md              | missing  | scaffold + populate from reports |
    | Prompts/implementation_plan.md         | present  | migrate to implementation.md |
    | .claude/settings.json (hooks)          | missing  | install |
    | Prompts/dependencies.json              | missing  | scaffold skeleton |
    | Scripts/INDEX.md                       | missing  | scaffold + populate |

Ask user to confirm before proceeding to Phase 2.

---

## Phase 2: Backfill scaffolding

For each missing piece, create with conservative defaults. Show the user a one-line summary per action:

1. **Folders**: `mkdir -p` any missing dirs from the standard layout.
2. **CLAUDE.md**: if absent, write the template from `~/.claude/skills/research-setup/SKILL.md` (CLAUDE.md TEMPLATE section), substituting `<project_name>` from the directory name, `<home_folder>` from `pwd`, and asking user for `<data_folder>`. If present, **do not overwrite** — diff against template and surface differences as suggestions.
3. **PIPELINE.md**: if absent, write the template (PIPELINE.md TEMPLATE section). If present, leave alone.
4. **Prompts/implementation.md**: if absent, seed with three section headers (`## Todo`, `## In progress`, `## Done`) and a one-line preface.
5. **Prompts/implementation_plan.md** (legacy): if present alongside the new file, leave both — `/plan-review` handles fallback. If present and the new file is absent, migrate:
   - Each `[x]` item from the legacy file → `## Done` in the new file
   - Each `[ ]` item → `## Todo`
   - Carry over phase context as `[phase: N]` markers
   - Keep the legacy file untouched (don't delete; rename to `.legacy.md` for clarity)
6. **Hooks**: if `.claude/settings.json` doesn't exist or lacks the two hooks, copy `~/.claude/scripts/project-settings-template.json` into `.claude/settings.json`. If a settings file exists, MERGE the `hooks` block in rather than overwriting.
7. **Prompts/dependencies.json**: if absent, write `{"nodes": [], "edges": []}` skeleton.
8. **Scripts/INDEX.md**: if absent, write the header row only (`| Path | Lang | Purpose | Inputs | Outputs | Upstream | Downstream |` plus separator). Phase 3 will populate.
9. **Prompts/canvases/.gitkeep**: ensure exists.
10. **CHANGELOG.md**: if absent, write `# <project> CHANGELOG` header plus a dated "Adopted prompt-driven pipeline" entry.

If `--dry-run`: skip all writes. Report what would happen.

---

## Phase 3: Reverse-engineer canvases (interactive, one per turn)

For each `Scripts/Reports/NN_*.Rmd` (in order; resume from `$ARGUMENTS` if it's a number):

1. Launch an Explore agent to read the report and any `Scripts/Bin/` files it sources, plus the figures it produces under `Results/<report>/`.
2. Draft a canvas at `Prompts/canvases/NNN_slug.md` (use the report's `NN` prefix; generate slug from filename):

       ---
       id: NNN
       slug: <kebab-case from filename>
       created: <today YYYY-MM-DD>
       source_prompt_log: (retrofit — pre-pipeline)
       implementation_md_item: "<one-line summary>"
       status: done
       ---

       # Question
       <Inferred from report title, intro paragraph, or section headers. If unclear, mark "TBD — confirm with user".>

       # Entities
       <Data files, sample sheets, helpers referenced. Pull from YAML `inputs:` block, `source()` calls, `library()` loads, and any path strings in chunk code.>

       # Approach
       <Methods inferred from package calls + key parameters. Be concrete: cite the DE function used, normalization method, statistical test, thresholds. Mark "TBD" anywhere parameters are unclear from code.>

       # Structure
       - **Upstream**: <data files + any other report this depends on, inferred from inputs>
       - **Downstream**: (filled in Phase 4)
       - **Lives in**: `Scripts/Reports/NN_<name>.Rmd`

       # Operations
       1. <chunk-by-chunk summary, 5-10 steps>
       2. ...

       # Safeguards
       - <Any QC chunks, oracle comparisons, control checks found in the report>
       - Done = <figures listed in Results/<report>/ exist and report knits without error>

3. Show the draft to the user. Options: `accept | refine <note> | skip | stop`.
   - `accept`: write the file, move on.
   - `refine <note>`: address the note, re-show.
   - `skip`: mark this report as un-canvased (record in the final summary so it can be revisited).
   - `stop`: jump to Phase 4 with whatever's been done.
4. Add `# Canvas: Prompts/canvases/NNN_slug.md` to the .Rmd header (top YAML or comment block) if not already present. Don't touch the rest of the file.
5. Append an item to `Prompts/implementation.md` `## Done`:

       - [x] <one-line summary> [phase: retrofit] → Prompts/canvases/NNN_slug.md

Also walk `Scripts/Bin/*.{R,py,sh}` files that look like top-level analysis scripts (not pure helper utilities). For each, decide:
- If it's clearly a transformation called by an existing report → no canvas needed; it's covered by the report's canvas
- If it's standalone analysis (e.g. produces its own Results/ figures) → propose a canvas the same way

While walking Bin/, also classify each file's **mode** (dual-mode is the standard — see CLAUDE.md "Bin/ vs Reports/" section):

- **dual-mode** ✓ — defines a top-level function AND has a CLI shim (`if (sys.nframe() == 0)` in R, `if __name__ == "__main__":` in Python, `main()` pattern in bash). Nothing to do.
- **function-only** — has the function definition but no CLI shim. Cannot be invoked by Snakemake / cron / `RUN_LOG`. Flag in Phase 8 summary as `SINGLE_MODE_FN_ONLY`.
- **script-only** — runs top-level (no function wrapper). Cannot be `source()`'d cleanly by reports. Flag as `SINGLE_MODE_SCRIPT_ONLY`.

Do **not** auto-refactor here — that's intrusive code editing on a retrofit pass. Report only; the user can opt into refactor per-file later via `/plan-convert` on a "make X dual-mode" Todo.

---

## Phase 4: Cross-link canvases (Structure section)

Walk every canvas just written. For each one, infer Downstream references from the upstream pointers of *other* canvases:

- Canvas A's Upstream contains "from `02_Normalization`"? Then canvas for `02_Normalization` gets canvas A added under Downstream.

Edit each canvas's Structure section in place to fill the Downstream bullet. Don't touch any other section.

---

## Phase 5: Reconcile against research_plan.md

If `Prompts/research_plan.md` exists, read its `Scientific Questions` and `Planned Analyses` sections. Cross-reference against the canvases just created:

- Any question / planned analysis with **no corresponding canvas** → add a fresh item to `## Todo` in `implementation.md`, marked `[source: research_plan retrofit]`.
- Any **canvas not traceable** to any planned analysis → flag in the final summary (might indicate scope drift or missing research_plan updates).

---

## Phase 6: Populate Scripts/INDEX.md and dependencies.json

For each script under `Scripts/Bin/` and `Scripts/Reports/`:
- Add a row to `Scripts/INDEX.md` with as much detail as can be inferred from the file header (or "TBD" where unclear).

For `Prompts/dependencies.json`:
- Add a `data` node per raw input file referenced in any canvas's Entities, with `sha256` computed via `sha256sum`.
- Add a `report` node per report.
- Add `figure` nodes for each PDF under `Results/`.
- Build `edges` from each canvas's Upstream/Downstream graph.

This is the heaviest single write. If the project has many scripts, ask whether to do a light pass (file paths only) or full pass (with content hashes).

---

## Phase 7: Commit

Single commit with all migration work:

    chore: adopt prompt-driven canvas pipeline

    - Scaffold: CLAUDE.md, PIPELINE.md, Prompts/{implementation.md, dependencies.json,
      canvases/, Logs/}, .claude/settings.json, Scripts/INDEX.md, CHANGELOG.md
    - Backfill canvases for N existing reports (status: done)
    - Wire # Canvas: headers in N reports
    - Populate implementation.md ## Done with retrofit items; ## Todo with unimplemented
      research_plan items

    Backfilled: Prompts/canvases/001_<slug>.md
    Backfilled: Prompts/canvases/002_<slug>.md
    ...

`Backfilled:` trailers (one per canvas) — distinguish from `Implements:` (used when code is *generated from* a canvas).

If `--dry-run`: skip the commit; print what would be committed.

---

## Phase 8: Verify and suggest next step

Run a mental `/plan-review` pass:
- Every report has a canvas? ✓ / ✗
- Every canvas's YAML `status:` matches its `implementation.md` section? ✓ / ✗
- `dependencies.json` validates as JSON?
- All `# Canvas:` headers in code point to existing canvas files?
- Bin/ mode summary: count of dual-mode ✓ / function-only / script-only (from Phase 3 walk)

Report the audit. If clean, suggest:
- `/plan-review` for a fresh audit
- `/plan-convert next` if any `## Todo` items exist (new work from research_plan retrofit)
- `/grill-me Prompts/canvases/NNN_*.md` on any canvas where Approach contains `TBD`
- For each `SINGLE_MODE_*` file flagged in Phase 3: suggest adding a Todo item like `make Scripts/Bin/<name> dual-mode (add CLI shim / function wrapper)` — small refactor, runs through `/plan-convert` → `/plan-exec` like any other task.

If anything failed validation, list the specific files that need attention.

---

## Anti-patterns

- **Don't overwrite an existing CLAUDE.md or PIPELINE.md** without showing a diff and asking
- **Don't delete `implementation_plan.md`** even after migrating — keep as `.legacy.md` for reference
- **Don't fabricate** Approach parameters where the code is genuinely unclear — write `TBD` and let `/grill-me` resolve them later
- **Don't touch figure captions** during this command — caption editing is user-visible churn; let the user opt in separately
- **Don't auto-rename existing reports or scripts** to fit conventions — only add headers and backlinks
- **Don't process more than one canvas per turn** in Phase 3 — the user needs to see and accept each
- **Don't commit unless Phase 8 validation passes** — if any check fails, surface and ask whether to commit with caveats or fix first
