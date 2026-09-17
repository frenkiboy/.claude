# Shared report setup — sourced by every Scripts/Reports/*.Rmd setup chunk.
# Project convention (CLAUDE.md): ALL figures are numbered.
#
# Auto-numbers figure captions across a report as "Figure N. <caption>" by wrapping the default
# knitr plot hook — no per-caption edits, no extra dependency. Any chunk that sets fig.cap gets
# the next number. Write captions WITHOUT a manual number; the hook adds it in order, so
# inserting a figure mid-report renumbers everything after it automatically.
#
# Usage (in a report's ```{r setup} chunk):
#     source("_report_setup.R")     # reports render with wd = Scripts/Reports/
#
# Also loads the shared colour system (Scripts/Bin/manuscript_theme.R): the matte, colourblind-safe
# Paul Tol "muted" palette + semantic scales (scale_colour_method/_encoding/_selected/...) and
# theme_manuscript(). Made available but NOT forced — a report opts in with
# `theme_set(theme_manuscript())` and the scale_*_<role>() helpers where a variable is semantic.
# See Prompts/manuscript/figure_style.md.

local({
    theme_path <- "../Bin/manuscript_theme.R"          # wd = Scripts/Reports/
    if (file.exists(theme_path)) source(theme_path, local = FALSE)
})

local({
    fig_i <- 0L
    base_hook <- knitr::knit_hooks$get("plot")
    knitr::knit_hooks$set(plot = function(x, options) {
        if (!is.null(options$fig.cap) && nzchar(options$fig.cap) &&
            !grepl("^Figure [0-9]+\\.", options$fig.cap)) {
            fig_i <<- fig_i + 1L
            options$fig.cap <- paste0("Figure ", fig_i, ". ", options$fig.cap)
        }
        base_hook(x, options)
    })
})
