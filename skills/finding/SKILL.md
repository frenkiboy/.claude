---
name: finding
description: Record a scientific finding into the project's topic-based evidence ledger (Prompts/findings/). Use when an analysis yields a result worth tracking as evidence for or against a claim — distinct from a code/process learning (that goes to Prompts/learnings.md via /transfer). Maintains Prompts/findings/{topic}.md and FINDINGS_REGISTRY.md.
argument-hint: [claim text, or a topic slug]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(date *), Bash(ls *), Bash(mkdir *)
---

# Record a Scientific Finding

A **finding** is a substantive scientific claim supported (or refuted) by evidence
in this project — e.g. "Tumor samples show loss of X expression vs normal (p<0.01,
canvas 014)". It is NOT a process/tooling gotcha; those are *learnings* (see
`Prompts/learnings.md` and `/transfer`).

Findings live in **topic ledgers** so evidence accumulates across runs:
`Prompts/findings/{topic-slug}.md`, indexed by `Prompts/findings/FINDINGS_REGISTRY.md`.

## Preconditions

This skill operates on a research-setup project. If `./Prompts/` does not exist,
tell the user this isn't a pipeline project and stop (suggest `/research-setup`).
If `Prompts/findings/FINDINGS_REGISTRY.md` is missing, create it from the seed in
the **Templates** section before proceeding.

## Steps

1. **Get the claim.** Use the argument as the finding's one-line claim. If the
   argument is empty or just a topic slug, ask the user for the claim (one
   sentence, falsifiable, with direction/magnitude where possible).

2. **Pick the topic.** Topics group related claims (e.g. `xist-silencing`,
   `batch-effects`, `de-genes-tumor-vs-normal`). List existing ledgers
   (`ls Prompts/findings/*.md` excluding the registry) and reuse the best match;
   otherwise propose a new kebab-case `topic-slug` and confirm with the user.

3. **Gather evidence.** Identify the supporting artifact(s): the canvas number,
   the report/figure path under `Results/`, and the test/stat that backs it.
   Pull these from context or ask. Prefer concrete pointers (`canvas: 014`,
   `Results/de_analysis/260624_volcano.pdf`) over prose.

4. **Assign an ID and status.**
   - ID: `F-NNN` — next integer across all ledgers (scan existing IDs in
     `Prompts/findings/`). Zero-pad to 3.
   - Status: `tentative` (one line of evidence / unreplicated), `supported`
     (multiple consistent lines), or `refuted`.

5. **Write the ledger entry.** If `Prompts/findings/{topic-slug}.md` exists,
   append a new finding block (or, if this strengthens/refutes an existing
   finding in that topic, add an evidence bullet + update its Status/Updated
   instead of duplicating). If new, create it from the **Topic Ledger Template**.

6. **Update the registry.** Add or update the `F-NNN` row in
   `FINDINGS_REGISTRY.md` (claim, status, topic link, today's date from
   `date +%Y-%m-%d`). Keep rows sorted by ID.

7. **Cross-link.** If the finding came from a specific canvas, mention in your
   reply that the canvas/report caption can cite `(finding: F-NNN)` so the
   provenance chain is bidirectional.

8. **Report** the ID, topic file, and status back to the user. Do not invent
   evidence — if the claim isn't actually backed by a project artifact yet, say
   so and record it as `tentative` with a note on what evidence is still needed.

## Templates

### Registry seed (`Prompts/findings/FINDINGS_REGISTRY.md`)

```markdown
# Findings Registry

> Scientific findings for this project. One topic ledger per file in this
> directory (`<topic-slug>.md`); each accumulates evidence across runs.
> Maintained by `/finding`. Status: tentative | supported | refuted.

| ID | Claim | Status | Topic | Updated |
|----|-------|--------|-------|---------|
```

### Topic Ledger Template (`Prompts/findings/{topic-slug}.md`)

```markdown
# Finding topic: <Topic title>

## F-NNN — <one-line claim>
- **Status:** tentative | supported | refuted
- **Claim:** <full statement with direction/magnitude>
- **Evidence:**
  - <result/figure/test> (canvas: NNN, Results/...) — what it shows
- **Caveats / alternatives:** <confounds, competing explanations, n>
- **Implications:** <what it means for the project's questions>
- **Updated:** YYYY-MM-DD
```

### Registry row

```
| F-014 | Tumor samples lose X expression vs normal | supported | [de-genes](de-genes-tumor-vs-normal.md) | 2026-06-24 |
```
