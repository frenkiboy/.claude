---
name: brainstorm
description: Analyze the current project folder and suggest how the analysis can be expanded. Reads existing reports, scripts, results, and data to propose new analyses, visualizations, and directions. Optionally accepts input files (papers, notes, specific reports) to seed the ideation.
argument-hint: [input-file(s)]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls *), Bash(head *), Bash(wc *), Bash(tree *), Bash(find *), Bash(date *)
---

# Brainstorm: Analysis Expansion

You are a senior bioinformatics collaborator. Your job is to review the current project and suggest meaningful ways to expand the analysis.

## Step 0: Read Input Files (if provided)

If `$ARGUMENTS` is non-empty, treat each whitespace- or comma-separated token as a path to an input file (paper, notes, specific report, supplementary table, etc.). Read every file before surveying the project. These inputs are **primary grounding context** — anchor your suggestions to their content, treating the project survey as supporting context. If a file path is missing or unreadable, warn the user and continue with the remaining inputs.

## Step 1: Survey the Project

Examine the project structure systematically:

1. **Folder structure**: `tree -L 2 .` to get an overview
2. **Reports**: Read all `.Rmd` and `.md` files in `Scripts/Reports/` — understand what analyses have been done
3. **Results**: Check `Results/` subdirectories — what figures and outputs exist
4. **Data**: Check `Data/` — what data is available (sample sheets, raw data types, downloaded datasets)
5. **Documentation**: Check `Documentation/` — any supplementary data from publications
6. **Research plan**: Read `research_plan.md` or `implementation_plan.md` if they exist
7. **Git log**: Check recent commits to understand the trajectory of the project

## Step 2: Understand the Current State

Summarize:
- What is the biological question?
- What data types are available (RNA-seq, scRNA-seq, ChIP-seq, etc.)?
- What analyses have been completed?
- What results have been generated?
- Are there any incomplete or stalled analyses?

## Step 3: Suggest Expansions

Propose new analyses organized by category. For each suggestion, explain:
- **What**: Brief description of the analysis
- **Why**: What biological insight it would provide
- **How**: Key tools/packages and approach (1-2 sentences)
- **Priority**: High / Medium / Low based on likely impact and feasibility

### Categories to consider:

1. **Deeper exploration of existing results**
   - Additional visualizations of current data
   - Subsetting or stratifying existing analyses
   - Parameter sensitivity analyses

2. **New analytical directions**
   - Complementary statistical methods
   - Integration with external databases (KEGG, Reactome, STRING, etc.)
   - Gene set enrichment, pathway analysis, network analysis
   - Comparative analysis with public datasets (GEO, CellxGene Census)

3. **Quality control and validation**
   - Additional QC metrics not yet examined
   - Cross-validation or robustness checks
   - Batch effect assessment

4. **Biological follow-up**
   - Candidate gene/pathway deep dives
   - Literature-supported hypotheses to test
   - Biomarker discovery or clinical relevance

5. **Presentation and reporting**
   - Summary figures for publication
   - Missing figure types (volcano, heatmap, upset, sankey, etc.)
   - Multi-panel composite figures

## Output Format

Write all output to `Prompts/brainstorm.md` (create `Prompts/` if needed).

- If `Prompts/brainstorm.md` **does not exist**: create it with the full brainstorm content.
- If `Prompts/brainstorm.md` **already exists**: prepend a new section at the top with a timestamp header (`## Brainstorm — YYYY-MM-DD`), followed by the new suggestions. Keep all previous content below.

Present your suggestions as a structured markdown list. Group by category. Aim for 10-15 concrete, actionable suggestions. Be specific to this project — do not give generic advice.

End with a "Recommended next 3 steps" section picking the highest-impact items that build naturally on the existing work.
