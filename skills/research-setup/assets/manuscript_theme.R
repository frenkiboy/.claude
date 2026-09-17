# Purpose:    Single source of truth for figure colour + theme across every report in a project.
#             Paul Tol "muted" — a matte, colourblind-safe pool.
# Inputs:     none (constants + ggplot2 scale/theme helpers)
# Outputs:    R objects: palette constants, scale_*_<role>() helpers, theme_manuscript()
# Upstream:   Prompts/manuscript/figure_style.md
# Downstream: sourced by Scripts/Reports/_report_setup.R -> available in every report
#
# TEMPLATE — copy to Scripts/Bin/manuscript_theme.R and define your project's roles below.
#
# Design rule: ONE pool, scoped per figure. Pick ONE variable whose levels recur across reports
# (method / condition / tissue / modality) and give it a FIXED global assignment, so that level is
# the same colour everywhere. Every other role draws from the same pool and is declared in the
# figure's legend. Grey is semantic — baseline / n.s. / absent / other — never decorative.
#
# Scales are namespace-qualified (ggplot2::) inside function bodies, so this file can be sourced
# BEFORE library(ggplot2) is attached (as _report_setup.R does).

## ---- palette: Paul Tol "muted" (CVD-safe, matte) ----------------------------------------
# Distinct under deuteranopia, protanopia and tritanopia.
MUTED_POOL <- c("#332288", "#44AA99", "#DDCC77", "#CC6677", "#88CCEE",
                "#117733", "#882255", "#999933", "#AA4499")
GREY_NEUTRAL  <- "#BBBBBB"   # baseline / n.s. / "other"
GREY_HAIRLINE <- "#DDDDDD"

## ---- PROJECT ROLES — edit this block -----------------------------------------------------
# The one fixed global assignment. Rename to your project's recurring variable and give the
# baseline/control level GREY_NEUTRAL: a floor is not a competitor and should not get a hue.
#
#   GROUP <- c(treatment_a = "#332288", treatment_b = "#44AA99",
#              control     = GREY_NEUTRAL)
#
# Add further per-figure roles the same way, and declare them in each figure's legend.
GROUP <- c()

## ---- continuous ramps --------------------------------------------------------------------
SEQ_INDIGO <- c("#EDEDF5", "#C3C2DE", "#9391C3", "#332288", "#1D1350")  # abundance / coverage
DIVERGE    <- c(low = "#332288", mid = "#EDEDED", high = "#CC6677")     # deltas / logFC / z

## ---- qualitative palette -----------------------------------------------------------------
# Errors loudly past 9 rather than interpolating into CVD-unsafe colours. More than nine levels
# means the variable is not categorical for plotting — use a sequential scale, facet, or aggregate.
pal_manuscript <- function(n) {
    if (n > length(MUTED_POOL))
        stop(sprintf(paste("pal_manuscript: %d levels requested but the CVD-safe pool has %d;",
                           "use a sequential scale for many-level variables."),
                     n, length(MUTED_POOL)))
    MUTED_POOL[seq_len(n)]
}

## ---- semantic ggplot2 scales ---------------------------------------------------------------
scale_fill_group     <- function(...) ggplot2::scale_fill_manual(values = GROUP, ...)
scale_color_group    <- function(...) ggplot2::scale_colour_manual(values = GROUP, ...)
scale_colour_group   <- scale_color_group

scale_fill_manuscript   <- function(...) ggplot2::scale_fill_manual(values = MUTED_POOL, ...)
scale_color_manuscript  <- function(...) ggplot2::scale_colour_manual(values = MUTED_POOL, ...)
scale_colour_manuscript <- scale_color_manuscript

scale_fill_abundance  <- function(...) ggplot2::scale_fill_gradientn(colours = SEQ_INDIGO, ...)
scale_color_abundance <- function(...) ggplot2::scale_colour_gradientn(colours = SEQ_INDIGO, ...)
# Always set `midpoint` explicitly — a diverging scale with a misplaced centre lies about sign.
scale_fill_diverging  <- function(midpoint = 0, ...)
    ggplot2::scale_fill_gradient2(low = DIVERGE[["low"]], mid = DIVERGE[["mid"]],
                                  high = DIVERGE[["high"]], midpoint = midpoint, ...)
scale_color_diverging <- function(midpoint = 0, ...)
    ggplot2::scale_colour_gradient2(low = DIVERGE[["low"]], mid = DIVERGE[["mid"]],
                                    high = DIVERGE[["high"]], midpoint = midpoint, ...)

## ---- theme -----------------------------------------------------------------------------
theme_manuscript <- function(base_size = 11, base_family = "") {
    ink <- "#1B2027"; soft <- "#525b66"; hair <- "#E2E5EA"
    ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
        ggplot2::theme(
            panel.border     = ggplot2::element_rect(colour = hair, fill = NA, linewidth = 0.5),
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major = ggplot2::element_line(colour = hair, linewidth = 0.35),
            axis.text        = ggplot2::element_text(colour = soft),
            axis.title       = ggplot2::element_text(colour = ink),
            plot.title       = ggplot2::element_text(colour = ink, face = "bold",
                                                     size = base_size + 1),
            plot.subtitle    = ggplot2::element_text(colour = soft),
            strip.background = ggplot2::element_rect(fill = "#F2F4F6", colour = hair),
            strip.text       = ggplot2::element_text(colour = ink),
            legend.key       = ggplot2::element_blank(),
            legend.title     = ggplot2::element_text(colour = ink, size = base_size - 1),
            legend.text      = ggplot2::element_text(colour = soft, size = base_size - 1)
        )
}
