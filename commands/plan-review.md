---
description: Review implementation_plan.md - audit progress, mark done items, propose next steps, commit, and plan execution
argument-hint: [plan-file]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(mkdir:*), Bash(date:*), Agent]
---

# Implementation Plan Review

You are reviewing and advancing an implementation plan. Follow each phase sequentially.

---

## Phase 1: Locate and Read the Plan

**Actions**:
1. If `$ARGUMENTS` is provided, use it as the plan file path
2. Otherwise, find `implementation_plan.md` — check `Prompts/implementation_plan.md` first, then fall back to Glob with pattern `**/implementation_plan.md`
3. Read the full file
4. If not found, inform the user and stop

---

## Phase 1b: Pre-flight — Commit Pending Plan Edits

**Goal**: Keep manual plan edits separate from the audit commit

**Actions**:
1. Skip this phase if the working directory is not a git repo
2. Run `git status --porcelain -- <plan-file>`
3. If the plan file has staged or unstaged changes:
   - Stage only that file (do NOT use `git add -A`)
   - Commit with message: `docs: refine plan`
   - Show the commit hash to the user so they know it happened
4. Proceed to Phase 2 with a clean plan-file state

This ensures the audit commit in Phase 4 only contains audit-driven changes, not the user's manual edits.

---

## Phase 2: Audit the Codebase for Completed Work

**Goal**: Determine which plan items have already been implemented

**Actions**:
1. Launch 2-3 Explore agents in parallel to investigate the codebase:
   - One agent should check which components/features from the plan already exist in the code
   - One agent should identify new code additions not yet reflected in the plan (novel additions)
   - One agent should assess the current state of tests, documentation, or infrastructure items from the plan
2. Collect findings from all agents

---

## Phase 3: Report and Update the Plan

**Goal**: Mark completed items and flag novel additions

**Actions**:
1. Present a summary to the user:
   - **Completed**: Items from the plan that are now implemented (with evidence)
   - **Novel additions**: Code/features found that aren't in the plan yet
   - **In progress**: Items partially done
   - **Not started**: Items with no implementation yet
2. Update `implementation_plan.md`:
   - Mark completed items with `[x]` (or equivalent checkbox notation already used in the file)
   - Add any novel additions as new items under an appropriate section
   - Preserve the document's existing formatting and structure
3. Show the user the diff of changes made to the plan

---

## Phase 4: Commit the Updated Plan

**Goal**: Save the current state of the plan in git

**Actions**:
1. Check if the repository has git initialized; if not, inform the user and skip this phase
2. Stage `implementation_plan.md`
3. Commit with message: "docs: update implementation plan - mark completed items and add novel additions"
4. Confirm the commit to the user

---

## Phase 5: Propose and Plan Next Steps

**Goal**: Recommend what to work on next and outline execution

**Actions**:
1. From the remaining uncompleted items, identify the **top 3-5 actionable next steps** based on:
   - Dependencies (what unblocks other work)
   - Impact (what delivers the most value)
   - Feasibility (what can be done now with current codebase state)
2. For each proposed next step, provide:
   - **What**: Clear description of the task
   - **Why**: Why this should be prioritized
   - **How**: Brief execution plan (key files to modify, approach, estimated complexity)
   - **Dependencies**: What must exist first
3. Present the ranked list to the user and ask which items they want to tackle next

---

## Phase 6: Export Tasks to File

**Goal**: Write all remaining tasks to a dated file in the `Prompts/Logs/` directory

**Actions**:
1. Create `Prompts/Logs/` directory if it does not exist
2. Determine today's date in `yymmdd` format (e.g., `260330`)
3. Check if `Prompts/Logs/yymmdd_tasks.md` already exists
4. **If the file does NOT exist**: Create `Prompts/Logs/yymmdd_tasks.md` with:
   - A header: `# Remaining Tasks — YYYY-MM-DD`
   - All uncompleted tasks from the plan, each with: status, description, key files, dependencies, output
5. **If the file ALREADY exists**: Prepend a new section at the top of the file (after the main header) with:
   - `## Update HH:MM` (current hour and minute)
   - The updated task list reflecting the latest audit results
   - Keep the previous entries below for history
6. Confirm the file path to the user

---

## Phase 7: Update Implementation Summary

**Goal**: Maintain `implementation_summary.md` — a clean, up-to-date document of everything accomplished in the project, organized by report

**Actions**:
1. Read all reports in `Scripts/Reports/` (`.Rmd`, `.md`, `.qmd` files)
2. Read existing `Prompts/implementation_summary.md` if it exists
3. Create or update `Prompts/implementation_summary.md` with:
   - A header: `# Implementation Summary`
   - A brief project description (derived from `research_plan.md` or `implementation_plan.md`)
   - **One subheading per report** in `Scripts/Reports/`, named after the report (e.g., `## 01_QC_Analysis`)
   - Under each subheading, list:
     - The analyses performed in that report
     - Key findings or outputs (figures, tables)
     - Which implementation plan items this report addresses
   - A final section for work done outside of reports (data processing, pipeline setup, etc.)
4. The document should be well-organized, readable, and suitable as a project overview for collaborators
5. Stage and commit `Prompts/implementation_summary.md` with message: "docs: update implementation summary"

---
