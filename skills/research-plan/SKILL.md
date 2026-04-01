---
name: research-plan
description: Set up a new bioinformatics research project with standardized folder structure, computing environment (R/Python), cacheR integration, and git repository. Use when starting a new analysis project or when the user asks to scaffold a research project.
argument-hint: [project-name | print]
allowed-tools: Read, Write, Glob, Grep, Bash(mkdir *), Bash(ln *), Bash(git *), Bash(R *), Bash(Rscript *), Bash(pip *), Bash(mamba *), Bash(conda *)
---

# Research Project Setup

## Print Mode

If the argument is `print`, write the following template to `./research_plan.md` in the current working directory and stop:

```markdown
# Research Plan

## Project Description


## Environment Variables

- **project_name**:
- **home_folder**:
- **data_folder**:
- **sample_sheet**:

## Folder Structure

```
<home_folder>/
├── Scripts/
│   ├── Bin/          # All functions and executables
│   └── Reports/      # All R Markdown reports
├── Results/          # All figures created by reports
├── Data/             # Symlink to <data_folder>/<project_name>/Data
├── Documentation/    # Processed data downloaded from publications
└── Prompts/          # Prompt templates and notes
```

### Rules

- `Data/` is a symlink to `<data_folder>/<project_name>/Data`
- Downloaded data goes in `Data/` with a README describing source and download date
- `Documentation/` holds processed data from publications
- `Results/<report_name>/` — figure names: `<yymmdd>_<Figure-type>_<Figure-name>.pdf`
- cacheR output: `<data_folder>/<project_name>/Results/cacheR`
- All reports should be rendered in `./Scripts/Reports`
- All figures should be saved in `Results/<REPORT_NAME>/` with naming: `yymmdd_Figure-type_Figure-name.pdf`
- All figures in all reports should be numbered
- All reports should be knit in a folder with prefix `yymmdd`
- Always maintain an updated `00_Report` which contains a summary and relative links to all other reports in the folder
- All reports should be output in a folder named `yymmdd_DESCRIPTION`

## Computing Environment

### R
- Use `R45` for the newest R version
- Reproducible environment via `renv`
- Install cacheR from: `/home/vfranke/Projects/VFranke_cacheR/cacheR`

### Python
- Base Python: `/home/vfranke/bin/mamba/miniforge/bin/python`
- Create a reproducible conda/mamba or venv environment

## Execution Guidelines

- Wrap expensive functions with cacheR
- Reports in `Scripts/Reports/` should be self-contained R Markdown
- Shared functions go in `Scripts/Bin/`

## Scientific Analysis Plan

<!-- Describe your analysis goals, key questions, and planned analyses here -->

```

After writing the file, confirm the path to the user. Do not proceed with project setup.

---

## Setup Mode

You are setting up a new bioinformatics research project. Collect the required information from the user, then scaffold the project accordingly.

## Required Information

Ask the user to fill in these variables before proceeding:

- **project_name**: Name of the project (e.g., `AAkalin_Urine`). Use `$ARGUMENTS` if provided.
- **project_description**: Brief scientific description of the project goals.
- **home_folder**: Path to the project home directory (where code and scripts live).
- **data_folder**: Path to the data storage location (typically on a large-volume filesystem).
- **sample_sheet**: Path to the sample sheet, if applicable.

## Folder Structure

Create the following directory tree under `home_folder`:

```
<home_folder>/
├── Scripts/
│   ├── Bin/          # All functions and executables
│   └── Reports/      # All R Markdown reports
├── Results/          # All figures created by reports
├── Data/             # Symlink to <data_folder>/<project_name>/Data
├── Documentation/    # Processed data downloaded from publications
└── Prompts/          # Prompt templates and notes
```

### Rules

- `Data/` should be a **symlink** to `<data_folder>/<project_name>/Data`. Create the target directory if it does not exist.
- All downloaded data should be organized inside `Data/` with a `README` file describing the source and download date.
- `Documentation/` holds processed data tables and supplementary files from publications.
- `Results/` subdirectories should be named after the report that generates them: `Results/<report_name>/`. Figure filenames follow the pattern: `yymmdd_Figure-type_Figure-name.pdf`
- cacheR output should be saved in `<data_folder>/<project_name>/Results/cacheR`.
- All reports should be rendered in `./Scripts/Reports`.
- All figures should be saved in `Results/<REPORT_NAME>/` with naming: `yymmdd_Figure-type_Figure-name.pdf`.
- All figures in all reports must be numbered.
- All reports should be knit in a folder with prefix `yymmdd`.
- Always maintain an updated `00_Report` which contains a summary and relative links to all other reports in the folder
- All reports should be output in a folder named `yymmdd_DESCRIPTION`.

## Computing Environment

### R

- Use the `R45` command to access the newest version of R.
- Create a reproducible R environment using `renv`.
- Install the **cacheR** package from: `/home/vfranke/Projects/VFranke_cacheR/cacheR`

### Python

- Python dependency is available at: `/home/vfranke/bin/mamba/miniforge/bin/python`
- Create a reproducible Python environment (conda/mamba or venv as appropriate).

## Git

- Initialize a git repository in `home_folder` for version control of all code.

## Execution Guidelines

- Wrap time-expensive functions with **cacheR** so results are cached and easy to reuse.
- Reports in `Scripts/Reports/` should be self-contained R Markdown documents.
- Functions shared across reports belong in `Scripts/Bin/`.

## Scientific Analysis

After setup, ask the user to describe the scientific analysis plan so you can help structure the initial reports and analysis scripts.
