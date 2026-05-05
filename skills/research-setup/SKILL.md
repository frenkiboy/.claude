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

## Project Description


## Environment Variables

- **project_name**:
- **home_folder**:
- **data_folder**:
- **sample_sheet**:

## Folder Structure

    <home_folder>/
    ├── Scripts/
    │   ├── Bin/          # All functions and executables
    │   └── Reports/      # All R Markdown reports
    ├── Results/          # All figures created by reports
    ├── Data/             # Symlink to <data_folder>/<project_name>/Data
    ├── Documentation/    # Processed data downloaded from publications
    ├── Prompts/          # Prompt templates and notes
    │   └── Logs/         # Task logs, reports, and brainstorms
    └── CHANGELOG.md      # Shared memory across Claude sessions

## Rules

- `Data/` is a symlink to `<data_folder>/<project_name>/Data`
- Downloaded data goes in `Data/` with a README describing source and download date
- `Documentation/` holds processed data from publications
- `Results/<report_name>/` — figure names: `yymmdd_Figure-type_Figure-name.pdf`
- cacheR output: `<data_folder>/<project_name>/Results/cacheR`
- Reports rendered in `./Scripts/Reports`, output in folder `yymmdd_DESCRIPTION`
- All figures numbered; maintain `00_Report` with summary and links to all reports

## Computing Environment

### R
- Use `R45` for the newest R version
- Reproducible environment via `renv`
- Install cacheR from: `/home/vfranke/Projects/VFranke_cacheR/cacheR`

### Python
- Base Python: `/home/vfranke/bin/mamba/miniforge/bin/python`
- Create a reproducible conda/mamba or venv environment

### Git
- Initialize a git repository in `home_folder`

## Execution Guidelines

- Wrap expensive functions with cacheR
- Reports in `Scripts/Reports/` should be self-contained R Markdown
- Shared functions go in `Scripts/Bin/`

## Figure Documentation

Every figure must have a description (in `fig.cap` or preceding paragraph) covering:
- **Input data**: source, file path, filtering/transformation applied
- **Method**: functions, parameters, statistical tests, normalization, thresholds
- **What it shows**: plain-language interpretation (axes, groupings, conclusions)

Keep descriptions in sync with code — update when the generating code changes.

## Scientific Analysis Plan

<!-- Describe your analysis goals, key questions, and planned analyses here -->

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

1. Create the folder structure shown in the template above
2. Create `Data/` as a **symlink** to `<data_folder>/<project_name>/Data` (create target if needed)
3. Set up computing environment (R with renv, Python env)
4. Initialize git repository
5. Create `CHANGELOG.md` with project name header and "Project created" entry dated today
6. Write `CLAUDE.md` using the template below
7. Ask the user to describe the scientific analysis plan

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
    ├── Prompts/          # Prompt templates and notes
    │   └── Logs/         # Task logs, reports, and brainstorms
    └── CHANGELOG.md      # Shared memory across Claude sessions

### Rules

- `Data/` is a **symlink** to `<data_folder>/<project_name>/Data`
- Downloaded data goes in `Data/` with a `README` (source + download date)
- `Documentation/` holds processed data tables from publications
- `Results/<report_name>/` — figure names: `yymmdd_Figure-type_Figure-name.pdf`
- cacheR output: `<data_folder>/<project_name>/Results/cacheR`
- Reports rendered in `./Scripts/Reports`, output in folder `yymmdd_DESCRIPTION`
- All figures numbered; maintain `00_Report` with summary and links to all reports

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
---END CLAUDE.md TEMPLATE---
