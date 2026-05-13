---
description: Convert a research plan into a detailed implementation plan with phased tasks, report specifications, and checkboxes
argument-hint: [path-to-research-plan]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(mkdir:*), Bash(date:*), Bash(ls:*), Bash(find:*), Agent]
---

# Convert Research Plan to Implementation Plan

You are converting a research plan into a detailed, actionable implementation plan. Follow each phase sequentially.

---

## Phase 1: Locate the Research Plan

**Actions**:
1. Check `$ARGUMENTS`:
   - If a **path** is provided: read that file directly
   - If **no argument**: search for `research_plan.md` — check `Prompts/research_plan.md` first, then Glob with `**/research_plan.md`
2. Read the full research plan
3. If not found, inform the user and stop

---

## Phase 2: Understand the Project Context

**Goal**: Build a complete picture of the project before writing the plan

**Actions**:
1. Launch 2-3 Explore agents in parallel to investigate:
   - **Data agent**: What data exists? Check `Data/`, `Documentation/`, sample sheets. Identify data types (RNA-seq, scRNA-seq, ChIP-seq, etc.), species, sample counts, file formats
   - **Code agent**: What code already exists? Check `Scripts/`, `Config.*`, existing reports. Identify languages (R, Python), frameworks (Seurat, Scanpy, DESeq2), existing helper functions
   - **Infrastructure agent**: Check for `renv.lock`, conda environments, guix manifests, `.gitignore`, `CHANGELOG.md`, existing `Results/` structure
2. Read the research plan's scientific analysis section carefully
3. Identify the key scientific questions and analytical goals

---

## Phase 3: Evaluate the Research Plan

**Goal**: Critically assess the research plan before converting it

**Actions**:
1. Write a brief evaluation section at the top of the implementation plan:
   - **Strengths**: What is well-defined? Clear questions, available data, logical flow
   - **Issues & Clarifications**: Identify potential problems:
     - Incorrect terminology or typos
     - Missing information (sample sizes, thresholds, reference genomes)
     - Statistical limitations (e.g., low replicate count for DESeq2)
     - Ambiguous steps that need interpretation
     - Data availability concerns
2. Note assumptions you are making where the research plan is vague

---

## Phase 4: Write the Implementation Plan

**Goal**: Create `Prompts/implementation_plan.md` — a detailed, phased plan with checkboxes

**Structure the plan as follows:**

```markdown
# Implementation Plan: <Project Name> — <Brief Description>

## Evaluation of Research Plan

### Strengths
- ...

### Issues & Clarifications
- ...

---

## Phase 0: Project Setup & Environment Configuration

### 0.1 Directory Structure
- [ ] Task description...

### 0.2 Git Repository
- [ ] Task description...

### 0.3 R/Python Environment Setup
- [ ] Task description...

---

## Phase N: <Analysis Phase Name>

### Report: `Scripts/Reports/NN_report_name.Rmd`
### Output: `Results/NN_report_name/`

### N.1 Helper Functions — `Scripts/Bin/function_file.R`

**`function_name()`**
- Input: ...
- Processing steps...
- Output: ...
- Wrap with cacheR for disk caching

### N.2 Report Content

| Plot | Description | File naming |
|------|-------------|-------------|
| Plot type | What it shows | `yymmdd_type_description.pdf` |

### N.3 Tasks
- [ ] Implement `function_name()` in `Scripts/Bin/function_file.R`
- [ ] Create report section for ...
- [ ] Generate figure: ...

---
```

**Guidelines for writing the plan:**

1. **Phase 0** is always project setup (directories, git, environment) — skip items that already exist
2. **Each subsequent phase** corresponds to a major analytical step, typically producing one report
3. **Reports** are numbered sequentially: `01_data_loading`, `02_quality_control`, `03_analysis`, etc.
4. **Helper functions** go in `Scripts/Bin/` — define function signatures, inputs, outputs, and caching strategy
5. **Every task gets a checkbox** `- [ ]` for tracking by `/plan-exec` and `/plan-review`
6. **Figure tables** specify: plot type, what it shows, and file naming convention (`yymmdd_type_description.pdf`)
7. **Be specific**: name exact files, functions, packages, parameters, thresholds
8. **Reference the data**: use actual file paths, column names from sample sheets, gene names from gene sets
9. **Statistical methods**: specify exact tests, correction methods, thresholds (e.g., "DESeq2 Wald test, padj < 0.05, |log2FC| > 1")
10. **Order phases by dependencies**: data loading → QC → normalization → analysis → integration → visualization
11. **Include a final phase** for a summary report (`00_Report`) that links to all other reports
12. **Wrap expensive computations** with cacheR
13. **Keep tasks atomic**: each checkbox should be a single, completable unit of work

**Scale guidance:**
- A typical implementation plan has 4-8 phases
- Each phase has 5-15 tasks
- Each report has 5-12 figures specified in the table
- Helper function definitions should include parameter descriptions and expected return values

---

## Phase 5: Cross-Reference with Existing Code

**Goal**: Mark items that are already done

**Actions**:
1. Compare the implementation plan against existing code found in Phase 2
2. Mark already-completed items with `[x]`
3. Add notes for partially completed items
4. Flag any existing code that is NOT covered by the plan — add as novel items

---

## Phase 6: Save and Commit

**Goal**: Write the plan and commit

**Actions**:
1. Create `Prompts/` directory if it does not exist
2. Write the implementation plan to `Prompts/implementation_plan.md`
3. If the file already exists, warn the user and ask before overwriting
4. Stage and commit with message: `docs: create implementation plan from research plan`
5. Show the user a summary: number of phases, total tasks, tasks already completed

---

## Phase 7: Suggest First Steps

**Goal**: Help the user get started

**Actions**:
1. Identify the **top 3 tasks** to start with based on:
   - Dependencies (what unblocks other work)
   - Quick wins (what can be done immediately)
   - Impact (what delivers the most analytical value)
2. Present these to the user with brief justification
3. Remind them they can run `/plan-exec` to start executing tasks

---
