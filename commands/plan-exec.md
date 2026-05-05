---
description: Execute uncompleted items from an implementation plan, then commit all changes. Optionally pass a plan file path and/or task numbers (e.g. /plan-exec, /plan-exec 3, /plan-exec Prompts/my_plan.md, /plan-exec Prompts/my_plan.md 1,3,5).
argument-hint: [plan-file] [task-number(s) | all | next]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Implementation Plan Execution

You are executing uncompleted items from an implementation plan. Follow each phase sequentially.

---

## Phase 1: Locate and Parse the Plan

**Actions**:
1. Parse `$ARGUMENTS` into whitespace-separated tokens. The first token is a **plan-file** if it (a) ends in `.md`, (b) contains `/`, or (c) matches an existing file on disk. Otherwise treat all tokens as task selectors.
2. Determine the plan file:
   - If a plan-file token was provided: use it (resolve relative to the working directory; error out if missing)
   - Else: check `Prompts/implementation_plan.md` first, then fall back to Glob with pattern `**/implementation_plan.md`
3. Read the full plan file
4. If not found, inform the user and stop
5. Also read `Prompts/CHANGELOG.md` if it exists
6. Extract all uncompleted TODO items (lines with `[ ]` or unmarked items under TODO sections), numbering them sequentially (1, 2, 3, ...)
7. Determine which items to execute from the remaining (non-plan-file) tokens:
   - If `next`: execute only the **first** uncompleted task (task #1 in the numbered list)
   - If a **number** is provided (e.g., `3`): execute only that specific task item
   - If **multiple numbers** are provided (e.g., `1,3,5` or `1 3 5`): execute those specific items
   - If `all` or **no task token**: present the numbered list to the user and ask which items to execute (or confirm "all")

**Examples of argument parsing**:
- `/plan-exec` → default plan file, ask user
- `/plan-exec next` → default plan file, first uncompleted task
- `/plan-exec 3` → default plan file, task 3
- `/plan-exec all` → default plan file, all tasks
- `/plan-exec Prompts/my_plan.md` → `Prompts/my_plan.md`, ask user
- `/plan-exec Prompts/my_plan.md next` → `Prompts/my_plan.md`, first uncompleted task
- `/plan-exec Prompts/my_plan.md 3` → `Prompts/my_plan.md`, task 3
- `/plan-exec Prompts/my_plan.md 1,3,5` → `Prompts/my_plan.md`, tasks 1, 3, and 5
- `/plan-exec Prompts/my_plan.md all` → `Prompts/my_plan.md`, all tasks

---

## Phase 1b: Pre-flight — Commit Pending Plan Edits

**Goal**: Keep manual plan edits separate from implementation commits

**Actions**:
1. Skip this phase if the working directory is not a git repo
2. Run `git status --porcelain -- <plan-file>` (and `Prompts/CHANGELOG.md` if it exists)
3. If either file has staged or unstaged changes:
   - Stage only those files (do NOT use `git add -A`)
   - Commit with message: `docs: refine plan`
   - Show the commit hash to the user so they know it happened
4. Proceed to Phase 2 with a clean plan-file state

This ensures the upcoming implementation commit only contains code changes, not the user's manual plan edits.

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
1. Read the existing `Prompts/CHANGELOG.md` (create `Prompts/` directory if needed)
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
