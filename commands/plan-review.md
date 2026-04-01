---
description: Review implementation_plan.md - audit progress, mark done items, propose next steps, commit, and plan execution
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Agent]
---

# Implementation Plan Review

You are reviewing and advancing an implementation plan. Follow each phase sequentially.

---

## Phase 1: Locate and Read the Plan

**Actions**:
1. Find `implementation_plan.md` in the current folder tree using Glob with pattern `**/implementation_plan.md`
2. Read the full file
3. If not found, inform the user and stop

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

**Goal**: Write all remaining tasks to a dated file in the `Prompts/` directory

**Actions**:
1. Determine today's date in `yymmdd` format (e.g., `260330`)
2. Check if `Prompts/yymmdd_tasks.md` already exists
3. **If the file does NOT exist**: Create `Prompts/yymmdd_tasks.md` with:
   - A header: `# Remaining Tasks — YYYY-MM-DD`
   - All uncompleted tasks from the plan, each with: status, description, key files, dependencies, output
4. **If the file ALREADY exists**: Prepend a new section at the top of the file (after the main header) with:
   - `## Update HH:MM` (current hour and minute)
   - The updated task list reflecting the latest audit results
   - Keep the previous entries below for history
5. Confirm the file path to the user

---
