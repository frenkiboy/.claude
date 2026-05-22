---
description: Verify provenance — recompute sha256 hashes in dependencies.json, validate canvas/script backlinks, detect drift between static metadata and filesystem state.
argument-hint: [--fix-hashes]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(find:*), Bash(sha256sum:*), Bash(stat:*), Bash(wc:*), Bash(date:*), Bash(jq:*), Bash(python3:*), Bash(test:*)]
---

# Dependencies Check — Provenance Integrity Audit

Walk the static-side metadata (`Prompts/dependencies.json` + canvas Upstream/Downstream graph + `# Canvas:` headers in code) and verify it matches filesystem reality. Surfaces silent-failure modes:

- Raw data files quietly overwritten upstream (sha256 drift)
- Canvas YAML status out of sync with `implementation.md` section
- Code citing a canvas that doesn't exist
- Canvases referencing upstream canvases that don't exist
- Figures declared in dependencies.json but never rendered

Read-only by default. `--fix-hashes` is the only flag that writes — and it only touches `Prompts/dependencies.json` to update drifted `sha256` values for files that **do** exist (it never invents hashes for missing files).

---

## Phase 1: Parse dependencies.json

1. Read `Prompts/dependencies.json`. If missing, tell the user "no `dependencies.json` — nothing to check; consider initializing one (or running `/pipeline-adopt`)" and stop.
2. Parse as JSON. If malformed, surface the parse error with line number and stop.
3. Expect schema:
   - `nodes`: array of `{id, type, path}` with optional `sha256` (mandatory on `data` nodes)
   - `edges`: array of `{from, to}` using node ids
4. Build two lookup tables: `nodes_by_id` and `nodes_by_path`. Detect duplicate ids → fail fast.

---

## Phase 2: Data-node hash & existence check

For each node where `type == "data"`:

1. **File exists?** `test -f <path>`. If not, record as `MISSING`.
2. **Has `sha256` field?** If not, record as `UNHASHED`.
3. **Hash matches?** Compute `sha256sum <path>` and compare to the recorded value. Record as `MATCH` / `DRIFT`.
4. **File empty?** `stat -c %s <path>` == 0 → record as `EMPTY` (often indicates a botched copy).

Collect counts: matched, drifted, missing, unhashed, empty.

---

## Phase 3: Report/figure-node existence check

For each node where `type in {"report", "figure"}`:

1. **File exists?** If not, record as `MISSING`. (Figures may legitimately not exist yet if the report hasn't been rendered — surface as a warning, not an error.)
2. For `report` nodes: also read the file's header and confirm there's a `# Canvas: Prompts/canvases/NNN_*.md` line. Missing → record as `NO_CANVAS_HEADER`.

---

## Phase 4: Canvas backlinks in code

Independent of dependencies.json — scan the codebase directly.

1. Glob `Scripts/Bin/*.{R,py,sh}` and `Scripts/Reports/*.{Rmd,qmd,R,py}`.
2. For each file: grep first 30 lines for `# Canvas:\s*(Prompts/canvases/\S+\.md)`.
3. For each cited canvas path: verify it exists. Missing → record as `DANGLING_CANVAS_REF`.
4. Files with no `# Canvas:` header at all → record as `UNANCHORED` (separate from drift; informational, not a failure — Bin/ utility files may legitimately have no canvas).

---

## Phase 5: Canvas DAG integrity

1. Glob `Prompts/canvases/*.md`.
2. For each canvas: parse the YAML frontmatter (`id`, `slug`, `status`) and the `# Structure` section's Upstream / Downstream bullet lists.
3. Cross-reference:
   - Each Upstream reference points to a canvas that exists → if not, `MISSING_UPSTREAM`
   - Each Downstream reference points to a canvas that exists → if not, `MISSING_DOWNSTREAM`
   - For each Upstream `A → B`, the reverse Downstream `B → A` should also exist → if not, `ASYMMETRIC_EDGE`
4. Check `status` vs `implementation.md` section placement:
   - Canvas `status: todo` but item under `## In progress` or `## Done` → `STATUS_DRIFT`
   - Canvas `status: in_progress` but item under `## Todo` or `## Done` → `STATUS_DRIFT`
   - Canvas `status: done` but item under `## Todo` or `## In progress` → `STATUS_DRIFT`
5. Optional cycle detection (use a topological sort on the edge list). Cycle found → `CYCLE`. (Rare in practice; skip if it adds complexity.)

---

## Phase 6: Render the report

Single structured output. Group by category, surface failures first:

    Dependencies check — <YYYY-MM-DD HH:MM>

    ✗ Hash drift (2):
      Data/counts.csv         sha256: a3f5e1… → 9c1284…
      Data/samples.tsv        sha256: bc4a92… → file empty (0 bytes)

    ✗ Missing files (1):
      Data/refs.fa            declared in dependencies.json, not on disk

    ✗ Dangling canvas refs (1):
      Scripts/Reports/03_DE.Rmd cites canvases/007_de.md — does not exist

    ⚠ Status drift (1):
      canvases/004_norm.md status:in_progress, but implementation.md has it under ## Done

    ⚠ Missing figures (3):
      Results/03_DE/260520_Volcano_treated_vs_ctrl.pdf — not rendered yet
      Results/03_DE/260520_MA_treated_vs_ctrl.pdf — not rendered yet
      Results/03_DE/260520_Heatmap_top50.pdf — not rendered yet

    ⚠ Unanchored scripts (2):
      Scripts/Bin/io_helpers.R       no # Canvas: header (utility — ok)
      Scripts/Bin/parse_samplesheet.R no # Canvas: header (utility — ok)

    ✓ Clear (18):
      data hashes match (8), reports tracked (4), figures present (6)

    Summary: 4 failures, 6 warnings, 18 clear

Failures vs warnings:
- **Failures** (`✗`): block trust in downstream results until resolved (hash drift, missing input file, dangling canvas ref)
- **Warnings** (`⚠`): not always actionable (missing figures may just mean "not rendered yet"; unanchored utility scripts are fine)

---

## Phase 7: Optional fix-hashes pass

Only if `$ARGUMENTS == "--fix-hashes"`:

1. For each `data` node where hash drifted **and** file exists **and** file is non-empty:
   - Recompute `sha256sum <path>`
   - Update the node's `sha256` field in `Prompts/dependencies.json` in place
2. Do **not** touch:
   - `MISSING` nodes (file doesn't exist — no hash to compute)
   - `EMPTY` nodes (0-byte file is suspicious — flag for human review)
   - `UNHASHED` nodes that have no sha256 field at all (let the user decide whether to backfill or remove the node)
3. Print a one-line confirmation per updated node:

       updated: Data/counts.csv  a3f5e1… → 9c1284…

4. Stage and commit only `Prompts/dependencies.json` with message:

       chore: refresh data-node hashes (N drifted)

5. Do **not** auto-fix any other category (canvas refs, status drift, etc.) — those need human judgment.

---

## Phase 8: Exit status & suggested next step

- All clear → "Provenance clean. Safe to proceed with downstream analyses."
- Warnings only → "Provenance clean; warnings noted but not blocking."
- Failures present (no --fix-hashes) → "**Provenance broken** — N failures. Investigate before trusting downstream results. Run `/deps-check --fix-hashes` if drift is from a known intentional input update."
- Failures present (after --fix-hashes) → "Hash drift resolved. Remaining failures (M) need manual attention: <list>."

---

## Anti-patterns

- **Don't fix anything beyond data-node hashes automatically.** Canvas DAG drift, status mismatches, missing files — all need human judgment. Auto-fixing would silently rewrite intent.
- **Don't recompute hashes for `EMPTY` files.** A 0-byte file is almost always a bug; recording it as the "new hash" hides the failure.
- **Don't recurse forever on canvas Upstream/Downstream.** Single hop is enough — multi-hop graph traversal is what `/plan-review` would do.
- **Don't fail noisily on missing `dependencies.json`.** It's optional for very early-stage projects. Just say "nothing to check" and stop.
- **Don't commit on a no-op `--fix-hashes` run.** If nothing actually drifted, no commit.
