---
name: research-setup
description: Set up a new bioinformatics research project with standardized folder structure, computing environment (R/Python), cacheR integration, and git repository. Use when starting a new analysis project or when the user asks to scaffold a research project.
argument-hint: [project-name | print]
allowed-tools: Read, Write, Glob, Grep, Bash(mkdir *), Bash(ln *), Bash(git *), Bash(R *), Bash(Rscript *), Bash(pip *), Bash(mamba *), Bash(conda *)
---

# Research Project Setup

## Print Mode

If the argument is `print`, write the `research_plan.md` template to `./Prompts/research_plan.md` AND the CLAUDE.md template (see "CLAUDE.md Template" section below) to `./CLAUDE.md` (create `Prompts/` if needed), then stop.

The research_plan.md template content:

---BEGIN research_plan.md TEMPLATE---
# Research Plan

> For project conventions, folder structure, computing environment, and
> workflow rules, see `CLAUDE.md`. This document is the **scientific
> plan** only — what is being studied and why.

## Project Description

<!-- One paragraph: what this project investigates and why. -->

## Environment Variables

<!-- Project-specific values referenced throughout the codebase. -->

- **project_name**:
- **home_folder**:
- **data_folder**:
- **sample_sheet**:

## Background & Motivation

<!-- Prior work, gap in the literature, biological/clinical context.
     What makes this question worth asking now? -->

## Scientific Questions

<!-- The concrete questions the analyses must answer. One per bullet.
     Order from primary to exploratory. -->

1.
2.
3.

## Data Sources

<!-- For each dataset: accession or path, organism, modality, sample
     count, source publication or grant. Note ownership and any
     embargoes. -->

| Dataset | Modality | Accession / Path | Samples | Source |
|---------|----------|------------------|---------|--------|

## Planned Analyses

<!-- High-level analyses in order. Each becomes one or more reports
     under Scripts/Reports/ and one or more canvases under
     Prompts/canvases/. -->

1.
2.
3.

## Constraints

<!-- The guardrails: what defines a valid result, what must not happen,
     and what every analysis must respect. Treat these as test
     oracles — every report should be checkable against them. -->

### Positive controls

<!-- Things that MUST work / show signal to prove the pipeline is
     functioning. Known true-positives, spike-ins, marker genes whose
     behavior is established. If a positive control fails, halt and
     debug — don't trust downstream results. -->

-

### Negative controls

<!-- Things that should NOT show signal. Null samples, shuffled labels,
     randomized data, regions of the genome with no expected effect.
     If a negative control fires, you have a false-positive source. -->

-

### Workflow constraints

<!-- Non-negotiables on how the analysis must run. Tools/versions to
     use or avoid, ordering dependencies between steps, time/compute
     budgets, reproducibility requirements (seeds, deterministic
     pipelines), data-locality rules. -->

-

### Important variables

<!-- Biological and technical covariates that every analysis must
     track and report on. Batch, donor, sex, age, condition, library
     prep, sequencer, etc. Anything that could confound results if
     ignored. Include the column name in the sample sheet. -->

| Variable | Type | Sample-sheet column | Why it matters |
|----------|------|--------------------|----------------|

## Expected Outputs

<!-- Reports, figures, tables, supplementary materials that this
     project will produce. Tie each to a Scientific Question above. -->

-

## Open Questions / TBD

<!-- Unresolved scientific or methodological decisions. Items here
     should be raised with the user before relevant canvases are
     written. -->

-

---END research_plan.md TEMPLATE---

After writing the file, confirm the path to the user. Do not proceed with project setup.

---

## Setup Mode

Collect the required information from the user, then scaffold the project.

### Required Information

Ask the user to fill in (use `$ARGUMENTS` for project_name if provided):

- **project_name**: e.g., `AAkalin_Urine`
- **project_description**: Brief scientific description
- **home_folder**: Path to project home (code and scripts)
- **data_folder**: Path to data storage (large-volume filesystem)
- **sample_sheet**: Path to sample sheet (if applicable)

### Actions

1. Create the folder structure shown in the template above (including `Prompts/Logs/` and `Prompts/canvases/`)
2. Create `Data/` as a **symlink** to `<data_folder>/<project_name>/Data` (create target if needed)
3. Set up computing environment (R with renv, Python env)
4. Initialize git repository
5. Create `CHANGELOG.md` with project name header and "Project created" entry dated today
6. Write `CLAUDE.md` using the template below
7. Seed `Scripts/INDEX.md` with the header row only: `| Path | Lang | Purpose | Inputs | Outputs | Upstream | Downstream |` plus separator row — no entries yet
8. Seed `Prompts/implementation.md` with three empty sections: `## Todo`, `## In progress`, `## Done` — and a one-line preface explaining that `/triage` populates Todo from `PROMPT_LOG.md`
9. Add a placeholder `Prompts/canvases/.gitkeep` so the empty directory tracks in git
10. Install the project-scoped auto-logging hooks: copy `~/.claude/scripts/project-settings-template.json` to `<home_folder>/.claude/settings.json` (create the `.claude/` directory). This file activates `PROMPT_LOG.md` and `RUN_LOG.md` only when Claude Code runs in this project. If `.claude/settings.json` already exists, MERGE the `hooks` block in rather than overwriting the file.
11. Ask the user to describe the scientific analysis plan

---

## CLAUDE.md Template

When creating `CLAUDE.md` for a new project (both Print Mode and Setup Mode), use this content, substituting `<project_name>`, `<home_folder>`, and `<data_folder>`:

---BEGIN CLAUDE.md TEMPLATE---
# <project_name> — Project Conventions

## Folder Structure

    <home_folder>/
    ├── Scripts/
    │   ├── Bin/          # All functions and executables
    │   └── Reports/      # All R Markdown reports
    ├── Results/          # All figures created by reports
    ├── Data/             # Symlink to <data_folder>/<project_name>/Data
    ├── Documentation/    # Processed data downloaded from publications
    ├── Prompts/
    │   ├── research_plan.md       # High-level plan
    │   ├── implementation.md      # Curated request backlog
    │   ├── canvases/              # Structured prompts, committed with code
    │   └── Logs/
    │       ├── PROMPT_LOG.md      # Auto: every user prompt
    │       └── RUN_LOG.md         # Auto: every script invocation
    └── CHANGELOG.md      # Shared memory across Claude sessions

### Rules

- `Data/` is a **symlink** to `<data_folder>/<project_name>/Data`
- Downloaded data goes in `Data/` with a `README` (source + download date)
- `Documentation/` holds processed data tables from publications
- `Results/<report_name>/` — figure names: `yymmdd_Figure-type_Figure-name.pdf`
- cacheR output: `<data_folder>/<project_name>/Results/cacheR`
- Reports rendered in `./Scripts/Reports`, output in folder `yymmdd_DESCRIPTION`
- All figures numbered; maintain `00_Report` with summary and links to all reports
- Every script in `Scripts/Bin/` carries a header (Purpose/Inputs/Outputs/Upstream/Downstream); listed in `Scripts/INDEX.md`

## Computing Environment

### R
- Use `R45` for the newest R version
- Reproducible environment via `renv`
- Install cacheR from: `/home/vfranke/Projects/VFranke_cacheR/cacheR`

### Python
- Base Python: `/home/vfranke/bin/mamba/miniforge/bin/python`
- Per-project reproducible env via conda/mamba or venv

### Git
- Repository is initialized in `<home_folder>`
- Commits implementing a canvas carry an `Implements:` trailer (see Prompt-Driven Workflow)

## Execution Guidelines

- Wrap expensive functions with cacheR — never re-compute what's already cached
- Reports in `Scripts/Reports/` must be self-contained R Markdown / Quarto / Jupyter
- Shared functions go in `Scripts/Bin/` and are sourced/imported by reports — never copy-paste between reports
- For long-running jobs, log progress to `Prompts/Logs/` not stdout
- Validate against positive/negative controls listed in `Prompts/research_plan.md` before trusting downstream results

## Data Provenance

Always use the **newest results** from upstream steps. Never hardcode dated paths.

- Document upstream dependencies at the top of each Rmd (comment block or YAML header)
- Use `get_latest_cache()` or glob sorted by date to resolve latest cacheR output
- Re-run downstream reports when upstream changes
- Warn if cached outputs are stale relative to upstream report modification time

## Report Input Files

Every `.Rmd` must list **all input files** it consumes near the top (in a YAML `inputs:` block or a "## Inputs" section). For each file:

- **Path**: full or project-relative
- **Type**: raw data, cacheR output, upstream report figure/table, external/published
- **Source**: which report or pipeline produced it (or the publication if external)
- **Used for**: brief reason it's loaded in this report

Update the list when the code changes — stale input documentation is worse than none.

## Figure Documentation

Every figure must have a description (in `fig.cap` or preceding paragraph) covering:
- **Input data**: source, file path, filtering/transformation
- **Method**: functions, parameters, statistical tests, thresholds
- **What it shows**: plain-language interpretation

Keep descriptions in sync with code — update when the generating code changes.

## Code Quality

- Read files before editing; prefer editing over creating new files
- Fail fast with clear, actionable error messages (operation, input, suggested fix)
- Never commit secrets, credentials, or .env files
- Follow `/karpathy-guidelines`: think first, simplicity first, surgical changes, goal-driven execution

## Session Orientation

1. Read `CHANGELOG.md` for status, next steps, and blockers
2. Pick the next task
3. Update `CHANGELOG.md` before stopping

## CHANGELOG.md as Shared Memory

- Update after every meaningful unit of work
- Check off completed items with dates
- **Record failed approaches** so they aren't re-attempted
- Note blockers and newly discovered tasks

## Oracle Testing

Validate against established tools. When results disagree, bisect upstream to find divergence. Never add fudge factors — find the bug.

## Context Window Hygiene

- Print summaries, not full data frames
- Log verbose diagnostics to `Prompts/Logs/`, not stdout
- Use `head()` / summary views, never dump entire tables

## Analysis Dependencies

Maintain `Prompts/dependencies.json` — a DAG tracking data flow from inputs to figures:

    {
      "nodes": [
        {"id": "raw_counts", "type": "data",   "path": "Data/counts.csv"},
        {"id": "norm_report", "type": "report", "path": "Scripts/Reports/01_Normalization.Rmd"},
        {"id": "fig_pca",     "type": "figure", "path": "Results/01_Normalization/260420_PCA_samples.pdf"}
      ],
      "edges": [
        {"from": "raw_counts",  "to": "norm_report"},
        {"from": "norm_report", "to": "fig_pca"}
      ]
    }

Update when adding/modifying analysis steps. When upstream changes, re-run downstream and update prose.

## Script Tracking

Mixed-language projects (bash + R + Python) become opaque without a consistent script manifest. Two mechanisms — one automated, one by convention.

### `Prompts/Logs/RUN_LOG.md` (automated)

A global PostToolUse hook auto-appends every Bash script invocation (Rscript, python, snakemake, bash *.sh, ./*.{R,py,sh,Rmd}, etc.) to this file. **Never edit manually** — it's an append-only execution trace. At session start, read the tail to see what last ran. If the file doesn't exist yet, it'll be created the first time a matching command runs.

### `Scripts/INDEX.md` (by hand)

Maintain a one-row-per-script table covering everything in `Scripts/Bin/` and `Scripts/Reports/`:

| Path | Lang | Purpose | Inputs | Outputs | Upstream | Downstream |
|------|------|---------|--------|---------|----------|------------|

Update whenever a script is added, renamed, or repurposed. Stale rows are worse than no index.

### Script header convention

Every script in `Scripts/Bin/` (and the YAML/preamble of every `.Rmd`) starts with:

    # Purpose:    <one line>
    # Inputs:     <path> (<type>), ...
    # Outputs:    <path> (<type>), ...
    # Upstream:   <script or report that produces inputs>
    # Downstream: <script or report that consumes outputs>

Headers, INDEX.md, and `dependencies.json` together form the static picture; `RUN_LOG.md` is the dynamic execution trace. When they disagree, fix the static side.

## Prompt-Driven Workflow

Prompts are first-class artifacts in this project — versioned, reviewable, and committed alongside the code they produce.

### The four files

| File | What goes in | Edit policy |
|------|--------------|-------------|
| `Prompts/Logs/PROMPT_LOG.md`   | Every user prompt verbatim, auto-appended by hook | Never edit by hand |
| `Prompts/implementation.md`    | Curated backlog of real requests (`## Todo` / `## In progress` / `## Done`) | Hand-curated; triage from PROMPT_LOG |
| `Prompts/canvases/NNN_slug.md` | One structured prompt per task, written before the code it drives | Update before code, commit together |
| `Prompts/research_plan.md`     | High-level scientific plan (rare changes) | Hand-curated |

### The flow

1. You type a request → hook auto-appends to `PROMPT_LOG.md`
2. `/triage` (or by hand): promote real requests from the log into `implementation.md` under `## Todo`
3. `/plan-convert` (or by hand): turn an `implementation.md` item into a structured canvas in `Prompts/canvases/NNN_slug.md`
4. `/plan-exec` style execution: generate code from the canvas, commit canvas + code together
5. Move the `implementation.md` entry to `## Done` with a backlink to the canvas

### Canvas file format

Each canvas is a markdown file at `Prompts/canvases/NNN_slug.md` with this front matter and body:

    ---
    id: 003
    slug: normalization
    created: 2026-05-10
    source_prompt_log: 2026-05-10T14:32:15  # timestamp anchor in PROMPT_LOG.md
    implementation_md_item: "Normalize counts with size factors"
    status: in_progress  # todo | in_progress | done
    ---

    # Question
    What scientific question does this answer? (one sentence)

    # Entities
    Data, samples, features, metadata involved. Reference paths.

    # Approach
    Methods, packages, parameters, thresholds. Be specific.

    # Structure
    Upstream: which canvases / reports / data feed this
    Downstream: which canvases / reports / outputs depend on it

    # Operations
    Numbered steps the report will perform.

    # Safeguards
    Sanity checks, oracle tests, validation against established tools.

### Per-report header (`.Rmd` / `.R` / `.py`)

Every analysis script starts with a comment block pointing at its canvas:

    # Canvas:     Prompts/canvases/003_normalization.md
    # Purpose:    <one line, mirrors canvas Question>
    # Inputs:     <path> (<type>), ...
    # Outputs:    <path> (<type>), ...
    # Upstream:   <canvas/report producing inputs>
    # Downstream: <canvas/report consuming outputs>

### Fix the prompt first

When a report's output is wrong, the rule is:

1. Update the canvas (intent, parameters, method) — **first**
2. Regenerate or surgically edit the script to match
3. Re-run, re-commit

Editing code without updating the canvas turns the canvas into a lie about what the code does, and the provenance chain breaks. Hot-fix exception: trivial cosmetic tweaks (axis labels, colours, typos) can skip canvas updates — but the prompt that requested them still lives in `PROMPT_LOG.md` so it's not invisible.

### Provenance commit trailer

Every commit that implements a canvas ends with:

    Implements: Prompts/canvases/003_normalization.md

Multiple canvases per commit go on separate trailer lines. This makes the chain queryable: `git log --grep "canvases/003"` finds every commit that touched a given task.

### Figure → canvas backlink

Every figure caption ends with `(canvas: NNN)` so the prompt that drove the figure can be recovered six months later from the figure alone.
---END CLAUDE.md TEMPLATE---
