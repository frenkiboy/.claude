---
description: Execute uncompleted items from implementation_plan.md, then commit all changes
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Implementation Plan Execution

You are executing uncompleted items from an implementation plan. Follow each phase sequentially.

---

## Phase 1: Locate and Parse the Plan

**Actions**:
1. Find `implementation_plan.md` in the current folder tree using Glob with pattern `**/implementation_plan.md`
2. Read the full file
3. If not found, inform the user and stop
4. Also read `CHANGELOG.md` if it exists alongside the plan (same directory)
5. Extract all uncompleted TODO items (lines with `[ ]` or unmarked items under TODO sections)
6. Present the list of uncompleted items to the user and ask which items to execute (or confirm "all")

---

## Phase 2: Execute Each Item

**Goal**: Implement each selected TODO item from the plan

**Actions**:
1. For each item, determine what needs to be done:
   - Read any referenced files (reports, scripts, data files) to understand current state
   - Identify what code changes are needed
2. Implement the changes:
   - Edit existing `.Rmd` reports, `.R` scripts, or other files as specified by the plan item
   - Follow existing code conventions found in the project
   - Test changes where possible (e.g., check R syntax, verify file paths exist)
3. After completing each item, mark it as done in `implementation_plan.md` by changing `[ ]` to `[x]`
4. Keep a running log of what was changed for each item

**Guidelines**:
- Work through items sequentially unless independent items can be parallelized
- If an item requires data that doesn't exist, skip it and note the blocker
- If an item is ambiguous, make reasonable choices based on project context
- Do NOT render reports unless explicitly requested — just edit the source files
- Prefer minimal, targeted edits over large rewrites

---

## Phase 3: Update the Changelog

**Goal**: Document what was implemented

**Actions**:
1. Read the existing `CHANGELOG.md` (same directory as `implementation_plan.md`)
2. Add a new version entry at the top with today's date
3. List all items that were completed with brief descriptions
4. Note any items that were skipped and why

---

## Phase 4: Commit All Changes

**Goal**: Create a single commit with all implementation work

**Actions**:
1. Run `git status` to see all changed files
2. Run `git diff` to review changes
3. Stage all relevant files (reports, scripts, plan, changelog — NOT data files or large binaries)
4. Create a descriptive commit message summarizing what was implemented, e.g.:
   ```
   feat: implement plan items - [brief list of what was done]

   - Item 1 description
   - Item 2 description
   ...

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   ```
5. Confirm the commit to the user and show `git log --oneline -1`

---

## Phase 5: Summary

**Goal**: Report back to the user

**Actions**:
1. List all completed items with key changes made
2. List any skipped items with reasons
3. Show the commit hash and message
4. Suggest what to work on next based on remaining uncompleted items

---
