# =============================================================================
# Breedbase Analysis Pipeline - phenotypic analysis of a dataset
# =============================================================================
#
# Runs a configurable phenotypic analysis pipeline ("recipe") on a Breedbase
# phenotype file (the tab-delimited file produced when downloading a dataset
# or a trial's phenotypes):
#
#   1. Data preparation (trait selection, plot level filtering)
#   2. Outlier removal (IQR within groups, BH-MADR on model residuals and/or
#      individually excluded observations)
#   3. Modelling, either
#        a) two stages: stage 1 per trial (SpATS spatial model or a model
#           specific to the trial design) followed by a weighted stage 2
#           across trials, or
#        b) a single stage model fitted on all plots at once, built term by
#           term (environment, replicate, block, row/column, field trend,
#           G x trial / location / year, covariates) or given as a custom
#           lme4 formula.
#      Covariates (other traits of the same plots) enter the stage 1 models
#      and the single-stage model. Traits measured more than once per plot
#      (repeated measurements) are summarised per plot (mean, first, last,
#      maximum, minimum, sum, area under the curve, slope over time) or all
#      their measurements are modelled (date effect + plot effect).
#   4. Selection index (weighted Z-score or Mulamba & Mock rank sum) with
#      selection differentials and expected genetic gains.
#   5. Environmental zoning (Lin 1982 GxE F-test grouping or genetic
#      correlation clustering) for each trait and/or the selection index.
#
# Usage:
#   Rscript script_factory_pipeline.R <phenotype_file> <recipe_json> <output_json> [exclusions_json] [output_prefix]
#
# When exported from the Analysis Pipeline page, the recipe is embedded at the top
# of the script as RECIPE_JSON and the usage becomes:
#   Rscript my_script.R <phenotype_file> <output_json>
#
# Optional named arguments (anywhere on the command line):
#   --pedigree=<file>  accession, mother, father (pedigree models)
#   --repeated=<file>  unit, trait, value, date: every measurement of the traits
#                      measured more than once per plot (repeated measurements)
#
# Author: Chris Simoes ccs263@cornell.edu
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(lme4)
})

SF_VERSION <- "1.7"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
# optional named argument: --pedigree=<file> (tab-delimited accession, mother,
# father; header line; the format of the Breedbase pedigree download)
pedigree_file <- NA
named <- grepl("^--pedigree=", args)
if (any(named)) pedigree_file <- sub("^--pedigree=", "", args[named][1])
args <- args[!named]
# optional named argument: --repeated=<file> (tab-delimited unit, trait, value,
# date; one line per measurement of the traits measured more than once per plot)
repeated_file <- NA
named <- grepl("^--repeated=", args)
if (any(named)) repeated_file <- sub("^--repeated=", "", args[named][1])
args <- args[!named]
# optional named argument: --genotypes=<file> (marker dosage matrix of the
# genotyping protocol; genomic and single-step relationships)
genotypes_file <- NA
named <- grepl("^--genotypes=", args)
if (any(named)) genotypes_file <- sub("^--genotypes=", "", args[named][1])
args <- args[!named]

if (exists("RECIPE_JSON")) {
  if (length(args) < 2) {
    stop("Usage: Rscript <this_script.R> <phenotype_file> <output_json>")
  }
  phenotype_file <- args[1]
  recipe <- fromJSON(RECIPE_JSON, simplifyVector = FALSE)
  output_file <- args[2]
  exclusions_file <- if (length(args) >= 3) args[3] else NA
  output_prefix <- if (length(args) >= 4) args[4] else sub("\\.json$", "", output_file)
} else {
  if (length(args) < 3) {
    stop("Usage: Rscript script_factory_pipeline.R <phenotype_file> <recipe_json> <output_json> [exclusions_json] [output_prefix]")
  }
  phenotype_file <- args[1]
  recipe <- fromJSON(args[2], simplifyVector = FALSE)
  output_file <- args[3]
  exclusions_file <- if (length(args) >= 4) args[4] else NA
  output_prefix <- if (length(args) >= 5) args[5] else sub("\\.json$", "", output_file)
}

warnings_log <- character()
add_warning <- function(...) {
  msg <- paste0(...)
  if (exists("pretty_model")) msg <- pretty_model(msg)
  warnings_log <<- c(warnings_log, msg)
  message("WARNING: ", msg)
}

log_step <- function(...) message("[script_factory] ", paste0(...))

n_levels <- function(x) length(unique(x[!is.na(x) & x != ""]))

# safe accessor with default
opt <- function(x, name, default) {
  if (is.null(x) || is.null(x[[name]])) return(default)
  v <- x[[name]]
  if (is.list(v) && length(v) == 0) return(default)
  v
}

short_trait <- function(x) sub("\\|.*$", "", x)
# name of the model variable of a covariate (trait)
cov_name <- function(full) paste0("cov_", gsub("[^A-Za-z0-9]+", "_", short_trait(full)))

# -----------------------------------------------------------------------------
# Read data
# -----------------------------------------------------------------------------
log_step("Reading ", phenotype_file)
pheno <- read.delim(phenotype_file, header = TRUE, sep = "\t", check.names = FALSE,
                    quote = "", comment.char = "", stringsAsFactors = FALSE,
                    na.strings = c("", "NA", "NaN", "."))

required <- c("studyName", "germplasmName")
miss <- setdiff(required, names(pheno))
if (length(miss) > 0) stop("Phenotype file is missing required column(s): ", paste(miss, collapse = ", "))

if ("observationLevel" %in% names(pheno)) {
  lv <- tolower(as.character(pheno$observationLevel))
  if (any(lv == "plot", na.rm = TRUE)) {
    if (any(lv != "plot", na.rm = TRUE)) add_warning("Only plot-level observations were used; ", sum(lv != "plot", na.rm = TRUE), " non-plot rows were ignored.")
    pheno <- pheno[!is.na(lv) & lv == "plot", , drop = FALSE]
  }
}

col_or <- function(d, candidates, default = NA) {
  for (cand in candidates) if (cand %in% names(d)) return(d[[cand]])
  rep(default, nrow(d))
}

dat <- data.frame(
  unit       = as.character(col_or(pheno, c("observationUnitName", "plotName"), NA)),
  trial      = as.character(pheno$studyName),
  year       = as.character(col_or(pheno, c("studyYear", "year"))),
  location   = as.character(col_or(pheno, c("locationName", "location"))),
  design_raw = as.character(col_or(pheno, c("studyDesign", "design"))),
  accession  = as.character(pheno$germplasmName),
  rep        = as.character(col_or(pheno, c("replicate", "rep_number"))),
  block      = as.character(col_or(pheno, c("blockNumber", "block_number"))),
  row        = suppressWarnings(as.numeric(col_or(pheno, c("rowNumber", "row_number")))),
  col        = suppressWarnings(as.numeric(col_or(pheno, c("colNumber", "col_number")))),
  entry_type = as.character(col_or(pheno, c("entryType"), "test")),
  stringsAsFactors = FALSE
)
dat$unit[is.na(dat$unit)] <- paste0("row_", which(is.na(dat$unit)))
dat$location[is.na(dat$location)] <- "unknown location"
dat$year[is.na(dat$year)] <- ""

# Traits ---------------------------------------------------------------------
meta_cols <- c("studyYear", "programDbId", "programName", "programDescription", "studyDbId", "studyName",
               "studyDescription", "studyDesign", "plotWidth", "plotLength", "fieldSize",
               "fieldTrialIsPlannedToBeGenotyped", "fieldTrialIsPlannedToCross", "plantingDate", "harvestDate",
               "locationDbId", "locationName", "germplasmDbId", "germplasmName", "germplasmSynonyms",
               "observationLevel", "observationUnitDbId", "observationUnitName", "replicate", "blockNumber",
               "plotNumber", "rowNumber", "colNumber", "entryType", "plantNumber", "notes")
available_traits <- setdiff(names(pheno), meta_cols)
available_traits <- available_traits[!grepl("^plantedSeedlot|^availableGermplasm", available_traits)]

# Treatments ------------------------------------------------------------------
# Treatments are not traits. Two kinds reach the phenotype file:
#  - management factors (treatment projects): one column per project after
#    'notes', with a value on the plots that received it. Columns of the same
#    type (Fertilizer, Irrigation...) become one factor whose levels are the
#    rest of the project names ("10-15-15 400kgha base"), "none" elsewhere;
#  - treatment variables (EXPERIMENT_TREATMENT ontology): one factor each,
#    its values are the levels, "none" where missing.
# A factor is used in the models only when the recipe lists it.
trt_cfg <- opt(recipe, "treatments", list())
trt_types <- unlist(opt(trt_cfg, "types", list()))
if (!length(trt_types)) trt_types <- c("Fertilizer", "Fungicide", "Irrigation", "Drought", "Herbicide", "Weeding", "Pruning", "Hormone treatment", "Light treatment")
notes_i <- match("notes", names(pheno))
legacy_trt_cols <- if (!is.na(notes_i) && notes_i < ncol(pheno)) names(pheno)[(notes_i + 1):ncol(pheno)] else character()
onto_trt_cols <- names(pheno)[grepl("\\|(EXPERIMENT_TREATMENT|COMP_EXP_TREATMENT):", names(pheno))]
available_traits <- setdiff(available_traits, c(legacy_trt_cols, onto_trt_cols))

trt_var_name <- function(x) paste0("trt_", gsub("^_+|_+$", "", gsub("[^A-Za-z0-9]+", "_", x)))
# factor and level of a management factor column
legacy_factor <- function(col) {
  for (ty in trt_types) {
    re <- paste0("(^|[_ ])(", gsub("[ _]+", "[_ ]", ty), ")([_ ]|$)")
    if (grepl(re, col, ignore.case = TRUE, perl = TRUE)) {
      pos <- regexpr(re, col, ignore.case = TRUE, perl = TRUE)
      rest <- substring(col, pos + attr(pos, "match.length"))
      level <- trimws(gsub("[_ ]+", " ", rest))
      return(c(factor = ty, level = if (nzchar(level)) level else col))
    }
  }
  c(factor = col, level = "applied")
}
treatment_factors <- list()     # var -> list(name, var, source, values (per plot))
trt_applied <- function(v) !is.na(v) & trimws(as.character(v)) != "" & !(trimws(as.character(v)) %in% c("0", "NA"))
for (col in legacy_trt_cols) {
  fl <- legacy_factor(col)
  var <- trt_var_name(fl[["factor"]])
  on <- trt_applied(pheno[[col]])
  if (!any(on)) next
  if (is.null(treatment_factors[[var]])) treatment_factors[[var]] <- list(name = fl[["factor"]], var = var, source = "management factor", values = rep(NA_character_, nrow(pheno)))
  cur <- treatment_factors[[var]]$values
  cur[on] <- ifelse(is.na(cur[on]) | cur[on] == fl[["level"]], fl[["level"]], paste(cur[on], "+", fl[["level"]]))
  treatment_factors[[var]]$values <- cur
}
for (col in onto_trt_cols) {
  var <- trt_var_name(short_trait(col))
  v <- trimws(as.character(pheno[[col]]))
  v[!trt_applied(v)] <- NA
  if (all(is.na(v))) next
  treatment_factors[[var]] <- list(name = short_trait(col), var = var, source = "treatment variable", values = v)
}
for (k in names(treatment_factors)) {
  v <- treatment_factors[[k]]$values; v[is.na(v)] <- "none"
  treatment_factors[[k]]$values <- v
}
# factor names of the recipe (display name or variable name)
trt_pick <- function(x) { x <- unlist(x); Filter(function(k) any(c(k, treatment_factors[[k]]$name) %in% x), names(treatment_factors)) }
trt_use <- trt_pick(opt(trt_cfg, "use", list()))
trt_gxt <- trt_pick(opt(trt_cfg, "gxt", list()))
for (x in setdiff(unlist(c(opt(trt_cfg, "use", list()), opt(trt_cfg, "gxt", list()))), c(names(treatment_factors), vapply(treatment_factors, `[[`, "", "name"))))
  add_warning("Treatment '", x, "' is not in this dataset and was skipped.")

requested <- unlist(opt(recipe, "traits", list()))
if (length(requested) == 0) {
  traits <- available_traits
} else {
  # match on full name first, then on the short (display) name, so that a
  # recipe built on one dataset can be used on another one
  traits <- character()
  for (t in requested) {
    if (t %in% c(legacy_trt_cols, onto_trt_cols)) { add_warning("'", short_trait(t), "' is a treatment, not a trait; it is not analysed (it can be used as a model factor)."); next }
    if (t %in% names(pheno)) {
      traits <- c(traits, t)
    } else {
      m <- available_traits[short_trait(available_traits) == short_trait(t)]
      if (length(m) > 0) traits <- c(traits, m[1]) else add_warning("Trait '", t, "' is not in this dataset and was skipped.")
    }
  }
}
traits <- unique(traits)

# Checks: entries whose entryType is "check" (augmented designs, check plots)
dat$check <- ifelse(tolower(dat$entry_type) %in% c("check", "control", "checks"), "check", "test")

# Pedigree ----------------------------------------------------------------------
# mother / father of every accession (factors of the model; unknown parents are
# missing) and the full pedigree (ancestors included) for the relationship
# matrix. Rows: accession, mother, father.
pedigree <- NULL
if (!is.na(pedigree_file) && file.exists(pedigree_file)) {
  pg <- tryCatch(read.delim(pedigree_file, header = TRUE, sep = "\t", quote = "", comment.char = "",
                            stringsAsFactors = FALSE, colClasses = "character", na.strings = c("", "NA")),
                 error = function(e) NULL)
  if (!is.null(pg) && ncol(pg) >= 3 && nrow(pg)) {
    pg <- pg[, 1:3]; names(pg) <- c("accession", "mother", "father")
    pg <- pg[!is.na(pg$accession) & pg$accession != "", ]
    for (k in c("mother", "father")) pg[[k]][!is.na(pg[[k]]) & (pg[[k]] %in% c("", "0", "NA", "unknown") | pg[[k]] == pg$accession)] <- NA
    pedigree <- pg[!duplicated(pg$accession), ]
    log_step("Pedigree: ", nrow(pedigree), " individuals, ", sum(!is.na(pedigree$mother) | !is.na(pedigree$father)), " with known parent(s)")
  }
}
dat$mother <- if (!is.null(pedigree)) pedigree$mother[match(dat$accession, pedigree$accession)] else NA_character_
dat$father <- if (!is.null(pedigree)) pedigree$father[match(dat$accession, pedigree$accession)] else NA_character_

# Repeated measurements ---------------------------------------------------------
# Traits measured more than once on a plot (trait_repeat_type 'multiple' or
# 'time_series' in Breedbase) arrive in the phenotype file as the plot average.
# Every measurement is in the --repeated file; recipe$repeated$traits chooses,
# per trait, the value used for each plot:
#   mean, first, last, max, min, sum  of the plot's measurements
#   auc    area under the curve over the measurement dates (trapezoids, in
#          value x days; AUDPC for disease scores)
#   slope  change per day (least squares line over the dates)
#   all    every measurement enters the models (repeated-measures model):
#          a measurement date effect within trial (or a linear trend in days,
#          recipe$repeated$time = "linear"), a random plot effect for the
#          measurements of one plot and optionally genotype x date
#          (recipe$repeated$gxtime). Outlier rules, zones and covariates use
#          the plot mean of these traits.
REP_SUMMARIES <- c("mean", "first", "last", "max", "min", "sum", "auc", "slope", "all", "multi")
REP_LABEL <- c(mean = "mean", first = "first measurement", last = "last measurement", max = "maximum", min = "minimum",
               sum = "sum", auc = "area under the curve", slope = "slope per day", all = "all measurements (repeated-measures model)",
               multi = "multi-trait (each date a trait)")
rep_cfg <- opt(recipe, "repeated", list())
rep_time <- opt(rep_cfg, "time", "date")          # date | linear
if (!rep_time %in% c("date", "linear")) rep_time <- "date"
rep_gxtime <- isTRUE(opt(rep_cfg, "gxtime", FALSE))
rep_long <- NULL
if (!is.na(repeated_file) && file.exists(repeated_file)) {
  rl <- tryCatch(read.delim(repeated_file, header = TRUE, sep = "\t", quote = "", comment.char = "", stringsAsFactors = FALSE,
                            colClasses = c("character", "character", "numeric", "character"), na.strings = c("", "NA")),
                 error = function(e) NULL)
  if (!is.null(rl) && nrow(rl)) {
    names(rl)[1:4] <- c("unit", "trait", "value", "date")
    rl <- rl[!is.na(rl$value) & !is.na(rl$unit), ]
    ts <- as.POSIXct(substr(rl$date, 1, 19), tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
    ts[is.na(ts)] <- as.POSIXct(substr(rl$date[is.na(ts)], 1, 10), tz = "UTC", format = "%Y-%m-%d")
    rl$day <- as.numeric(ts) / 86400
    rl$mdate <- ifelse(is.na(ts), "(no date)", format(ts, "%Y-%m-%d"))
    rl <- rl[order(rl$trait, rl$unit, is.na(rl$day), rl$day), ]
    rep_long <- rl
    log_step("Repeated measurements: ", nrow(rl), " values of ", paste(short_trait(unique(rl$trait)), collapse = ", "))
  }
}
# full trait name of a recipe trait name (full or short)
match_trait <- function(x) {
  if (x %in% names(pheno)) return(x)
  m <- available_traits[short_trait(available_traits) == short_trait(x)]
  if (length(m)) m[1] else NA_character_
}
pheno_unit <- as.character(col_or(pheno, c("observationUnitName", "plotName"), NA))
rep_summary_fun <- function(v, day, how) {
  ok <- !is.na(day)
  switch(how,
    mean = mean(v), first = v[1], last = v[length(v)], max = max(v), min = min(v), sum = sum(v),
    auc = { if (sum(ok) < 2 || length(unique(day[ok])) < 2) NA_real_ else { x <- day[ok]; y <- v[ok]; o <- order(x); x <- x[o]; y <- y[o]; sum(diff(x) * (head(y, -1) + tail(y, -1)) / 2) } },
    slope = { if (sum(ok) < 2 || length(unique(day[ok])) < 2) NA_real_ else unname(coef(lm(v[ok] ~ day[ok]))[2]) },
    NA_real_)
}
rep_mode <- list()      # full trait -> "all" (traits modelled measurement by measurement)
repeated_info <- list() # reported with the results
rep_traits_cfg <- opt(rep_cfg, "traits", list())
for (key in names(rep_traits_cfg)) {
  how <- as.character(unlist(rep_traits_cfg[[key]]))[1]
  if (is.na(how) || !how %in% REP_SUMMARIES) { add_warning("Repeated measurements of '", short_trait(key), "': unknown summary '", how, "'; the plot mean was used."); next }
  if (how == "multi" && !requireNamespace("glmmTMB", quietly = TRUE)) {
    # the multi-trait model (each date a trait) needs glmmTMB in R
    add_warning(short_trait(key), ": the multi-trait model of repeated measurements needs the R package glmmTMB, which is not installed; its measurements were modelled with the repeated-measures model (all measurements) instead.")
    how <- "all"
  }
  full <- match_trait(key)
  if (is.na(full)) next     # not in this dataset: reported with the traits / covariates
  rl <- if (is.null(rep_long)) NULL else rep_long[rep_long$trait == full, ]
  if (is.null(rl) || !nrow(rl)) {
    if (how != "mean") add_warning(short_trait(full), " has a single measurement per plot in this dataset, so the '", REP_LABEL[[how]], "' setting for repeated measurements was not needed.")
    next
  }
  n_per <- table(rl$unit)
  info <- list(trait = short_trait(full), summary = how, label = REP_LABEL[[how]], n_plots = length(n_per),
               n_repeated_plots = sum(n_per > 1), n_measurements = nrow(rl), n_dates = n_levels(rl$mdate[rl$mdate != "(no date)"]),
               n_missing_summary = 0L)
  if (how == "all" || how == "multi") {
    rep_mode[[full]] <- how
  } else if (how != "mean") {
    vals <- vapply(split(seq_len(nrow(rl)), rl$unit), function(i) rep_summary_fun(rl$value[i], rl$day[i], how), numeric(1))
    new <- unname(vals[pheno_unit])
    had <- !is.na(suppressWarnings(as.numeric(pheno[[full]])))
    info$n_missing_summary <- sum(had & is.na(new))
    if (info$n_missing_summary > 0)
      add_warning(short_trait(full), ": ", info$n_missing_summary, " plot(s) have fewer than two dated measurements, so no ", REP_LABEL[[how]],
                  " could be computed; they were left out for this trait.")
    pheno[[full]] <- new
  }
  log_step("Repeated measurements of ", short_trait(full), ": ", REP_LABEL[[how]], " (", info$n_measurements, " measurements on ", info$n_plots, " plots)")
  repeated_info[[length(repeated_info) + 1]] <- info
}
# traits with repeated values and no setting: Breedbase plot means (reported)
if (!is.null(rep_long)) {
  done <- vapply(repeated_info, function(x) x$trait, "")
  for (full in unique(rep_long$trait)) {
    if (short_trait(full) %in% done || !(full %in% traits)) next
    rl <- rep_long[rep_long$trait == full, ]
    n_per <- table(rl$unit)
    repeated_info[[length(repeated_info) + 1]] <- list(trait = short_trait(full), summary = "mean", label = REP_LABEL[["mean"]], n_plots = length(n_per),
                                                       n_repeated_plots = sum(n_per > 1), n_measurements = nrow(rl),
                                                       n_dates = n_levels(rl$mdate[rl$mdate != "(no date)"]), n_missing_summary = 0L)
  }
}

for (t in traits) dat[[t]] <- suppressWarnings(as.numeric(pheno[[t]]))

# Covariates --------------------------------------------------------------------
# Any numeric column of the phenotype file (usually another trait measured on
# the same plots, with its repeated-measurement summary). Fixed linear effects
# of the stage 1 models (two stages) and of the single-stage model. A trait is
# never its own covariate. Older recipes keep them in single$covariates.
cov_list <- unlist(opt(recipe, "covariates", opt(opt(recipe, "single", list()), "covariates", list())))
cov_vars <- character()
cov_label <- character()     # cov_x -> trait display name
cov_full <- character()      # cov_x -> full trait name
for (cv in unique(cov_list)) {
  full <- match_trait(cv)
  if (is.na(full)) { add_warning("Covariate '", short_trait(cv), "' is not in this dataset and was skipped."); next }
  vn <- cov_name(full)
  dat[[vn]] <- suppressWarnings(as.numeric(pheno[[full]]))
  if (!any(!is.na(dat[[vn]]))) { add_warning("Covariate '", short_trait(cv), "' has no numeric values and was skipped."); next }
  cov_vars <- c(cov_vars, vn)
  cov_label[[vn]] <- short_trait(full)
  cov_full[[vn]] <- full
}
if (length(cov_vars)) log_step("Covariates: ", paste(cov_label, collapse = ", "))
for (k in names(treatment_factors)) dat[[k]] <- treatment_factors[[k]]$values
if (length(treatment_factors)) log_step("Treatments: ", paste(vapply(treatment_factors, function(f) paste0(f$name, " (", length(unique(f$values)), " levels)"), ""), collapse = ", "),
                                        "; in the models: ", if (length(c(trt_use, trt_gxt))) paste(unique(c(trt_use, trt_gxt)), collapse = ", ") else "none")
traits <- traits[vapply(traits, function(t) sum(!is.na(dat[[t]])) > 0, logical(1))]
if (length(traits) == 0) stop("None of the selected traits has numeric data in this dataset. Available traits: ", paste(short_trait(available_traits), collapse = ", "))
log_step("Traits: ", paste(short_trait(traits), collapse = ", "))

# -----------------------------------------------------------------------------
# Design detection per trial
# -----------------------------------------------------------------------------

detect_trial_design <- function(d, sp = NULL) {
  txt <- tolower(paste(unique(d$design_raw[!is.na(d$design_raw)]), collapse = " "))
  n_rep <- n_levels(d$rep)
  n_block <- n_levels(d$block)
  has_rowcol <- sum(!is.na(d$row) & !is.na(d$col)) >= 0.9 * nrow(d) && n_levels(d$row) > 1 && n_levels(d$col) > 1
  block_ne_rep <- n_rep > 0 && n_block > 0 && any(d$block != d$rep, na.rm = TRUE)
  replicated <- any(table(d$accession) > 1)
  # with the factor support (factor_support()): a replicate only counts when
  # the test entries are repeated across replicates, a block only when blocks
  # are linked by common entries
  rep_ok <- if (is.null(sp)) n_rep > 1 else sp$rep$ok
  block_ok <- if (is.null(sp)) n_block > 1 else sp$block$ok
  entries_rep <- if (is.null(sp)) replicated else sp$entries_replicated

  design <- if (grepl("row.?col|rowcol|spatial|p-rep|prep", txt)) {
    "row_column"
  } else if (grepl("augmented|madii|\\bmad\\b|aug", txt) || (!entries_rep && replicated && block_ok)) {
    "augmented"
  } else if (grepl("alpha|lattice|incomplete", txt) || (rep_ok && block_ok && n_block > n_rep && block_ne_rep)) {
    "alpha_lattice"
  } else if (grepl("rcbd|randomized complete block|randomised complete block", txt) || rep_ok) {
    "rcbd"
  } else if (grepl("crd|completely random", txt) || replicated) {
    "crd"
  } else {
    "unreplicated"
  }
  if (!replicated && design != "augmented") design <- "unreplicated"

  list(design = design, has_rowcol = has_rowcol, n_rep = n_rep, n_block = n_block,
       design_label = c(row_column = "Row-column", augmented = "Augmented", alpha_lattice = "Alpha-lattice",
                        rcbd = "RCBD", crd = "CRD", unreplicated = "Unreplicated")[[design]])
}

# The "replicate" factor of a RCBD sometimes lives in the block column (one
# replicate, several blocks). Build a coherent replicate factor.
effective_rep <- function(d) {
  if (n_levels(d$rep) > 1) return(as.character(d$rep))
  if (n_levels(d$block) > 1) return(as.character(d$block))
  rep("1", nrow(d))
}

trials <- sort(unique(dat$trial))
trial_info <- lapply(trials, function(tr) {
  d <- dat[dat$trial == tr, ]
  di <- detect_trial_design(d)
  override <- opt(opt(opt(recipe, "stage1", list()), "design_overrides", list()), tr, NULL)
  if (!is.null(override) && override != "auto" && override != "") di$design <- override
  di$trial <- tr
  di$location <- d$location[1]
  di$year <- d$year[1]
  di$n_plots <- nrow(d)
  di$n_accessions <- n_levels(d$accession)
  di
})
names(trial_info) <- trials

# Environment (zoning unit) --------------------------------------------------
zones_cfg <- opt(recipe, "zones", list())
env_unit <- opt(zones_cfg, "unit", "trial")
dat$env <- if (env_unit == "location") dat$location else if (env_unit == "location_year") paste(dat$location, dat$year) else dat$trial

# -----------------------------------------------------------------------------
# Step 2 - outliers
# -----------------------------------------------------------------------------
out_cfg <- opt(recipe, "outliers", list())
out_method <- opt(out_cfg, "method", "none")
out_group <- opt(out_cfg, "group_by", "trial")
iqr_k <- as.numeric(opt(out_cfg, "k", 1.5))
madr_alpha <- as.numeric(opt(out_cfg, "alpha", 0.05))

outlier_rows <- list()
flag_outlier <- function(idx, trait, reason, value = dat[[trait]][idx]) {
  if (length(idx) == 0) return(invisible())
  outlier_rows[[length(outlier_rows) + 1]] <<- data.frame(
    unit = dat$unit[idx], trial = dat$trial[idx], accession = dat$accession[idx],
    trait = trait, value = value, reason = reason, stringsAsFactors = FALSE)
}

# Per trait: the side the rules flag (outliers$side: "high" | "low", default
# both) and, for traits measured several times per plot, the value per plot
# the rules judge (outliers$view: mean | sum | first | last, default mean),
# which may differ from the value the model uses (repeated$traits).
per_trait_opt <- function(name, allowed) {
  h <- opt(out_cfg, name, list())
  out <- list()
  for (key in names(h)) {
    full <- match_trait(key)
    v <- as.character(unlist(h[[key]]))[1]
    if (!is.na(full) && !is.na(v) && v %in% allowed) out[[full]] <- v
  }
  out
}
out_side <- per_trait_opt("side", c("high", "low"))
out_view <- per_trait_opt("view", c("mean", "sum", "first", "last", "max", "min"))
is_rep_trait <- function(t) !is.null(rep_long) && any(rep_long$trait == t)
# values the rules judge for trait t, aligned with the rows of dat
judged_values <- function(t) {
  y <- dat[[t]]
  if (!is_rep_trait(t)) return(y)
  how <- if (is.null(out_view[[t]])) "mean" else out_view[[t]]
  rl <- rep_long[rep_long$trait == t, ]
  vals <- vapply(split(seq_len(nrow(rl)), rl$unit), function(i) rep_summary_fun(rl$value[i], rl$day[i], how), numeric(1))
  v <- unname(vals[as.character(dat$unit)])
  ifelse(is.na(y), NA_real_, ifelse(is.na(v), y, v))
}
keep_side <- function(t, high) {
  s <- out_side[[t]]
  if (is.null(s)) rep(TRUE, length(high)) else if (s == "high") high else !high
}
how_text <- function(t) {
  w <- character()
  if (!is.null(out_side[[t]])) w <- c(w, paste(out_side[[t]], "values only"))
  if (is_rep_trait(t)) {
    how <- if (is.null(out_view[[t]])) "mean" else out_view[[t]]
    w <- c(w, paste0("judged on the ", if (how == "mean") "plot mean" else REP_LABEL[[how]], " of the repeated measurements"))
  }
  if (length(w)) paste0(", ", paste(w, collapse = ", ")) else ""
}

group_vector <- function(by) {
  switch(by,
    trial = dat$trial,
    trial_rep = paste(dat$trial, effective_rep_all),
    trial_accession = paste(dat$trial, dat$accession),
    all = rep("all", nrow(dat)),
    dat$trial)
}
effective_rep_all <- character(nrow(dat))
for (tr in trials) { ii <- which(dat$trial == tr); effective_rep_all[ii] <- effective_rep(dat[ii, ]) }
dat$rep_eff <- effective_rep_all

# -----------------------------------------------------------------------------
# Factor support ("smart block"): before any model is built, every design
# factor of a trial is checked against the data. A factor the data cannot
# support is switched off for that trial (one level), so no model uses it:
# stage 1, SpATS, BH-MADR, the single-stage builder and custom formulas.
# Same rules as _factor_support() in SGN::Controller::AJAX::ScriptFactory
# (shown in the page before the run).
#   rep    a typical test entry (checks excluded) is in >= 2 replicates;
#          replicated checks alone do not make a replicate factor
#   block  blocks subdivide the replicates (more blocks than replicates,
#          >= 2 plots per block) and some entry is in more than one block
#          (otherwise block effects cannot be separated from genotypes)
#   row,   row / column numbers on >= 90% of the plots, >= 2 levels, >= 2
#   col    plots per level, and not the same grouping as replicate or block
# -----------------------------------------------------------------------------
same_grouping <- function(a, b) {
  k <- !is.na(a) & !is.na(b)
  a <- a[k]; b <- b[k]
  length(a) > 0 && n_levels(a) == n_levels(b) && n_levels(paste(a, b)) == n_levels(a)
}

factor_support <- function(d) {
  yes <- list(ok = TRUE, why = "")
  no <- function(why) list(ok = FALSE, why = why)
  test <- d$check != "check"
  if (!any(test)) test <- rep(TRUE, nrow(d))
  reps_per_entry <- tapply(d$rep_eff[test], d$accession[test], function(v) length(unique(v)))
  copies_per_entry <- as.numeric(table(d$accession[test]))
  checks_repeated <- any(table(d$accession[!test]) > 1)
  sp <- list(entries_replicated = median(copies_per_entry) >= 2)

  sp$rep <- if (n_levels(d$rep_eff) < 2) no("one replicate") else if (median(reps_per_entry) < 2)
    no(paste0("the test entries are in one replicate only", if (checks_repeated) ", only the checks are repeated" else "")) else yes
  rep_used <- if (sp$rep$ok) d$rep_eff else rep("1", nrow(d))

  has_b <- !is.na(d$block) & d$block != ""
  bid <- ifelse(has_b, paste(rep_used, d$block), NA)
  sp$block <- if (n_levels(d$block) < 2) no("one block") else
    if (n_levels(bid) <= n_levels(rep_used)) no("the blocks are the replicates") else
    if (sum(has_b) / n_levels(bid) < 2) no("one plot per block") else
    if (!any(tapply(bid[has_b], d$accession[has_b], function(v) length(unique(v))) > 1))
      no("no entry is in more than one block, so block effects cannot be separated from the genotypes") else yes
  blk_used <- if (sp$block$ok) bid else rep(NA, nrow(d))

  rc <- sum(!is.na(d$row) & !is.na(d$col)) >= 0.9 * nrow(d)
  for (f in c("row", "col")) {
    x <- d[[f]]
    nm <- if (f == "row") "row" else "column"
    sp[[f]] <- if (!rc || n_levels(x) < 2) no(paste0("no ", nm, " numbers")) else
      if (sum(!is.na(x)) / n_levels(x) < 2) no(paste0("one plot per ", nm)) else
      if (sp$rep$ok && same_grouping(ifelse(is.na(x), NA, paste(rep_used, x)), rep_used)) no(paste0("each ", nm, " is a replicate")) else
      if (sp$block$ok && same_grouping(ifelse(is.na(x), NA, paste(rep_used, x)), blk_used)) no(paste0("each ", nm, " is a block")) else yes
  }
  sp
}

FACTOR_LABEL <- c(rep = "Replicate", block = "Block", row = "Row", col = "Column")
dat$row_off <- FALSE
dat$col_off <- FALSE
for (tr in trials) {
  ii <- which(dat$trial == tr)
  d <- dat[ii, ]
  sp <- factor_support(d)
  trial_info[[tr]]$support <- sp
  # re-detect the design with the support (an override still wins)
  di <- detect_trial_design(d, sp)
  override <- opt(opt(opt(recipe, "stage1", list()), "design_overrides", list()), tr, NULL)
  if (is.null(override) || override == "auto" || override == "") {
    trial_info[[tr]]$design <- di$design
    trial_info[[tr]]$design_label <- di$design_label
  }
  # switch off what the data cannot support; report only factors that were
  # really recorded (a single replicate or block needs no warning)
  if (!sp$rep$ok) dat$rep_eff[ii] <- "1"
  if (!sp$block$ok) dat$block[ii] <- "0"   # one level: no block effect in this trial
  for (f in c("row", "col")) if (!sp[[f]]$ok) dat[[paste0(f, "_off")]][ii] <- TRUE
  off <- Filter(function(f) !sp[[f]]$ok && !grepl("^(one replicate|one block|no row|no column|the blocks are the replicates)", sp[[f]]$why), names(FACTOR_LABEL))
  if (length(off)) add_warning(tr, ": not used as model factor(s): ", paste0(tolower(FACTOR_LABEL[off]), " (", vapply(off, function(f) sp[[f]]$why, ""), ")", collapse = "; "), ".")
}

n_before <- sapply(traits, function(t) sum(!is.na(dat[[t]])))

if (out_method == "iqr") {
  g <- group_vector(out_group)
  for (t in traits) {
    y <- judged_values(t)
    for (lvl in unique(g)) {
      ii <- which(g == lvl & !is.na(y))
      if (length(ii) < 4) next
      q <- quantile(y[ii], c(0.25, 0.75), type = 7, names = FALSE)
      iqr <- q[2] - q[1]
      lo <- q[1] - iqr_k * iqr
      hi <- q[2] + iqr_k * iqr
      bad <- ii[(y[ii] > hi & keep_side(t, TRUE)) | (y[ii] < lo & keep_side(t, FALSE))]
      flag_outlier(bad, t, paste0(sprintf("IQR (k = %.2g) within %s", iqr_k, gsub("_", " x ", out_group)), how_text(t)), y[bad])
      dat[[t]][bad] <- NA
    }
  }
} else if (out_method == "madr") {
  # Bernal-Vasquez, Utz & Piepho (2016): Bonferroni-Holm test on residuals
  # re-scaled by the median absolute deviation (BH-MADR).
  for (t in traits) {
    yj <- judged_values(t)
    for (tr in trials) {
      ii <- which(dat$trial == tr & !is.na(yj))
      d <- dat[ii, ]
      if (nrow(d) < 6 || n_levels(d$accession) < 2) next
      fml <- if (n_levels(d$rep_eff) > 1) y ~ accession + rep_eff else y ~ accession
      d$y <- yj[ii]
      fit <- tryCatch(lm(fml, data = d), error = function(e) NULL)
      if (is.null(fit) || df.residual(fit) < 2) next
      r <- residuals(fit)
      # entries with a single plot have a residual of zero by construction (up
      # to rounding): they neither enter the MAD nor can be tested
      inf <- as.numeric(table(d$accession)[as.character(d$accession)]) > 1
      if (sum(inf) < 3) next
      madv <- mad(r[inf], constant = 1.4826)
      if (!is.finite(madv) || madv <= 1e-8 * max(sd(d$y), 1e-300)) next
      z <- r[inf] / madv
      p <- 2 * pnorm(-abs(z))
      # the side of a value: above (positive residual) or below what the model expects
      bad <- ii[inf][p.adjust(p, "holm") < madr_alpha & keep_side(t, r[inf] > 0)]
      flag_outlier(bad, t, paste0(sprintf("BH-MADR (alpha = %.2g)", madr_alpha), how_text(t)), yj[bad])
      dat[[t]][bad] <- NA
    }
  }
}

# individual exclusions chosen in the interface
if (!is.na(exclusions_file) && file.exists(exclusions_file)) {
  ex <- fromJSON(exclusions_file, simplifyVector = TRUE)
  if (length(ex) > 0 && is.data.frame(ex) && nrow(ex) > 0) {
    for (k in seq_len(nrow(ex))) {
      tt <- if (is.null(ex$trait) || is.na(ex$trait[k]) || ex$trait[k] == "") traits else intersect(ex$trait[k], traits)
      ii <- which(dat$unit == ex$unit[k])
      # values marked as outliers in Breedbase, pre-excluded in step 2
      src <- if (is.null(ex$source)) NA_character_ else ex$source[k]
      reason <- switch(if (is.na(src)) "" else src,
                       dataset = "Marked as dataset outlier in Breedbase",
                       database = "Marked as database outlier in Breedbase",
                       both = "Marked as dataset and database outlier in Breedbase",
                       "Excluded individually")
      for (t in tt) {
        bad <- ii[!is.na(dat[[t]][ii])]
        flag_outlier(bad, t, reason)
        dat[[t]][bad] <- NA
      }
    }
  }
}

outliers <- if (length(outlier_rows)) do.call(rbind, outlier_rows) else
  data.frame(unit = character(), trial = character(), accession = character(), trait = character(), value = numeric(), reason = character())

outlier_summary <- do.call(rbind, lapply(traits, function(t) {
  data.frame(trait = short_trait(t), n_observations = unname(n_before[t]),
             n_removed = sum(outliers$trait == t),
             pct_removed = round(100 * sum(outliers$trait == t) / max(1, n_before[t]), 2))
}))
outliers$trait <- short_trait(outliers$trait)

if (identical(opt(recipe, "stop_after", ""), "outliers")) {
  writeLines(toJSON(list(outliers = outliers, outlier_summary = outlier_summary, warnings = warnings_log),
                    dataframe = "rows", na = "null", auto_unbox = TRUE, digits = 8), output_file)
  quit(save = "no", status = 0)
}

# -----------------------------------------------------------------------------
# Helpers for models
# -----------------------------------------------------------------------------
var_comp <- function(fit) {
  vc <- as.data.frame(VarCorr(fit))
  setNames(vc$vcov, vc$grp)
}

# Terms of a fitted lme4 / lm model the data could not estimate. lme4 drops
# rank-deficient fixed-effect columns and fits a zero variance to random terms
# it cannot separate (e.g. trial:rep when each trial has one rep) with only a
# message, which fit_quietly muffles; lm leaves those coefficients NA. Returns
# readable notes so they reach the run warnings instead of passing silently.
inestimable_terms <- function(m) {
  notes <- character()
  mf <- tryCatch(model.frame(m), error = function(e) NULL)
  if (is.null(mf)) return(notes)
  # fixed effects
  nobars_fn <- if (requireNamespace("reformulas", quietly = TRUE)) reformulas::nobars else lme4::nobars
  fx_fml <- if (inherits(m, "merMod")) nobars_fn(formula(m)) else formula(m)
  X <- tryCatch(model.matrix(fx_fml, mf), error = function(e) NULL)
  dropped <- if (inherits(m, "merMod")) unname(attr(getME(m, "X"), "col.dropped")) else which(is.na(coef(m)))
  if (!is.null(X) && length(dropped)) {
    labels <- attr(terms(fx_fml), "term.labels")
    asg <- attr(X, "assign")
    for (k in sort(unique(asg[dropped]))) {
      if (k == 0) next
      n_all <- sum(asg == k)
      n_out <- sum(asg[dropped] == k)
      notes <- c(notes, if (n_out == n_all) paste0("fixed term ", labels[k], " could not be estimated (confounded with other terms) and was dropped")
                        else paste0(n_out, " of ", n_all, " effects of fixed term ", labels[k], " could not be estimated (confounded with other terms) and were dropped"))
    }
  }
  # random effects: a grouping factor with the same levels as another term of
  # the model is not identifiable (lme4 still splits the variance between the
  # two, arbitrarily); otherwise a zero variance means it had no effect
  if (inherits(m, "merMod")) {
    vc <- as.data.frame(VarCorr(m))
    vc <- vc[vc$grp != "Residual" & is.na(vc$var2), , drop = FALSE]
    total <- sum(vc$vcov) + sigma(m)^2
    fl <- getME(m, "flist")
    fx_factors <- intersect(attr(terms(fx_fml), "term.labels"), names(mf)[vapply(mf, function(x) is.factor(x) || is.character(x), logical(1))])
    cands <- c(lapply(setNames(fx_factors, fx_factors), function(o) factor(mf[[o]])), lapply(fl, factor))
    reported <- character()
    for (i in seq_len(nrow(vc))) {
      g <- vc$grp[i]
      if (is.null(fl[[g]])) next
      gf <- factor(fl[[g]])
      same <- names(cands)[!(names(cands) %in% c(g, reported)) & vapply(cands, function(f) nlevels(f) == nlevels(gf) && nlevels(interaction(gf, f, drop = TRUE)) == nlevels(gf), logical(1))]
      if (length(same)) reported <- c(reported, g)
      if (length(same)) notes <- c(notes, paste0("random term ", g, " cannot be separated from ", same[1], " (one ", sub(".*:", "", g), " level per ", same[1],
                                                 "), so its variance is not estimable; remove it from the model"))
      else if (is.finite(vc$vcov[i]) && vc$vcov[i] <= 1e-8 * total)
        notes <- c(notes, paste0("random term ", g, " was estimated with zero variance, so it has no effect on the results"))
      if (length(same)) next
      # design factors switched off per trial are already reported by the factor gate
      if (grepl("(^|:|_)(rep|block|row|col)$", g)) next
      # partly confounded: nested in an environment term, with a single level
      # in some environments (e.g. trial:rep and an unreplicated trial)
      for (f in intersect(c("trial", "location", "year"), setdiff(names(cands), g))) {
        ff <- cands[[f]]
        if (nlevels(interaction(gf, ff, drop = TRUE)) != nlevels(gf)) next   # not nested in f
        n_in <- tapply(gf, ff, function(x) length(unique(x)))
        one <- names(n_in)[!is.na(n_in) & n_in == 1]
        if (!length(one)) next
        notes <- c(notes, paste0("random term ", g, " has a single level in ", length(one), " of ", length(n_in), " ", f, "(s) (",
                                 paste(head(one, 5), collapse = ", "), if (length(one) > 5) ", ...", "): there it cannot be separated from ", f,
                                 ", so only the other ", f, "s estimate its variance"))
        break
      }
    }
  }
  notes
}

# adjusted means (BLUEs) of accessions from a model with accession as fixed effect
accession_blues <- function(fit, d) {
  acc_levels <- levels(d$accession)
  X <- if (inherits(fit, "merMod")) getME(fit, "X") else model.matrix(fit)
  beta <- if (inherits(fit, "merMod")) fixef(fit) else coef(fit)
  # vcov() of a degenerate lme4 fit (no error variance) fails; keep the
  # estimates and report missing standard errors instead
  V <- tryCatch(suppressWarnings(as.matrix(vcov(fit))), error = function(e) NULL)
  if (!is.null(V) && any(!is.finite(V))) V <- NULL
  keep <- !is.na(beta)
  beta <- beta[keep]; X <- X[, keep, drop = FALSE]
  if (!is.null(V)) V <- V[names(beta), names(beta), drop = FALSE]
  cn <- colnames(X)
  acc_cols <- paste0("accession", acc_levels)
  # columns of interactions with the accession (accession:trial, ...)
  inter <- !(cn %in% acc_cols) & grepl("(^|:)accession", cn)
  if (!any(inter)) {
    # average the non-accession columns over the data
    other <- setdiff(cn, c("(Intercept)", acc_cols))
    base <- setNames(rep(0, length(cn)), cn)
    base["(Intercept)"] <- 1
    if (length(other)) base[other] <- colMeans(X[, other, drop = FALSE])
    L <- t(sapply(acc_levels, function(a) {
      l <- base
      col <- paste0("accession", a)
      if (col %in% cn) l[col] <- 1
      l
    }))
  } else {
    # with interactions, each accession is predicted over the observed
    # combinations of the other model variables (weighted by their frequency in
    # the data), so its interaction columns hold its own effects only
    # (emmeans-like); averaging those columns over all rows would mix in the
    # interaction effects of the other accessions
    tt <- delete.response(if (inherits(fit, "merMod")) terms(fit, fixed.only = TRUE) else terms(fit))
    vars <- setdiff(all.vars(tt), "accession")
    mf <- d[, vars, drop = FALSE]
    key <- if (length(vars)) do.call(paste, c(lapply(mf, as.character), sep = "\r")) else rep("1", nrow(d))
    first <- !duplicated(key)
    combos <- mf[first, , drop = FALSE]
    w <- as.numeric(table(factor(key, levels = key[first]))) / length(key)
    xlev <- lapply(d[, c("accession", vars), drop = FALSE], function(x) if (is.numeric(x)) NULL else levels(factor(x)))
    xlev <- xlev[!vapply(xlev, is.null, logical(1))]
    ctr <- attr(if (inherits(fit, "merMod")) getME(fit, "X") else model.matrix(fit), "contrasts")
    L <- t(vapply(acc_levels, function(a) {
      newdata <- combos; newdata$accession <- factor(a, levels = acc_levels)
      M <- model.matrix(tt, model.frame(tt, newdata, xlev = xlev), contrasts.arg = ctr)
      out <- setNames(numeric(length(cn)), cn)
      hit <- intersect(cn, colnames(M))
      out[hit] <- colSums(M[, hit, drop = FALSE] * w)
      out
    }, numeric(length(cn))))
  }
  est <- as.vector(L %*% beta)
  se <- if (is.null(V)) rep(NA_real_, length(est)) else sqrt(pmax(0, rowSums((L %*% V) * L)))
  data.frame(accession = acc_levels, value = est, se = se, stringsAsFactors = FALSE)
}

fit_quietly <- function(expr) {
  withCallingHandlers(
    tryCatch(expr, error = function(e) e),
    warning = function(w) invokeRestart("muffleWarning"),
    message = function(m) invokeRestart("muffleMessage"))
}

# -----------------------------------------------------------------------------
# Model engine
# -----------------------------------------------------------------------------
# This script fits every model in R (lme4, SpATS). The BLUPF90+ engine of the
# Analysis Pipeline is not part of it: Breedbase runs recipes with
# "engine": "blupf90" (and pedigree models) without R, in the Perl library
# CXGN::BLUPF90 (bin/script_factory_blupf90.pl).
engine <- opt(recipe, "engine", "lme4")
if (!identical(engine, "lme4")) {
  add_warning("The BLUPF90+ engine runs in Breedbase (CXGN::BLUPF90), not in this R script; the models were fitted with lme4 instead.")
  engine <- "lme4"
}

# -----------------------------------------------------------------------------
# Genetic model and model fitting shared by stage 2 and the single stage
# -----------------------------------------------------------------------------
gen_cfg <- opt(recipe, "genetic", list())
gen_model <- opt(gen_cfg, "model", "iid")      # iid | parents | pedigree | genomic | single_step
check_opt <- opt(gen_cfg, "check", "auto")     # auto | fixed | none
if (!gen_model %in% c("iid", "parents", "pedigree", "genomic", "single_step")) gen_model <- "iid"
REL_LABEL <- c(pedigree = "pedigree (A matrix)", genomic = "genomic (G matrix)", single_step = "single-step (H matrix)")
if (gen_model %in% c("parents", "pedigree")) {
  n_known <- if (is.null(pedigree)) 0 else sum(unique(dat$accession) %in% pedigree$accession[!is.na(pedigree$mother) | !is.na(pedigree$father)])
  if (n_known == 0) {
    add_warning("No accession of this dataset has known parents, so the ", if (gen_model == "pedigree") "pedigree (A matrix)" else "mother / father", " model could not be used; accessions were treated as unrelated.")
    gen_model <- "iid"
  } else log_step("Genetic model: ", gen_model, " (", n_known, " accessions with known parents)")
}

# Relationship matrices in R (AGHmatrix): A from the pedigree (with
# inbreeding), G from the marker dosages (VanRaden, after the MAF and call
# rate filters; blended 0.95 G + 0.05 A22 so it can be inverted, as BLUPF90+
# does), H from A and G (single step; Martini et al. 2018 with tau = omega = 1).
# The models then use the relationship through the Cholesky factor of the
# matrix (lme4, as pedigreemm does).
rel_K <- NULL         # relationship matrix over all individuals (data + ancestors)
rel_kind <- ""        # A | G | H
rel_info <- list()
ped_order <- function(pg) {
  # parents before their offspring; parents missing from the pedigree become founders
  ids <- unique(c(pg$accession, pg$mother[!is.na(pg$mother)], pg$father[!is.na(pg$father)]))
  mo <- setNames(pg$mother[match(ids, pg$accession)], ids); fa <- setNames(pg$father[match(ids, pg$accession)], ids)
  depth <- setNames(rep(NA_integer_, length(ids)), ids)
  get_depth <- function(i, seen = character()) {
    if (!is.na(depth[[i]])) return(depth[[i]])
    if (i %in% seen) return(0L)      # loop in the pedigree: cut it
    p <- c(mo[[i]], fa[[i]]); p <- p[!is.na(p)]
    d <- if (length(p)) 1L + max(vapply(p, get_depth, integer(1), seen = c(seen, i))) else 0L
    depth[[i]] <<- d; d
  }
  for (i in ids) get_depth(i)
  ids <- ids[order(depth[ids])]
  data.frame(id = ids, mother = ifelse(is.na(mo[ids]), "0", mo[ids]), father = ifelse(is.na(fa[ids]), "0", fa[ids]), stringsAsFactors = FALSE)
}
build_A <- function() {
  ped <- ped_order(pedigree)
  A <- AGHmatrix::Amatrix(ped, ploidy = 2)
  rel_info$n_pedigree <<- nrow(ped)
  rel_info$inbreeding_mean <<- mean(diag(A) - 1)
  A
}
read_dosages <- function(f) {
  g <- read.delim(f, header = TRUE, sep = "\t", quote = "", comment.char = "", check.names = FALSE, stringsAsFactors = FALSE)
  M <- as.matrix(g[, -1, drop = FALSE]); storage.mode(M) <- "numeric"
  rownames(M) <- as.character(g[[1]])
  M <- M[rownames(M) %in% unique(dat$accession) | (!is.null(pedigree) & rownames(M) %in% pedigree$accession), , drop = FALSE]
  M
}
build_G <- function(Afull = NULL) {
  M <- read_dosages(genotypes_file)
  if (nrow(M) < 2) stop("fewer than two accessions of the dataset have genotypes")
  minfreq <- as.numeric(opt(gen_cfg, "minfreq", 0.05)); callrate <- as.numeric(opt(gen_cfg, "callrate", 0.90))
  cr <- colMeans(!is.na(M)); p <- colMeans(M, na.rm = TRUE) / 2; maf <- pmin(p, 1 - p)
  keep <- cr >= callrate & is.finite(maf) & maf >= minfreq
  rel_info$n_snps <<- ncol(M); rel_info$n_snps_used <<- sum(keep); rel_info$n_genotyped <<- nrow(M)
  if (sum(keep) < 2) stop("no marker passed the minor allele frequency and call rate filters")
  M <- M[, keep, drop = FALSE]; M[is.na(M)] <- -9
  G <- AGHmatrix::Gmatrix(SNPmatrix = M, method = "VanRaden", missingValue = -9, maf = 0, ploidy = 2)
  ids <- rownames(M)
  dimnames(G) <- list(ids, ids)
  A22 <- diag(length(ids)); dimnames(A22) <- list(ids, ids)
  if (!is.null(Afull)) {
    inA <- ids[ids %in% rownames(Afull)]; A22[inA, inA] <- Afull[inA, inA]
    # single step: G on the scale of the pedigree (as BLUPF90+ tunedG 2):
    # G* = a + b G with the mean diagonal and mean off-diagonal of A22
    up <- upper.tri(G)
    b <- (mean(diag(A22)) - mean(A22[up])) / (mean(diag(G)) - mean(G[up]))
    G <- (mean(A22[up]) - b * mean(G[up])) + b * G
  }
  0.95 * G + 0.05 * A22
}
if (gen_model %in% c("pedigree", "genomic", "single_step")) {
  rel <- tryCatch({
    if (!requireNamespace("AGHmatrix", quietly = TRUE)) stop("the R package AGHmatrix is not installed (or choose the BLUPF90+ engine)")
    if (gen_model %in% c("genomic", "single_step") && (is.na(genotypes_file) || !file.exists(genotypes_file) || !file.info(genotypes_file)$size))
      stop("the genotypes of the genotyping protocol could not be retrieved")
    if (gen_model == "single_step" && (is.null(pedigree) || !any(!is.na(pedigree$mother) | !is.na(pedigree$father)))) {
      add_warning("No accession has known parents, so the single-step (H) model is the genomic (G) model here.")
      gen_model <- "genomic"
    }
    if (gen_model == "pedigree") list(K = build_A(), kind = "A")
    else if (gen_model == "genomic") {
      G <- build_G()
      miss <- setdiff(unique(dat$accession), rownames(G))
      rel_info$n_without <- length(miss)
      if (length(miss)) {
        add_warning(length(miss), " accession(s) have no genotypes in the genotyping protocol; in the genomic (G) model they are treated as unrelated.")
        K <- as.matrix(Matrix::bdiag(G, diag(length(miss)))); dimnames(K) <- list(c(rownames(G), miss), c(rownames(G), miss))
      } else K <- G
      list(K = K, kind = "G")
    } else {
      A <- build_A()
      G <- build_G(A)
      add_ped <- setdiff(rownames(G), rownames(A))
      if (length(add_ped)) {   # genotyped but not in the pedigree: founders
        nm <- c(rownames(A), add_ped)
        A <- as.matrix(Matrix::bdiag(A, diag(length(add_ped)))); dimnames(A) <- list(nm, nm)
      }
      H <- AGHmatrix::Hmatrix(A = A, G = G, method = "Martini", tau = 1, omega = 1, ploidy = 2)
      if (is.null(rownames(H))) dimnames(H) <- dimnames(A)
      list(K = H, kind = "H")
    }
  }, error = function(e) e)
  if (inherits(rel, "error")) {
    add_warning("The ", REL_LABEL[[gen_model]], " model could not be built in R (", conditionMessage(rel), "); accessions were treated as unrelated.")
    gen_model <- "iid"
  } else {
    rel_K <- rel$K; rel_kind <- rel$kind
    log_step("Relationship matrix ", rel_kind, " (AGHmatrix): ", nrow(rel_K), " individuals")
  }
}

# Cholesky factor of the relationship of the given levels (a small ridge keeps
# it positive definite)
rel_chol <- function(lv) {
  K <- rel_K[lv, lv, drop = FALSE]
  t(chol(K + diag(1e-6 * mean(diag(K)), nrow(K))))
}

# lme4 fit with the accession effect following the relationship: u = L v,
# v ~ N(0, s2 I), so Z is replaced by Z L (pedigreemm's approach). Returns the
# merMod, the factor and the levels.
lmer_rel <- function(fml, d) {
  lf <- lFormula(fml, data = d, weights = .w, REML = TRUE)
  k <- which(names(lf$reTrms$cnms) == "accession")
  if (length(k) != 1) stop("the accession term was not found")
  lv <- levels(lf$reTrms$flist[[k]])
  Lk <- rel_chol(lv)
  idx <- (lf$reTrms$Gp[k] + 1):lf$reTrms$Gp[k + 1]
  Zt <- lf$reTrms$Zt
  Zt[idx, ] <- Matrix::crossprod(Matrix::Matrix(Lk, sparse = TRUE), Zt[idx, , drop = FALSE])
  lf$reTrms$Zt <- Zt
  devfun <- do.call(mkLmerDevfun, lf)
  opt <- optimizeLmer(devfun)
  m <- mkMerMod(environment(devfun), opt, lf$reTrms, fr = lf$fr)
  list(m = m, Lk = Lk, lv = lv, idx = idx, k = k)
}
acc_is_check <- tapply(dat$check == "check", dat$accession, any)

# Fit 'y ~ ...' (lme4 syntax) with the engine of the recipe and the genetic
# model. Returns genotype values, variance components (lme4 names),
# residuals, the solutions of every random effect, ancestors' breeding values
# (pedigree model) and notes.
fit_model <- function(d, fml_txt, genotype_random, w = NULL, label = "model") {
  rhs <- sub("^\\s*y\\s*~", "", fml_txt)
  has_random <- grepl("\\|", rhs)
  notes <- character()
  fit <- NULL
  if (is.null(fit)) {
    # lme4 / lm; unknown parents become one '(unknown)' level
    for (v in intersect(c("mother", "father"), all.vars(as.formula(fml_txt)))) d[[v]] <- ifelse(is.na(d[[v]]), "(unknown)", d[[v]])
    fml <- as.formula(fml_txt)
    d$.w <- if (is.null(w)) rep(1, nrow(d)) else w
    use_rel <- genotype_random && !is.null(rel_K) && grepl("\\(1\\s*\\|\\s*accession\\s*\\)", rhs) && all(unique(as.character(d$accession)) %in% rownames(rel_K))
    rf <- NULL
    m <- if (use_rel) { rf <- fit_quietly(lmer_rel(fml, d)); if (inherits(rf, "error")) rf else rf$m }
         else if (has_random) fit_quietly(lmer(fml, data = d, weights = .w, REML = TRUE)) else fit_quietly(lm(fml, data = d, weights = .w))
    if (inherits(m, "error")) stop(conditionMessage(m))
    vc <- if (inherits(m, "merMod")) var_comp(m) else c(Residual = summary(m)$sigma^2)
    random <- list()
    if (inherits(m, "merMod")) {
      re <- ranef(m, condVar = TRUE)
      for (k in names(re)) {
        pv <- attr(re[[k]], "postVar")
        random[[k]] <- data.frame(level = rownames(re[[k]]), solution = re[[k]][, 1],
                                  se = if (!is.null(pv)) sqrt(pv[1, 1, ]) else NA_real_, stringsAsFactors = FALSE)
      }
    }
    ancestors_df <- NULL
    if (genotype_random && use_rel) {
      # u = L v: values and prediction error (co)variances from the full
      # coefficient matrix (fixed and random effects, as BLUPF90+): with a
      # relationship the accession effects share ancestors with the trial
      # means, so the uncertainty of the fixed effects must be included.
      # C = [X'WX, X'WZL; L'Z'WX, L'Z'WZL + I] (Lambda form), PEV(v) = s2 theta^2 [C^-1]_vv
      fp <- predict(m, re.form = NA)
      mu <- mean(tapply(fp, d$trial, mean))
      v <- ranef(m)[["accession"]][rf$lv, 1]
      u <- as.numeric(rf$Lk %*% v)
      th <- getME(m, "theta")[[grep("^accession\\.", names(getME(m, "theta")))[1]]]
      X <- getME(m, "X"); wv <- weights(m)
      ZL <- Matrix::t(getME(m, "Lambdat") %*% getME(m, "Zt"))
      XtW <- t(X * wv)
      Cf <- rbind(cbind(XtW %*% X, as.matrix(XtW %*% ZL)),
                  cbind(as.matrix(Matrix::crossprod(ZL, X * wv)), as.matrix(Matrix::crossprod(ZL, ZL * wv)) + diag(ncol(ZL))))
      Ci <- solve(Cf)
      bi <- ncol(X) + rf$idx
      # b (spherical) -> v = theta b: PEV(v) = s2 theta^2 [C^-1]_bb
      Cvv <- Ci[bi, bi, drop = FALSE]
      PEVu <- sigma(m)^2 * th^2 * rf$Lk %*% Cvv %*% t(rf$Lk)
      gv <- data.frame(accession = rf$lv, value = mu + u, se = sqrt(pmax(0, diag(PEVu))), stringsAsFactors = FALSE)
      random$accession <- data.frame(level = rf$lv, solution = u, se = gv$se, stringsAsFactors = FALSE)
      # ancestors (A, H): u_a = K_ad K_dd^-1 u, PEV = s2g (K_aa - K_ad K_dd^-1 K_da) + B PEV(u) B'
      ids_a <- setdiff(rownames(rel_K), rf$lv)
      if (rel_kind %in% c("A", "H") && length(ids_a)) {
        Kdd <- rel_K[rf$lv, rf$lv] + diag(1e-6 * mean(diag(rel_K)), length(rf$lv))
        B <- rel_K[ids_a, rf$lv, drop = FALSE] %*% solve(Kdd)
        s2g <- vc[["accession"]]
        pev_a <- s2g * pmax(0, diag(rel_K)[ids_a] - rowSums(B * rel_K[ids_a, rf$lv, drop = FALSE])) + rowSums((B %*% PEVu) * B)
        ancestors_df <- data.frame(accession = ids_a, value = mu + as.numeric(B %*% u), se = sqrt(pmax(0, pev_a)), stringsAsFactors = FALSE)
      }
    } else if (genotype_random) {
      fp <- predict(m, re.form = NA)
      mu <- mean(tapply(fp, d$trial, mean))
      u <- random$accession
      gv <- data.frame(accession = u$level, value = mu + u$solution, se = u$se, stringsAsFactors = FALSE)
    } else {
      gv <- accession_blues(m, d)
      mu <- NA_real_
    }
    fit <- list(values = gv, vc = vc, resid = as.numeric(residuals(m)), notes = inestimable_terms(m), random = random, mu = mu, engine = "R")
  }
  fit$notes <- c(notes, fit$notes)
  fit$ancestors <- if (exists("ancestors_df", inherits = FALSE)) ancestors_df else NULL
  fit$pedigree <- isTRUE(use_rel)
  fit$relationship <- if (isTRUE(use_rel)) rel_kind else "I"
  if (genotype_random) {
    gv <- fit$values
    # mother / father (GCA-like) effects are part of the genetic value
    if (!is.null(fit$random$mother) || !is.null(fit$random$father)) {
      for (k in intersect(c("mother", "father"), names(fit$random))) {
        p <- dat[[k]][match(gv$accession, dat$accession)]
        r <- fit$random[[k]]
        i <- match(p, r$level)
        g <- r$solution[i]; g[is.na(g)] <- 0
        e <- r$se[i]; e[is.na(e)] <- 0
        gv$value <- gv$value + g
        gv$se <- sqrt(gv$se^2 + e^2)
      }
    }
    fit$values <- gv
  }
  fit
}

# random terms for a design inside one trial
design_terms <- function(design, d) {
  has_rep <- n_levels(d$rep_eff) > 1
  terms <- character()
  if (design == "rcbd" && has_rep) terms <- "(1|rep_eff)"
  if (design == "alpha_lattice") {
    if (has_rep) terms <- c(terms, "(1|rep_eff)")
    if (n_levels(d$block) > 1) terms <- c(terms, "(1|rep_eff:block)")
  }
  if (design == "augmented" && n_levels(d$block) > 1) terms <- "(1|block)"
  if (design == "row_column") {
    if (has_rep) terms <- c(terms, "(1|rep_eff)")
    if (n_levels(d$row) > 1 && !any(d$row_off)) terms <- c(terms, "(1|rep_eff:row_f)")
    if (n_levels(d$col) > 1 && !any(d$col_off)) terms <- c(terms, "(1|rep_eff:col_f)")
  }
  terms
}

model_text <- function(design, terms, genotype_random) {
  g <- if (genotype_random) "(1|accession)" else "accession"
  paste("y ~", paste(c(g, terms), collapse = " + "))
}


# -----------------------------------------------------------------------------
# Helpers for the single-stage model, residuals and variance components
# -----------------------------------------------------------------------------

# factors used by the single-stage models (builder and custom formula)
add_model_factors <- function(d) {
  d$rowN <- d$row; d$colN <- d$col
  d$accession <- factor(d$accession); d$trial <- factor(d$trial)
  d$location <- factor(d$location); d$year <- factor(d$year)
  d$rep <- factor(d$rep_eff); d$block <- factor(d$block)
  d$tr_rep <- factor(paste(d$trial, d$rep_eff))
  d$tr_block <- factor(paste(d$trial, d$rep_eff, d$block))
  # rows / columns switched off by factor_support() keep one level in their
  # trial (the numeric rowN / colN trends still use the positions)
  d$tr_row <- factor(ifelse(is.na(d$rowN), NA, paste(d$trial, ifelse(d$row_off, "off", d$rowN))))
  d$tr_col <- factor(ifelse(is.na(d$colN), NA, paste(d$trial, ifelse(d$col_off, "off", d$colN))))
  d$row <- factor(ifelse(d$row_off & !is.na(d$rowN), 0, d$rowN)); d$col <- factor(ifelse(d$col_off & !is.na(d$colN), 0, d$colN))
  d
}

# Variables a custom formula may use. Only these names, the numbers 0 and 1,
# the operators + - * / : | and parentheses are accepted: no function call can
# reach R through the formula.
FORMULA_VARS <- c("accession", "trial", "location", "year", "rep", "block", "row", "col", "rowN", "colN", "mother", "father", "check")

parse_custom_formula <- function(txt, cov_vars) {
  txt <- gsub("[\r\n\t]+", " ", as.character(txt))
  txt <- sub("^\\s*y\\s*~", "", txt)
  if (!nzchar(trimws(txt))) stop("The custom model formula is empty.")
  allowed <- c(FORMULA_VARS, cov_vars)
  toks <- regmatches(txt, gregexpr("[A-Za-z_][A-Za-z0-9_.]*|[0-9]+(\\.[0-9]+)?|\\s+|.", txt))[[1]]
  for (i in seq_along(toks)) {
    tk <- toks[i]
    if (grepl("^\\s+$", tk) || tk %in% c("+", "-", "*", "/", ":", "|", "(", ")")) next
    if (grepl("^[0-9]", tk)) { if (tk %in% c("0", "1")) next; stop("Custom formula: only the numbers 0 and 1 are allowed (found '", tk, "').") }
    if (grepl("^[A-Za-z_]", tk)) {
      nxt <- toks[-(1:i)]; nxt <- nxt[!grepl("^\\s+$", nxt)]
      if (length(nxt) && nxt[1] == "(") stop("Custom formula: functions are not allowed ('", tk, "(').")
      if (!(tk %in% allowed)) stop("Custom formula: unknown variable '", tk, "'. Allowed: ", paste(allowed, collapse = ", "), ".")
      next
    }
    stop("Custom formula: character '", tk, "' is not allowed.")
  }
  rhs <- trimws(txt)
  random_g <- grepl("\\(\\s*1\\s*\\|\\s*accession\\s*\\)", rhs)
  fixed_part <- gsub("\\([^()]*\\|[^()]*\\)", "", rhs)
  fixed_g <- any(trimws(strsplit(fixed_part, "+", fixed = TRUE)[[1]]) == "accession")
  if (random_g == fixed_g) stop("Custom formula: include the genotype exactly once, either as a fixed effect 'accession' or as a random effect '(1|accession)'.")
  vars <- intersect(unique(toks), allowed)
  list(text = paste("y ~", rhs), genotype_random = random_g, vars = vars)
}

residual_rows <- list()
add_residuals <- function(units, trait, r) {
  if (length(r) != length(units)) return(invisible())
  residual_rows[[length(residual_rows) + 1]] <<- data.frame(unit = as.character(units), trait = trait, resid = as.numeric(r), stringsAsFactors = FALSE)
}
variance_components <- list()

# -----------------------------------------------------------------------------
# Stage 1 - one trial, one trait
# -----------------------------------------------------------------------------
s1_cfg <- opt(recipe, "stage1", list())
s1_model <- opt(s1_cfg, "model", "auto")   # auto | spats | design

# Repeated measurements: one row per measurement of the plots of d (plots
# whose value is missing or excluded keep none). Adds
#   mdate   measurement date (YYYY-MM-DD, "(no date)" when not recorded)
#   mday    days since the trial's first measurement
#   tr_date date within trial (factor): the first date of every trial is one
#           common reference level, so the term holds only the change over
#           the dates of each trial and can sit next to a trial effect
#   plot_u  the plot (factor)
expand_repeated <- function(d, trait) {
  d <- d[!is.na(d$y), , drop = FALSE]
  rl <- rep_long[rep_long$trait == trait & rep_long$unit %in% d$unit, ]
  only <- setdiff(d$unit, rl$unit)       # plots without a measurement list: their single value
  e <- d[c(match(rl$unit, d$unit), match(only, d$unit)), , drop = FALSE]
  e$y <- c(rl$value, d$y[match(only, d$unit)])
  e$mdate <- c(rl$mdate, rep("(no date)", length(only)))
  e$day <- c(rl$day, rep(NA_real_, length(only)))
  first <- ave(e$day, e$trial, FUN = function(x) if (all(is.na(x))) rep(NA_real_, length(x)) else rep(min(x, na.rm = TRUE), length(x)))
  e$mday <- e$day - first
  first_date <- ave(e$mdate, e$trial, FUN = function(x) rep(sort(unique(x))[1], length(x)))
  e$tr_date <- factor(ifelse(e$mdate == first_date, "(first date)", paste(e$trial, e$mdate)))
  e$date_f <- factor(e$mdate)
  e$plot_u <- factor(e$unit)
  # a covariate measured on several dates follows the measurements: each one
  # takes the covariate value of its plot on the nearest date (within
  # COV_DAYS days); measurements without one are left out (reported)
  tv <- character(); drop <- rep(FALSE, nrow(e))
  for (vn in cov_vars) {
    cf <- cov_full[[vn]]
    cl <- if (is.null(rep_long)) NULL else rep_long[rep_long$trait == cf & !is.na(rep_long$day), ]
    if (is.null(cl) || !nrow(cl) || is.null(e[[vn]])) next
    by_u <- split(cl, cl$unit)
    v <- e[[vn]]
    for (i in which(!is.na(e$day))) {
      m <- by_u[[as.character(e$unit[i])]]
      dd <- if (is.null(m)) numeric() else abs(m$day - e$day[i])
      ok <- which(dd <= COV_DAYS)
      if (length(ok)) v[i] <- m$value[ok[which.min(dd[ok])]] else { v[i] <- NA; drop[i] <- TRUE }
    }
    e[[vn]] <- v
    tv <- c(tv, cov_label[[vn]])
  }
  e <- e[!drop, , drop = FALSE]
  rownames(e) <- NULL
  attr(e, "tv_cov") <- tv
  attr(e, "cov_dropped") <- sum(drop)
  e
}
COV_DAYS <- 3
# notes after expand_repeated(): covariates matched to the measurement dates
report_expand <- function(e, where, trait) {
  tv <- attr(e, "tv_cov")
  if (!length(tv)) return(invisible())
  key <- paste("tvcov", trait)
  if (!key %in% names(warned_once)) {
    warned_once[[key]] <<- TRUE
    add_warning(short_trait(trait), ": covariate(s) ", paste(tv, collapse = ", "), " measured on several dates follow the measurements: each measurement uses the covariate value of its plot on the nearest date (within ", COV_DAYS, " days).")
  }
  if (attr(e, "cov_dropped") > 0) add_warning(where, ": ", attr(e, "cov_dropped"), " measurement(s) without a covariate value within ", COV_DAYS, " days were left out.")
}
warned_once <- list()
# time effect of a repeated-measures model on data e: "date" (date factor),
# "linear" (days) or "none" (one date per trial or no dates)
rep_time_effect <- function(e) {
  n_tr <- n_levels(e$trial)
  if (rep_time == "linear" && all(!is.na(e$mday)) && n_levels(e$mday) > n_tr) return("linear")
  if (n_levels(e$tr_date) > 1) return("date")
  "none"
}
# model variables as shown in the results
pretty_model <- function(x) {
  x <- gsub("\\btr_date\\b", "date", x); x <- gsub("\\bdate_f\\b", "date", x)
  x <- gsub("\\bplot_u\\b", "plot", x); gsub("\\bmday\\b", "days", x)
}
rep_warned <- character()
rep_warn_once <- function(key, ...) { if (!(key %in% rep_warned)) { rep_warned <<- c(rep_warned, key); add_warning(...) } }
# harmonic mean of the number of plots per accession and of measurements per plot
plots_per_acc <- function(d) { u <- unique(data.frame(a = as.character(d$accession), p = as.character(d$unit))); 1 / mean(1 / as.numeric(table(u$a))) }
meas_per_plot <- function(d) 1 / mean(1 / as.numeric(table(as.character(d$unit))))

# covariates of one trial: present on most plots and not constant (a
# covariate constant within the trial is held by the intercept)
trial_covariates <- function(d, trait) {
  Filter(function(cv) cv != cov_name(trait) && !(cv %in% mt_skip_cov[[trait]]) && sum(!is.na(d[[cv]])) > 0.5 * nrow(d) && n_levels(d[[cv]]) > 1, cov_vars)
}

fit_stage1 <- function(d, info, trait) {
  d <- d[!is.na(d$y), ]
  # covariates: plots without a value of a covariate the trial uses are left out
  cv_fx <- trial_covariates(d, trait)
  if (length(cv_fx)) {
    cc <- complete.cases(d[, cv_fx, drop = FALSE])
    if (any(!cc)) add_warning("Stage 1, ", info$trial, " / ", short_trait(trait), ": ", sum(!cc), " plot(s) without a covariate value were left out.")
    d <- d[cc, ]
  }
  for (cv in setdiff(cov_vars, c(cv_fx, cov_name(trait))))
    rep_warn_once(paste("cov", info$trial, cv), "Stage 1, ", info$trial, ": covariate ", cov_label[[cv]], " is missing or constant in this trial and was not used there.")
  cv_lab <- if (length(cv_fx)) paste0(" + ", paste(cv_fx, collapse = " + ")) else ""
  rep_all <- identical(rep_mode[[trait]], "all")
  res <- list(trial = info$trial, trait = short_trait(trait), design = info$design_label,
              n = nrow(d), n_measurements = nrow(d), n_accessions = n_levels(d$accession), mean = mean(d$y),
              cv = NA_real_, h2 = NA_real_, var_g = NA_real_, var_e = NA_real_, model = "", message = "OK")
  if (nrow(d) < 3 || n_levels(d$accession) < 2) {
    res$message <- "Not enough data"
    return(list(summary = res, means = NULL))
  }
  d$accession <- factor(d$accession)
  d$row_f <- factor(d$row); d$col_f <- factor(d$col)
  d$rep_eff <- factor(d$rep_eff); d$block <- factor(d$block)
  # treatments applied to part of this trial: fixed effects of the trial model
  trt_fx <- Filter(function(v) n_levels(d[[v]]) > 1, trt_use)
  for (v in trt_fx) d[[v]] <- factor(d[[v]])
  trt_df <- sum(vapply(trt_fx, function(v) n_levels(d[[v]]) - 1, numeric(1)))
  trt_lab <- if (length(trt_fx)) paste0(" + ", paste(trt_fx, collapse = " + ")) else ""

  design <- info$design
  raw_means <- function(model, message) {
    means <- aggregate(y ~ accession, data = d, FUN = mean)
    names(means)[2] <- "value"
    means$accession <- as.character(means$accession)
    means$se <- NA_real_
    res$model <- model
    res$message <- message
    list(summary = res, means = means)
  }
  if (design == "unreplicated") {
    return(raw_means("Unreplicated: raw values (no error estimate)", "Trial is unreplicated; values are raw observations."))
  }
  # Too few replicated plots, or replicated plots with identical values: no
  # model can estimate an error variance (augmented trials with a few checks
  # scored on a 1-9 scale, for example). Use the accession means.
  df_res <- nrow(d) - n_levels(d$accession) - max(0, n_levels(d$rep_eff) - 1) - trt_df - length(cv_fx)
  within <- tapply(d$y, d$accession, function(v) if (length(v) > 1) sum((v - mean(v))^2) else 0)
  if (df_res < 2 || sum(within) <= 1e-10 * max(1, sum((d$y - mean(d$y))^2))) {
    why <- if (df_res < 2) sprintf("only %d residual degree(s) of freedom", max(0, df_res)) else "the replicated plots have identical values"
    add_warning(info$trial, " / ", short_trait(trait), ": no error variance can be estimated (", why, "); accession means were used without standard errors.")
    return(raw_means(paste0("Accession means (no error estimate: ", why, ")"), paste0("No error variance: ", why, ".")))
  }


  use_spats <- (s1_model == "spats" || (s1_model == "auto" && info$has_rowcol)) && info$has_rowcol

  # repeated measurements of this trait modelled one by one: date effect (or
  # linear trend in days), random plot effect, optional genotype x date
  rep_fx <- character(); rep_rnd <- character()
  if (rep_all) {
    d <- expand_repeated(d, trait)
    report_expand(d, paste0("Stage 1, ", info$trial, " / ", short_trait(trait)), trait)
    res$n_measurements <- nrow(d)
    time_eff <- rep_time_effect(d)
    if (time_eff == "date") rep_fx <- "date_f" else if (time_eff == "linear") rep_fx <- "mday"
    if (any(table(as.character(d$unit)) > 1)) rep_rnd <- "(1|plot_u)"
    if (rep_gxtime && time_eff == "date") rep_rnd <- c(rep_rnd, "(1|accession:date_f)")
    if (use_spats) rep_warn_once(paste("spats", trait), short_trait(trait), ": SpATS does not model repeated measurements of a plot; the design model with a date and a plot effect was used in stage 1.")
    use_spats <- FALSE
  }

  if (use_spats && requireNamespace("SpATS", quietly = TRUE)) {
    nr <- n_levels(d$row); nc <- n_levels(d$col)
    nseg <- c(max(1, ceiling(nc / 2)), max(1, ceiling(nr / 2)))
    has_rep <- n_levels(d$rep_eff) > 1
    d$rowN <- d$row; d$colN <- d$col
    rc_random <- c(if (nr > 1 && !any(d$row_off)) "row_f", if (nc > 1 && !any(d$col_off)) "col_f")
    # Candidate specifications: replicate as fixed effect first; when blocks
    # are aligned with rows/columns the fixed replicate effect is collinear
    # with the spatial surface, so fall back to replicate as random effect.
    fx <- function(v) if (length(v)) as.formula(paste("~", paste(v, collapse = " + "))) else NULL
    specs <- list(
      list(fixed = fx(c(if (has_rep) "rep_eff", trt_fx, cv_fx)), random = rc_random, label = paste0(if (has_rep) " + rep" else "", trt_lab, cv_lab), rlabel = ""),
      list(fixed = fx(c(trt_fx, cv_fx)), random = c(if (has_rep) "rep_eff", rc_random), label = paste0(trt_lab, cv_lab), rlabel = if (has_rep) " + (1|rep)" else "")
    )
    if (!has_rep) specs <- specs[1]
    spats_fit <- function(spec, g_random) {
      random <- if (length(spec$random)) as.formula(paste("~", paste(spec$random, collapse = " + "))) else NULL
      fit_quietly(SpATS::SpATS(response = "y", genotype = "accession", genotype.as.random = g_random,
                    spatial = ~ SpATS::PSANOVA(colN, rowN, nseg = nseg), fixed = spec$fixed, random = random,
                    data = d, control = list(tolerance = 1e-03, monitoring = 0)))
    }
    fF <- NULL
    for (spec in specs) {
      fF <- spats_fit(spec, FALSE)
      if (!inherits(fF, "error")) break
    }
    if (!inherits(fF, "error")) {
      pr <- predict(fF, which = "accession")
      means <- data.frame(accession = as.character(pr$accession), value = pr$predicted.values,
                          se = pr$standard.errors, stringsAsFactors = FALSE)
      res$model <- sprintf("SpATS: y ~ accession%s + PSANOVA(col, row, nseg = c(%d, %d))%s%s",
                           spec$label, nseg[1], nseg[2], spec$rlabel,
                           if (length(rc_random)) paste0(" + (1|", sub("_f$", "", rc_random), ")", collapse = "") else "")
      res$var_e <- fF$psi[1]
      fR <- spats_fit(spec, TRUE)
      if (!inherits(fR, "error")) {
        res$h2 <- tryCatch(unname(SpATS::getHeritability(fR)), error = function(e) NA_real_)
        res$var_g <- tryCatch(unname(fR$var.comp["accession"]), error = function(e) NA_real_)
      }
      res$cv <- 100 * sqrt(res$var_e) / abs(res$mean)
      return(list(summary = res, means = means, resid = data.frame(unit = d$unit, resid = as.numeric(fF$residuals))))
    }
    add_warning("SpATS could not be fitted for ", info$trial, " / ", short_trait(trait), " (", conditionMessage(fF), " This usually means the field layout confounds the spatial trend with genotypes); the ", info$design_label, " design model was used instead.")
  } else if (use_spats) {
    add_warning("R package SpATS is not installed; using the design model for ", info$trial, ".")
  }

  # Design based model -------------------------------------------------------
  design <- info$design
  terms <- c(design_terms(design, d), rep_rnd)
  fx_all <- c(trt_fx, cv_fx, rep_fx)
  # h2 on an accession-mean basis: plots per accession, measurements per plot
  h2_of <- function(vg, vc) {
    r <- plots_per_acc(d); m <- meas_per_plot(d)
    vp <- if ("plot_u" %in% names(vc)) vc[["plot_u"]] else 0
    vgt <- if ("accession:date_f" %in% names(vc)) vc[["accession:date_f"]] / n_levels(d$date_f) else 0
    unname(vg / (vg + vgt + (vp + vc[["Residual"]] / m) / r))
  }
  # one residual per plot (mean over its measurements)
  plot_resid <- function(r) {
    if (!rep_all) return(data.frame(unit = d$unit, resid = as.numeric(r)))
    a <- tapply(as.numeric(r), as.character(d$unit), mean)
    data.frame(unit = names(a), resid = as.numeric(a))
  }

  fml_fixed <- as.formula(model_text(design, c(fx_all, terms), FALSE))
  fit <- if (length(terms)) fit_quietly(lmer(fml_fixed, data = d, REML = TRUE)) else fit_quietly(lm(fml_fixed, data = d))
  if (inherits(fit, "error")) {
    # fall back to the simplest model (the plot effect stays for repeated measurements)
    terms <- intersect(rep_rnd, "(1|plot_u)")
    fml_fixed <- as.formula(model_text(design, terms, FALSE))
    fit <- if (length(terms)) fit_quietly(lmer(fml_fixed, data = d, REML = TRUE)) else fit_quietly(lm(y ~ accession, data = d))
    if (inherits(fit, "error")) { res$message <- conditionMessage(fit); return(list(summary = res, means = NULL)) }
    res$message <- paste0("Design model failed; fitted ", paste(deparse(fml_fixed, width.cutoff = 500), collapse = ""), ".")
  }
  if (!inherits(fit, "merMod") && df.residual(fit) < 1) {
    res$message <- "No residual degrees of freedom"
    return(list(summary = res, means = NULL))
  }
  means <- accession_blues(fit, d)
  res$model <- paste(deparse(fml_fixed, width.cutoff = 500), collapse = "")
  lost <- inestimable_terms(fit)
  if (length(lost)) add_warning("Stage 1, ", info$trial, " / ", short_trait(trait), ": ", paste(lost, collapse = "; "), ".")
  res$var_e <- if (inherits(fit, "merMod")) sigma(fit)^2 else summary(fit)$sigma^2

  fml_random <- as.formula(model_text(design, c(fx_all, terms), TRUE))
  fr <- fit_quietly(lmer(fml_random, data = d, REML = TRUE))
  if (!inherits(fr, "error")) {
    vc <- var_comp(fr)
    res$var_g <- unname(vc["accession"])
    res$h2 <- h2_of(res$var_g, vc)
  }
  res$cv <- 100 * sqrt(res$var_e) / abs(res$mean)
  list(summary = res, means = means, resid = plot_resid(residuals(fit)))
}

# -----------------------------------------------------------------------------
# software of the run, with versions, what each program did in this run and
# the reference to cite (results overview and dashboard)
software_used <- function() {
  pv <- function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) "")
  s1 <- if (is.null(stage1_summary)) data.frame(trial = character(), trait = character(), model = character()) else stage1_summary
  is_sp <- grepl("^SpATS", s1$model)
  is_lm <- nzchar(s1$model) & !is_sp & !grepl("^(glmmTMB|Single trial|Accession means|raw values)", s1$model)
  nt <- function(i) n_levels(s1$trial[i]); nr <- function(i) n_levels(s1$trait[i])
  s2 <- if (!is.data.frame(stage2_summary)) data.frame(trait = character(), model = character(), stringsAsFactors = FALSE) else stage2_summary
  s2_lm <- s2$model != "" & !grepl("^(glmmTMB|Single trial)", s2$model)
  g_txt <- if (genotype_random) "genotype random, BLUPs" else "genotype fixed, BLUEs"
  plural <- function(n, w) paste(n, if (n == 1) w else paste0(w, "s"))
  sw <- list()
  if (any(is_sp))
    sw[[length(sw) + 1]] <- list(name = "SpATS", version = pv("SpATS"),
      used_for = paste0("Fitted the stage-1 spatial models of ", plural(nt(is_sp), "trial"), " x ", plural(nr(is_sp), "trait"), " (", plural(sum(is_sp), "model"),
                        "): a 2D P-spline surface (PSANOVA) with row and column effects corrects the field trend; its accession BLUEs went to stage 2."),
      reference = "Rodriguez-Alvarez MX, Boer MP, van Eeuwijk FA, Eilers PHC (2018). Correcting for spatial heterogeneity in plant breeding experiments with P-splines. Spatial Statistics 23: 52-71.")
  lm_parts <- c(if (any(is_lm)) paste0("the stage-1 design models of ", plural(sum(is_lm), "trial x trait combination"), " (", plural(nt(is_lm), "trial"), ")"),
                if (any(s2_lm) && strategy == "two_stage") paste0("the stage-2 models of ", plural(sum(s2_lm), "trait"), " across trials (", g_txt, if (weighting == "inverse_se2") ", weights 1/SE^2" else "", ")"),
                if (any(s2_lm) && strategy != "two_stage") paste0("the single-stage models of ", plural(sum(s2_lm), "trait"), " (", g_txt, ")"))
  rel_txt <- c(A = "the pedigree relationship A", G = "the genomic relationship G", H = "the single-step relationship H")[rel_kind]
  rel_used <- nzchar(rel_kind) && any(grepl("N\\(0, [AGH] s2g\\)", s2$model))
  if (length(lm_parts))
    sw[[length(sw) + 1]] <- list(name = "lme4", version = pv("lme4"),
      used_for = paste0("Fitted ", paste(lm_parts, collapse = " and "), " by REML",
                        if (rel_used) paste0("; the accession effect follows ", rel_txt[[1]], " (through the Cholesky factor of the matrix, as pedigreemm)") else "", "."),
      reference = "Bates D, Maechler M, Bolker B, Walker S (2015). Fitting linear mixed-effects models using lme4. Journal of Statistical Software 67(1): 1-48.")
  if (rel_used) {
    what <- switch(rel_kind,
      A = paste0("Built the pedigree relationship matrix A of ", rel_info$n_pedigree, " individuals (accessions and their ancestors), with inbreeding."),
      G = paste0("Built the genomic relationship matrix G (VanRaden) of ", rel_info$n_genotyped, " genotyped accessions from ", rel_info$n_snps_used, " of ", rel_info$n_snps,
                 " markers (after the minor allele frequency and call rate filters), blended 0.95 G + 0.05 I so it can be inverted",
                 if (isTRUE(rel_info$n_without > 0)) paste0("; ", rel_info$n_without, " accessions without genotypes were treated as unrelated") else "", "."),
      H = paste0("Built the single-step relationship matrix H (Martini et al. 2018) from the pedigree of ", rel_info$n_pedigree, " individuals and the genotypes of ",
                 rel_info$n_genotyped, " accessions (", rel_info$n_snps_used, " of ", rel_info$n_snps, " markers after filters); G was first put on the scale of the pedigree ",
                 "(same mean diagonal and off-diagonal as A22) and blended 0.95 G + 0.05 A22, so accessions without genotypes are linked through the pedigree."))
    sw[[length(sw) + 1]] <- list(name = "AGHmatrix", version = pv("AGHmatrix"), used_for = what,
      reference = "Amadeu RR, Cellon C, Olmstead JW, Garcia AAF, Resende MFR, Munoz PR (2016). AGHmatrix: R package to construct relationship matrices for autotetraploid and diploid species: a blueberry example. The Plant Genome 9(3).")
  }
  if (length(multi_trait_out))
    sw[[length(sw) + 1]] <- list(name = "glmmTMB", version = pv("glmmTMB"),
      used_for = paste0("Fitted the multi-trait model", if (length(multi_trait_out) > 1) "s" else "", " of ",
                        paste(vapply(names(multi_trait_out), function(t) { m <- multi_trait_out[[t]]; paste0(t, " (", plural(m$n_occasions, "date"),
                          if (length(m$covariates)) paste0(" + dates of ", paste(m$covariates, collapse = ", ")) else "", ")") }, ""), collapse = "; "),
                        ": genetic covariance between dates G0 (x) I and residual R0 (x) I, values = mean over the dates",
                        if (any(vapply(multi_trait_out, function(m) isTRUE(m$adjusted), logical(1)))) ", adjusted genetically for the covariate" else "", "."),
      reference = "Brooks ME, Kristensen K, van Benthem KJ, Magnusson A, Berg CW, Nielsen A, Skaug HJ, Maechler M, Bolker BM (2017). glmmTMB balances speed and flexibility among packages for zero-inflated generalized linear mixed modeling. The R Journal 9(2): 378-400.")
  sw
}

# Step 3 - models
# -----------------------------------------------------------------------------
strategy <- opt(recipe, "strategy", "two_stage")
s2_cfg <- opt(recipe, "stage2", list())
ss_cfg <- opt(recipe, "single", list())
genotype_random <- identical(opt(if (strategy == "two_stage") s2_cfg else ss_cfg, "genotype", "random"), "random")
weighting <- opt(s2_cfg, "weighting", "inverse_se2")

# Multi-trait repeated measurements (recipe repeated$traits = "multi") -------
# Every measurement occasion of the trait (1st, 2nd ... date of each trial)
# becomes a trait: stage 1 fits each trial x occasion; stage 2 is one multi-
# trait model fitted with glmmTMB (free, open source):
#   y ~ 0 + trait:trial + us(0 + trait | accession) + us(0 + trait | record)
# with the residual moved to the record term (dispformula = ~0), i.e.
# Var(g) = G0 (x) I and Var(e) = R0 (x) I, as the BLUPF90+ engine fits them.
# A covariate measured on several dates joins the model with its occasions
# as more traits (not as a stage-1 covariate): values are adjusted genetically,
# g_y - G_yc G_cc^-1 g_c. The value of an accession is the mean over the
# occasions; its standard error comes from the conditional covariances of
# the random effects. Pedigree / genomic multi-trait models need BLUPF90+.
MT_MAX <- 6
mt_groups <- list()        # trait -> list(trait, y, c, labels, covariates)
mt_skip_cov <- list()      # occasion trait -> covariates it does not use in stage 1
multi_trait_out <- list()
occasions_of <- function(full) {
  rl <- rep_long[rep_long$trait == full & rep_long$mdate != "(no date)", ]
  tr <- dat$trial[match(rl$unit, dat$unit)]
  ok <- !is.na(tr); rl <- rl[ok, ]; tr <- tr[ok]
  occ <- integer(nrow(rl)); n <- 0L
  for (t in unique(tr)) {
    i <- which(tr == t); dts <- sort(unique(rl$mdate[i]))
    occ[i] <- match(rl$mdate[i], dts); n <- max(n, length(dts))
  }
  list(rl = rl, occ = occ, n = n)
}
occasion_columns <- function(full, o, blank_from = NULL) {
  parts <- strsplit(full, "|", fixed = TRUE)[[1]]
  rest <- if (length(parts) > 1) paste0("|", paste(parts[-1], collapse = "|")) else ""
  nm <- character()
  for (k in seq_len(o$n)) {
    i <- which(o$occ == k)
    v <- tapply(o$rl$value[i], o$rl$unit[i], mean)
    col <- unname(v[as.character(dat$unit)])
    if (!is.null(blank_from)) col[is.na(dat[[blank_from]])] <- NA
    name <- paste0(parts[1], "@o", k, rest)
    dat[[name]] <<- as.numeric(col)
    nm <- c(nm, name)
  }
  nm
}
mt_wanted <- names(rep_mode)[vapply(rep_mode, function(x) identical(x, "multi"), logical(1))]
if (length(mt_wanted)) {
  back <- function(t, why) {
    rep_mode[[t]] <<- "all"
    add_warning(short_trait(t), ": ", why, "; its measurements were modelled with the repeated-measures model (all measurements) instead.")
  }
  if (strategy != "two_stage" || !genotype_random) {
    for (t in mt_wanted) back(t, "the multi-trait model needs two stages with the genotype as a random effect")
  } else {
    if (gen_model != "iid") add_warning("The multi-trait model of repeated measurements treats accessions as unrelated in R (glmmTMB cannot use the relationship matrix between dates); the other traits use the ", if (gen_model %in% names(REL_LABEL)) REL_LABEL[[gen_model]] else "mother / father effects", ".")
    rep_cov <- Filter(function(vn) !is.null(rep_long) && any(rep_long$trait == cov_full[[vn]]), cov_vars)
    new_traits <- character()
    for (t in traits) {
      if (!t %in% mt_wanted) { new_traits <- c(new_traits, t); next }
      o <- occasions_of(t)
      if (o$n < 2) { back(t, "it has one measurement date per trial, so there is nothing to model as several traits"); new_traits <- c(new_traits, t); next }
      cy <- Filter(function(x) x$occ$n >= 1, lapply(setdiff(rep_cov, cov_name(t)), function(vn) list(vn = vn, full = cov_full[[vn]], occ = occasions_of(cov_full[[vn]]))))
      K <- o$n + sum(vapply(cy, function(x) x$occ$n, numeric(1)))
      if (K > MT_MAX) { back(t, paste0(K, " traits (occasions + covariate occasions), more than the ", MT_MAX, " a multi-trait model estimates reliably")); new_traits <- c(new_traits, t); next }
      y <- occasion_columns(t, o, blank_from = t)
      cc <- unlist(lapply(cy, function(x) occasion_columns(x$full, x$occ)))
      labels <- c(paste(short_trait(t), "occasion", seq_along(y)), unlist(lapply(cy, function(x) paste(short_trait(x$full), "occasion", seq_len(x$occ$n)))))
      mt_groups[[t]] <- list(trait = t, y = y, c = cc, labels = labels, covariates = vapply(cy, function(x) short_trait(x$full), ""))
      for (p in c(y, cc)) mt_skip_cov[[p]] <- vapply(cy, function(x) x$vn, "")
      new_traits <- c(new_traits, y, cc)
      log_step("Multi-trait: ", short_trait(t), " as ", length(y), " occasion traits", if (length(cc)) paste0(" + ", length(cc), " covariate occasion traits") else "")
    }
    traits <- new_traits
  }
}
mt_pseudo <- unlist(lapply(mt_groups, function(g) c(g$y, g$c)))

stage1_summary <- list()
stage1_means <- list()
stage2_summary <- list()
genotype_values <- list()
ancestor_values <- list()

# Stage-1 style per-trial means are always computed: they are needed for the
# two-stage approach, for environmental zoning and for the results dashboard
# (performance of each accession in each environment). For a single-stage
# analysis they are plain cell means.
run_stage1 <- TRUE
if (run_stage1) {
  for (t in traits) {
    for (tr in trials) {
      d <- dat[dat$trial == tr, ]
      d$y <- d[[t]]
      if (sum(!is.na(d$y)) == 0) next
      log_step("Stage 1: ", tr, " / ", short_trait(t))
      r <- if (strategy == "two_stage") {
        tryCatch(fit_stage1(d, trial_info[[tr]], t), error = function(e) {
          add_warning("Stage 1, ", tr, " / ", short_trait(t), ": the model failed (", conditionMessage(e), "); this trial was left out for this trait.")
          list(summary = NULL, means = NULL)
        })
      } else {
        # for single stage only cell means are needed for zoning
        d <- d[!is.na(d$y), ]
        m <- aggregate(y ~ accession, data = d, FUN = mean)
        list(summary = NULL, means = data.frame(accession = m$accession, value = m$y, se = NA_real_))
      }
      if (!is.null(r$summary)) { r$summary$model <- pretty_model(r$summary$model); stage1_summary[[length(stage1_summary) + 1]] <- as.data.frame(r$summary, stringsAsFactors = FALSE) }
      if (!is.null(r$resid)) add_residuals(r$resid$unit, t, r$resid$resid)
      if (!is.null(r$means) && nrow(r$means)) {
        r$means$trial <- tr
        r$means$env <- dat$env[dat$trial == tr][1]
        r$means$trait <- t
        stage1_means[[length(stage1_means) + 1]] <- r$means
      }
    }
  }
}
stage1_summary <- if (length(stage1_summary)) do.call(rbind, stage1_summary) else NULL
stage1_means <- if (length(stage1_means)) do.call(rbind, stage1_means) else NULL


# stage 2 of a multi-trait group, fitted with glmmTMB
stage2_multi_tmb <- function(g) {
  names_all <- c(g$y, g$c)
  m <- stage1_means[stage1_means$trait %in% names_all & !is.na(stage1_means$value), ]
  short <- short_trait(g$trait)
  keep <- names_all[names_all %in% unique(m$trait)]
  ky <- intersect(keep, g$y)
  res <- list(trait = short, n_trials = n_levels(m$trial), n_accessions = n_levels(m$accession),
              mean = mean(m$value[m$trait %in% ky]), var_g = NA_real_, var_ge = NA_real_, h2 = NA_real_,
              model = "", message = "OK", engine_used = "glmmTMB", pedigree_used = FALSE)
  if (!length(ky) || length(keep) < 2) {
    add_warning("Stage 2, ", short, ": too few occasions with stage-1 results for the multi-trait model.")
    res$message <- "too few occasions"; return(list(summary = res, values = NULL))
  }
  K <- length(keep)
  sdv <- vapply(keep, function(k) { s <- sd(m$value[m$trait == k]); if (is.finite(s) && s > 0) s else 1 }, numeric(1))
  m$rec <- factor(paste(m$trial, m$accession))
  m$trait <- factor(m$trait, levels = keep)
  m$y <- m$value / sdv[as.character(m$trait)]
  m$trial <- factor(m$trial); m$accession <- factor(m$accession)
  fml <- if (n_levels(m$trial) > 1) y ~ 0 + trait:trial + us(0 + trait | accession) + us(0 + trait | rec) else y ~ 0 + trait + us(0 + trait | accession) + us(0 + trait | rec)
  log_step("Stage 2: multi-trait model for ", short, " (", K, " traits) with glmmTMB")
  fit <- tryCatch(glmmTMB::glmmTMB(fml, dispformula = ~0, data = m, REML = TRUE), error = function(e) e)
  if (inherits(fit, "error")) {
    add_warning("Stage 2, ", short, ": the multi-trait model could not be fitted (", conditionMessage(fit), ").")
    res$message <- conditionMessage(fit); return(list(summary = res, values = NULL))
  }
  if (!isTRUE(fit$sdr$pdHess)) add_warning("Stage 2, ", short, " (multi-trait): glmmTMB reports a non positive-definite Hessian; the variance estimates of this fit are approximate.")
  S <- outer(sdv, sdv)
  G <- unclass(glmmTMB::VarCorr(fit)$cond$accession)[seq_len(K), seq_len(K)] * S
  R <- unclass(glmmTMB::VarCorr(fit)$cond$rec)[seq_len(K), seq_len(K)] * S
  attributes(G) <- list(dim = c(K, K)); attributes(R) <- list(dim = c(K, K))
  re <- glmmTMB::ranef(fit)$cond$accession
  # prediction error (co)variances of the accession effects across the traits:
  # blocks of the inverse of the random-effect Hessian (the inverse of the
  # mixed model coefficient matrix, as BLUPF90+ store_pev_pec). glmmTMB's
  # condVar has no covariances between traits for us() terms.
  pec <- tryCatch({
    e <- fit$obj$env
    H <- e$spHess(e$last.par.best, random = TRUE)
    bi <- which(names(e$last.par.best)[e$random] == "b")
    idx <- bi[seq_len(K * nrow(re))]          # the accession term comes first, level by level
    E <- Matrix::sparseMatrix(i = idx, j = seq_along(idx), x = 1, dims = c(nrow(H), length(idx)))
    as.matrix(Matrix::solve(H, E))[idx, , drop = FALSE]
  }, error = function(e) NULL)
  py <- which(keep %in% g$y); pc <- which(keep %in% g$c)
  L <- numeric(K); L[py] <- 1 / length(py)
  adjusted <- FALSE
  if (length(pc)) {
    B <- tryCatch(G[py, pc, drop = FALSE] %*% solve(G[pc, pc, drop = FALSE]), error = function(e) NULL)
    if (is.null(B)) add_warning("Stage 2, ", short, ": the genetic covariance of the covariate occasions is singular, so the values were not adjusted for the covariate.")
    else { L[pc] <- -colSums(B) / length(py); adjusted <- TRUE }
  }
  fe <- glmmTMB::fixef(fit)$cond
  # mean of the fixed part of each occasion (its trial effects), on the original scale
  mu <- mean(vapply(py, function(k) { nm <- names(fe); b <- fe[nm == paste0("trait", keep[k]) | startsWith(nm, paste0("trait", keep[k], ":"))]; mean(b) * sdv[k] }, numeric(1)))
  U <- sweep(as.matrix(re), 2, sdv, "*")
  vg <- as.numeric(t(L) %*% G %*% L)
  se <- vapply(seq_len(nrow(U)), function(i) {
    if (is.null(pec)) return(NA_real_)
    C <- pec[(i - 1) * K + seq_len(K), (i - 1) * K + seq_len(K), drop = FALSE] * S
    p <- as.numeric(t(L) %*% C %*% L)
    if (is.finite(p) && p >= 0) sqrt(p) else NA_real_
  }, numeric(1))
  vals <- data.frame(accession = rownames(re), value = mu + as.numeric(U %*% L), se = se, stringsAsFactors = FALSE)
  rel <- 1 - se^2 / vg
  res$var_g <- vg
  w <- numeric(K); w[py] <- 1 / length(py)
  res$var_ge <- as.numeric(t(w) %*% R %*% w)
  res$h2 <- if (any(is.finite(rel))) mean(pmax(0, rel[is.finite(rel)])) else NA_real_
  res$model <- paste0("glmmTMB multi-trait: ", length(py), " occasions", if (length(pc)) paste0(" + ", length(pc), " covariate occasions (", paste(g$covariates, collapse = ", "), ")") else "",
                      " ~ trial + (1|accession), G0 (x) I, R0 (x) I; value = mean of the occasions",
                      if (adjusted) ", adjusted genetically for the covariate (g_y - G_yc G_cc^-1 g_c)" else "", "; H2 = mean reliability")
  labels <- g$labels[match(keep, names_all)]
  for (i in seq_len(K)) {
    variance_components[[length(variance_components) + 1]] <<- data.frame(trait = short, component = paste0("genetic, ", labels[i]), variance = G[i, i], stringsAsFactors = FALSE)
    variance_components[[length(variance_components) + 1]] <<- data.frame(trait = short, component = paste0("residual, ", labels[i]), variance = R[i, i], stringsAsFactors = FALSE)
  }
  multi_trait_out[[short]] <<- list(occasions = labels, n_occasions = length(py), covariates = g$covariates, G0 = G, R0 = R,
                                    genetic_correlations = cov2cor(G), weights = L, adjusted = adjusted, engine = "glmmTMB")
  vals$trait <- g$trait
  list(summary = res, values = vals)
}

if (strategy == "two_stage") {
  # Stage 2 -------------------------------------------------------------------
  for (g in mt_groups) {
    r <- stage2_multi_tmb(g)
    stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(r$summary, stringsAsFactors = FALSE)
    if (!is.null(r$values)) genotype_values[[length(genotype_values) + 1]] <- r$values
  }
  for (t in setdiff(traits, mt_pseudo)) {
    m <- stage1_means[stage1_means$trait == t & !is.na(stage1_means$value), ]
    if (is.null(m) || nrow(m) == 0) next
    n_tr <- n_levels(m$trial)
    res <- list(trait = short_trait(t), n_trials = n_tr, n_accessions = n_levels(m$accession),
                mean = mean(m$value), var_g = NA_real_, var_ge = NA_real_, h2 = NA_real_,
                model = "", message = "OK", engine_used = NA_character_, pedigree_used = FALSE)
    check_on <- genotype_random && check_opt != "none" && (check_opt == "fixed" || n_levels(acc_is_check[as.character(m$accession)]) > 1)
    if (n_tr == 1 && gen_model == "iid" && !check_on) {
      gv <- data.frame(accession = m$accession, value = m$value, se = m$se)
      res$model <- "Single trial: stage 1 means"
      s1 <- stage1_summary[stage1_summary$trait == short_trait(t), ]
      res$h2 <- s1$h2[1]; res$var_g <- s1$var_g[1]
    } else {
      m$accession <- factor(m$accession); m$trial <- factor(m$trial)
      w <- if (weighting == "inverse_se2" && all(is.finite(m$se)) && all(m$se > 0)) 1 / m$se^2 else rep(1, nrow(m))
      m$w <- w / mean(w)
      m$y <- m$value
      m$check <- ifelse(acc_is_check[as.character(m$accession)], "check", "test")
      m$mother <- dat$mother[match(m$accession, dat$accession)]
      m$father <- dat$father[match(m$accession, dat$accession)]
      terms <- c(if (genotype_random) "(1|accession)" else "accession", if (n_tr > 1) "trial", if (check_on) "check",
                 if (genotype_random && gen_model == "parents") c("(1|mother)", "(1|father)"))
      # genotype x treatment: treatments applied to whole trials (the trial
      # main effect already holds the treatment main effect)
      for (v in trt_gxt) {
        lv <- tapply(dat[[v]], dat$trial, function(x) { u <- unique(x); if (length(u) == 1) u else "(mixed)" })
        m[[v]] <- unname(lv[as.character(m$trial)])
        nm <- treatment_factors[[v]]$name
        if (any(m[[v]] == "(mixed)")) add_warning("Stage 2, ", short_trait(t), ": ", nm, " varies within trial(s) ", paste(names(lv)[lv == "(mixed)"], collapse = ", "),
                                                  "; those trials count as level '(mixed)' of the genotype x ", nm, " term (within a trial the treatment is a fixed effect of stage 1).")
        n_lv <- n_levels(m[[v]])
        if (n_lv > 1 && n_lv < n_tr) terms <- c(terms, paste0("(1|accession:", v, ")"))
        else add_warning("Stage 2, ", short_trait(t), ": genotype x ", nm, " left out (", if (n_lv < 2) paste0("all trials have the same ", nm) else paste0("each ", nm, " level has a single trial, so it cannot be separated from genotype x trial"), ").")
      }
      fml_txt <- paste("y ~", paste(terms, collapse = " + "))
      f2 <- tryCatch(fit_model(m, fml_txt, genotype_random, w = m$w, label = paste0("stage2_", short_trait(t))), error = function(e) e)
      if (inherits(f2, "error")) { res$message <- conditionMessage(f2); add_warning("Stage 2, ", short_trait(t), ": the model could not be fitted (", conditionMessage(f2), ")."); stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res); next }
      if (length(f2$notes)) add_warning("Stage 2, ", short_trait(t), ": ", paste(f2$notes, collapse = "; "), ".")
      gv <- f2$values
      vc <- f2$vc
      g_names <- intersect(c("accession", "mother", "father"), names(vc))
      if (genotype_random) {
        res$var_g <- unname(sum(vc[g_names]))
        e_bar <- 1 / mean(1 / as.numeric(table(m$accession)))
        # genotype x treatment components, divided by the (harmonic) mean
        # number of treatment levels per accession
        gxt_names <- intersect(paste0("accession:", trt_gxt), names(vc))
        gxt_part <- sum(vapply(gxt_names, function(k) {
          v <- sub("^accession:", "", k)
          u <- unique(data.frame(a = m$accession, l = m[[v]]))
          vc[[k]] * mean(1 / as.numeric(table(u$a)))
        }, numeric(1)))
        res$var_ge <- unname(vc["Residual"] + sum(vc[gxt_names]))
        res$h2 <- unname(res$var_g / (res$var_g + gxt_part + vc["Residual"] / e_bar))
      } else res$var_ge <- unname(vc["Residual"])
      comp <- names(vc); comp[comp == "Residual"] <- "accession:trial + error"
      for (v in trt_gxt) comp <- sub(v, treatment_factors[[v]]$name, comp, fixed = TRUE)
      variance_components[[length(variance_components) + 1]] <- data.frame(trait = short_trait(t), component = comp, variance = unname(vc), stringsAsFactors = FALSE)
      res$engine_used <- f2$engine
      res$pedigree_used <- isTRUE(f2$pedigree)
      res$relationship <- f2$relationship
      res$model <- paste0(sub("^y ~", "BLUE ~", fml_txt), if (isTRUE(f2$pedigree)) paste0(", accession ~ N(0, ", f2$relationship, " s2g)"),
                          if (weighting == "inverse_se2") ", weights = 1/SE^2" else "")
      if (!is.null(f2$ancestors)) { f2$ancestors$trait <- t; ancestor_values[[length(ancestor_values) + 1]] <- f2$ancestors }
    }
    gv$trait <- t
    genotype_values[[length(genotype_values) + 1]] <- gv
    stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res, stringsAsFactors = FALSE)
  }
} else {
  # Single stage -----------------------------------------------------------------
  # The model is either assembled from the terms chosen in the interface
  # ("builder") or given as a custom lme4 formula ("custom"). Every term the
  # data cannot support is dropped and reported, never silently.
  ss_mode <- opt(ss_cfg, "mode", "builder")
  ss_env <- opt(ss_cfg, "env", "fixed")            # fixed | random | none
  ss_rep <- opt(ss_cfg, "rep", "auto")             # auto | fixed | random | none
  ss_block <- opt(ss_cfg, "block", "auto")         # auto | fixed | random | none
  ss_rowcol <- opt(ss_cfg, "rowcol", "auto")       # auto | random | none
  ss_trend <- opt(ss_cfg, "trend", "none")         # none | linear
  ss_gxe <- unlist(opt(ss_cfg, "gxe", if (identical(opt(ss_cfg, "include_gxe", TRUE), FALSE)) list() else list("trial")))

  if (ss_mode == "custom") {
    custom <- parse_custom_formula(opt(ss_cfg, "formula", ""), c(cov_vars, names(treatment_factors)))
    genotype_random <- custom$genotype_random
  }

  for (t in traits) {
    d <- dat[!is.na(dat[[t]]), ]
    d$y <- d[[t]]
    if (nrow(d) < 3) next
    log_step("Single stage: ", short_trait(t))
    # repeated measurements modelled one by one: one row per measurement
    rep_all <- identical(rep_mode[[t]], "all")
    if (rep_all) { d <- expand_repeated(d, t); report_expand(d, short_trait(t), t) }
    d <- add_model_factors(d)
    n_tr <- n_levels(d$trial)
    dropped <- character()
    used_vars <- c("y", "accession")
    # terms of the repeated-measures model: date within trial (or linear trend
    # in days), plot effect, genotype x date
    rep_terms <- function() {
      out <- character(); time_eff <- rep_time_effect(d)
      if (time_eff == "date") out <- c(out, "tr_date")
      if (time_eff == "linear") out <- c(out, if (n_tr > 1) "trial:mday" else "mday")
      if (time_eff == "none") dropped <<- c(dropped, "measurement date (one date per trial or no dates recorded)")
      if (any(table(as.character(d$unit)) > 1)) out <- c(out, "(1|plot_u)")
      if (rep_gxtime) {
        if (time_eff == "date") out <- c(out, "(1|accession:trial:date_f)")
        else dropped <<- c(dropped, "accession x date (needs several measurement dates and the date effect)")
      }
      used_vars <<- unique(c(used_vars, "plot_u", if (time_eff == "date") c("tr_date", "date_f"), if (time_eff == "linear") c("trial", "mday")))
      out
    }

    if (ss_mode == "custom") {
      if (cov_name(t) %in% custom$vars) { add_warning(short_trait(t), " is a covariate of the custom formula; it cannot be analysed with its own value as covariate and was skipped."); next }
      fml_txt <- custom$text
      # design factors switched off in every trial (factor_support)
      off <- Filter(function(v) v %in% names(FACTOR_LABEL) && !any(vapply(unique(as.character(d$trial)), function(x) trial_info[[x]]$support[[v]]$ok, logical(1))), custom$vars)
      if (length(off)) {
        add_warning(short_trait(t), ": the custom formula uses ", paste0("'", off, "'", collapse = ", "), " but the data do not support ", if (length(off) > 1) "these factors" else "this factor",
                    " in any trial (", paste(vapply(off, function(v) paste0(v, ": ", paste(unique(vapply(unique(as.character(d$trial)), function(x) trial_info[[x]]$support[[v]]$why, "")), collapse = ", ")), ""), collapse = "; "),
                    "); remove ", if (length(off) > 1) "them" else "it", " from the formula.")
        next
      }
      one <- Filter(function(v) v %in% c("trial", "location", "year", "check", "rep", "block") && n_levels(d[[v]]) < 2, custom$vars)
      if (length(one)) {
        add_warning(short_trait(t), ": the custom formula uses ", paste0("'", one, "'", collapse = ", "), " but ", if (length(one) > 1) "these variables have" else "it has",
                    " a single level in the data", if ("check" %in% one) " (no entry is marked as check)" else "", "; remove ", if (length(one) > 1) "them" else "it", " from the formula.")
        next
      }
      used_vars <- unique(c(used_vars, setdiff(custom$vars, c("mother", "father"))))   # unknown parents are allowed
      if (rep_all) {
        rt <- rep_terms()
        if (length(rt)) {
          fml_txt <- paste(fml_txt, "+", paste(rt, collapse = " + "))
          rep_warn_once(paste("custom", t), short_trait(t), ": all its repeated measurements are modelled; ", paste(pretty_model(rt), collapse = " + "), " was added to the custom formula.")
        }
      }
    } else {
      designs <- vapply(unique(as.character(d$trial)), function(x) trial_info[[x]]$design, character(1))
      all_rc <- all(vapply(unique(as.character(d$trial)), function(x) trial_info[[x]]$has_rowcol, logical(1)))
      terms <- character()
      add_term <- function(term, ok, label, vars) {
        if (ok) { terms <<- c(terms, term); used_vars <<- unique(c(used_vars, vars)) }
        else dropped <<- c(dropped, label)
      }
      # environment (trial) main effect
      if (ss_env != "none") add_term(if (ss_env == "random") "(1|trial)" else "trial", n_tr > 1, "trial (only one trial)", "trial")
      if (rep_all) terms <- c(terms, rep_terms())
      # why a design factor is not in the model: the factor_support() reasons
      why_off <- function(f) paste(unique(vapply(unique(as.character(d$trial)), function(x) trial_info[[x]]$support[[f]]$why, "")) , collapse = ", ")
      # replicates within trials
      rep_on <- if (ss_rep == "auto") n_levels(d$tr_rep) > n_tr else ss_rep != "none"
      if (rep_on) add_term(if (ss_rep == "fixed") "tr_rep" else "(1|tr_rep)", n_levels(d$tr_rep) > n_tr, paste0("replicate within trial (", why_off("rep"), ")"), "tr_rep")
      # incomplete blocks within replicates
      block_on <- if (ss_block == "auto") any(designs %in% c("alpha_lattice", "augmented")) && n_levels(d$tr_block) > n_levels(d$tr_rep) else ss_block != "none"
      if (block_on) add_term(if (ss_block == "fixed") "tr_block" else "(1|tr_block)", n_levels(d$tr_block) > n_levels(d$tr_rep), paste0("block within replicate (", why_off("block"), ")"), "tr_block")
      # rows and columns within trials
      rc_on <- if (ss_rowcol == "auto") any(designs == "row_column") || all_rc else ss_rowcol != "none"
      if (rc_on) {
        add_term("(1|tr_row)", n_levels(d$tr_row) > n_tr && sum(!is.na(d$row)) > 0, paste0("row within trial (", why_off("row"), ")"), "tr_row")
        add_term("(1|tr_col)", n_levels(d$tr_col) > n_tr && sum(!is.na(d$col)) > 0, paste0("column within trial (", why_off("col"), ")"), "tr_col")
      }
      # linear field trend within trials
      if (ss_trend == "linear") {
        rc_ok <- sum(!is.na(d$rowN) & !is.na(d$colN)) >= 0.9 * nrow(d) && n_levels(d$rowN) > 1
        add_term(if (n_tr > 1) "trial:rowN + trial:colN" else "rowN + colN", rc_ok, "linear row/column trend (row and column numbers missing)", c("trial", "rowN", "colN"))
      }
      # genotype x environment interactions
      for (gx in ss_gxe) {
        n_lv <- n_levels(d[[gx]])
        if (gx != "trial" && "trial" %in% ss_gxe && n_lv > 1 && same_grouping(as.character(d[[gx]]), as.character(d$trial))) {
          dropped <- c(dropped, paste0("accession x ", gx, " (each ", gx, " has one trial: the same as accession x trial)"))
          next
        }
        add_term(paste0("(1|accession:", gx, ")"), n_lv > 1, paste0("accession x ", gx, " (only one ", gx, ")"), gx)
      }
      # treatments: fixed main effect (unless the trial effect already holds it,
      # when the treatment is constant within every trial) and genotype x treatment
      for (v in trt_use) {
        nm <- treatment_factors[[v]]$name
        within_trial <- any(tapply(d[[v]], d$trial, function(x) length(unique(x)) > 1))
        if (n_levels(d[[v]]) < 2) { dropped <- c(dropped, paste0("treatment ", nm, " (one level in the data)")); next }
        if (ss_env == "fixed" && n_tr > 1 && !within_trial) { dropped <- c(dropped, paste0("treatment ", nm, " main effect (constant within each trial: held by the trial effect)")); next }
        add_term(v, TRUE, "", v)
      }
      for (v in trt_gxt) {
        nm <- treatment_factors[[v]]$name
        add_term(paste0("(1|accession:", v, ")"), n_levels(d[[v]]) > 1, paste0("accession x ", nm, " (one level in the data)"), v)
      }
      # covariates
      for (cv in cov_vars) {
        if (cv == cov_name(t)) next   # a trait is never its own covariate
        ok <- sum(!is.na(d[[cv]])) > 0.5 * nrow(d) && n_levels(d[[cv]]) > 1
        # constant within every trial: held by a fixed trial effect
        held <- ok && ss_env == "fixed" && n_tr > 1 && !any(tapply(d[[cv]], d$trial, function(x) n_levels(x) > 1))
        add_term(cv, ok && !held, paste0("covariate ", cov_label[[cv]], if (held) " (constant within each trial: held by the trial effect)" else " (missing or constant)"), cv)
      }
      # checks vs test entries (separates the check mean from the population
      # the BLUPs shrink to); only with the genotype random
      if (genotype_random && check_opt != "none") {
        has_both <- n_levels(d$check) > 1
        if (check_opt == "fixed" || has_both) add_term("check", has_both, "check vs test entries (no checks in the data)", "check")
      }
      # mother / father (GCA-like) effects
      if (gen_model == "parents") {
        if (genotype_random) { terms <- c(terms, "(1|mother)", "(1|father)") }
        else dropped <- c(dropped, "mother / father effects (need the genotype as random effect)")
      }
      g_term <- if (genotype_random) "(1|accession)" else "accession"
      fml_txt <- paste("y ~", paste(c(g_term, terms), collapse = " + "))
    }
    if (gen_model %in% c("pedigree", "genomic", "single_step") && !genotype_random) dropped <- c(dropped, paste0(REL_LABEL[[gen_model]], " relationship (needs the genotype as random effect)"))

    # keep only the plots that have every variable of the model
    cc <- complete.cases(d[, intersect(used_vars, names(d)), drop = FALSE])
    if (sum(!cc) > 0) add_warning(short_trait(t), ": ", sum(!cc), " plot(s) without values for all model terms were left out of the single-stage model.")
    d <- droplevels(d[cc, ])
    n_tr <- n_levels(d$trial)
    if (length(dropped)) add_warning(short_trait(t), ": term(s) not supported by the data were left out of the model: ", paste(dropped, collapse = "; "), ".")

    res <- list(trait = short_trait(t), n_trials = n_tr, n_accessions = n_levels(d$accession), mean = mean(d$y),
                var_g = NA_real_, var_ge = NA_real_, var_e = NA_real_, h2 = NA_real_, model = "",
                dropped_terms = paste(dropped, collapse = "; "), message = "OK", engine_used = NA_character_, pedigree_used = FALSE)
    r_bar <- plots_per_acc(d)
    m_bar <- meas_per_plot(d)
    f1 <- tryCatch(fit_model(d, fml_txt, genotype_random, label = paste0("single_", short_trait(t))), error = function(e) e)
    if (inherits(f1, "error")) {
      res$message <- conditionMessage(f1)
      add_warning(short_trait(t), ": the model could not be fitted (", conditionMessage(f1), ").")
      stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res, stringsAsFactors = FALSE)
      next
    }
    if (length(f1$notes)) add_warning(short_trait(t), ": ", paste(f1$notes, collapse = "; "), ".")
    vc <- f1$vc
    res$engine_used <- f1$engine
    res$pedigree_used <- isTRUE(f1$pedigree)
    res$relationship <- f1$relationship
    res$model <- pretty_model(paste0(fml_txt,
                        if (isTRUE(f1$pedigree)) paste0(", accession ~ N(0, ", f1$relationship, " s2g)")))
    res$var_e <- unname(vc["Residual"])
    gv <- f1$values
    rs <- f1$resid
    if (!is.null(f1$ancestors)) { f1$ancestors$trait <- t; ancestor_values[[length(ancestor_values) + 1]] <- f1$ancestors }

    for (k in names(vc)) {
      lab <- k
      for (v in names(treatment_factors)) lab <- sub(v, treatment_factors[[v]]$name, lab, fixed = TRUE)
      variance_components[[length(variance_components) + 1]] <- data.frame(trait = short_trait(t), component = pretty_model(lab), variance = unname(vc[k]), stringsAsFactors = FALSE)
    }
    # genotype x environment components, each divided by the (harmonic) mean
    # number of levels of its environment factor per accession
    gxe_names <- names(vc)[grepl("(^|:)accession(:|$)", names(vc)) & names(vc) != "accession"]
    gxe_part <- 0
    if (length(gxe_names)) {
      res$var_ge <- sum(vc[gxe_names])
      for (k in gxe_names) {
        other <- setdiff(strsplit(k, ":", fixed = TRUE)[[1]], "accession")
        other <- other[other %in% names(d)]
        n_k <- if (length(other)) { u <- unique(data.frame(a = d$accession, e = do.call(paste, d[, other, drop = FALSE]))); 1 / mean(1 / as.numeric(table(u$a))) } else 1
        gxe_part <- gxe_part + vc[k] / n_k
      }
    }
    if (genotype_random) {
      res$var_g <- unname(sum(vc[intersect(c("accession", "mother", "father"), names(vc))]))
      # plot effect of repeated measurements: once per plot; residual: per measurement
      vp <- if ("plot_u" %in% names(vc)) vc[["plot_u"]] else 0
      res$h2 <- unname(res$var_g / (res$var_g + gxe_part + (vp + res$var_e / m_bar) / r_bar))
    }
    if (rep_all && length(rs) == nrow(d)) {
      a <- tapply(as.numeric(rs), as.character(d$unit), mean)
      add_residuals(names(a), t, as.numeric(a))
    } else add_residuals(d$unit, t, rs)
    gv$trait <- t
    genotype_values[[length(genotype_values) + 1]] <- gv
    stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res, stringsAsFactors = FALSE)
  }
}
stage2_summary <- if (length(stage2_summary)) do.call(rbind, stage2_summary) else NULL
genotype_values <- if (length(genotype_values)) do.call(rbind, genotype_values) else NULL
# the occasion traits of multi-trait groups give way to their trait again
if (length(mt_groups)) {
  traits <- unique(vapply(traits, function(x) { g <- Filter(function(g) x %in% c(g$y, g$c), mt_groups); if (length(g)) g[[1]]$trait else x }, ""))
}
if (is.null(genotype_values)) stop("No model could be fitted. Check the warnings and the trait data.")

# wide table accession x trait
traits_ok <- unique(genotype_values$trait)
wide <- data.frame(accession = sort(unique(genotype_values$accession)), stringsAsFactors = FALSE)
for (t in traits_ok) {
  g <- genotype_values[genotype_values$trait == t, ]
  wide[[t]] <- g$value[match(wide$accession, g$accession)]
}

# -----------------------------------------------------------------------------
# Step 4 - selection index
# -----------------------------------------------------------------------------
idx_cfg <- opt(recipe, "index", list())
index_result <- NULL

compute_index <- function(mat, cfg_traits, method) {
  # mat: data.frame with columns = traits (same names as in cfg_traits)
  tr <- names(cfg_traits)
  score <- rep(0, nrow(mat))
  for (t in tr) {
    w <- as.numeric(opt(cfg_traits[[t]], "weight", 1))
    dir <- if (identical(opt(cfg_traits[[t]], "direction", "increase"), "decrease")) -1 else 1
    x <- mat[[t]]
    if (method == "rank_sum") {
      # Mulamba & Mock: rank 1 = best; the index is the negative weighted rank sum
      rk <- rank(-dir * x, ties.method = "average", na.last = "keep")
      score <- score - w * rk
    } else {
      s <- sd(x, na.rm = TRUE)
      z <- if (is.finite(s) && s > 0) (x - mean(x, na.rm = TRUE)) / s else rep(0, length(x))
      score <- score + w * dir * z
    }
  }
  score
}

idx_traits_cfg <- list()
if (isTRUE(opt(idx_cfg, "enabled", FALSE))) {
  cfg_tr <- opt(idx_cfg, "traits", list())
  for (nm in names(cfg_tr)) {
    full <- if (nm %in% traits_ok) nm else traits_ok[short_trait(traits_ok) == short_trait(nm)][1]
    if (!is.na(full) && !is.null(full) && as.numeric(opt(cfg_tr[[nm]], "weight", 0)) != 0) idx_traits_cfg[[full]] <- cfg_tr[[nm]]
  }
  if (length(idx_traits_cfg) == 0) {
    add_warning("Selection index enabled but no trait has a non-zero weight; index skipped.")
  } else {
    method <- opt(idx_cfg, "method", "zscore")
    sel_pct <- as.numeric(opt(idx_cfg, "selection_pct", 10))
    complete <- complete.cases(wide[, names(idx_traits_cfg), drop = FALSE])
    if (sum(!complete) > 0) add_warning(sum(!complete), " accession(s) without values for all index traits were left out of the index.")
    w2 <- wide[complete, , drop = FALSE]
    w2$index <- compute_index(w2, idx_traits_cfg, method)
    w2 <- w2[order(-w2$index), ]
    w2$rank <- seq_len(nrow(w2))
    n_sel <- max(1, round(nrow(w2) * sel_pct / 100))
    w2$selected <- w2$rank <= n_sel
    h2_of <- function(t) {
      if (is.null(stage2_summary)) return(NA_real_)
      v <- stage2_summary$h2[stage2_summary$trait == short_trait(t)]
      if (length(v)) v[1] else NA_real_
    }
    # selection accuracy: mean over the accessions of sqrt(1 - PEV / var_g)
    # (genotype random, from the standard errors of the BLUPs), otherwise
    # sqrt(H2) (accuracy of selection on entry means)
    accuracy_of <- function(t) {
      vg <- if (is.null(stage2_summary)) NA_real_ else suppressWarnings(as.numeric(stage2_summary$var_g[stage2_summary$trait == short_trait(t)][1]))
      se <- suppressWarnings(as.numeric(genotype_values$se[genotype_values$trait == t]))
      se <- se[is.finite(se)]
      if (genotype_random && is.finite(vg) && vg > 0 && length(se)) return(list(value = mean(sqrt(pmax(0, 1 - se^2 / vg))), basis = "pev"))
      h2 <- h2_of(t)
      if (is.finite(h2)) list(value = sqrt(max(0, h2)), basis = "h2") else list(value = NA_real_, basis = "")
    }
    gains <- do.call(rbind, lapply(traits_ok, function(t) {
      x <- w2[[t]]; xs <- x[w2$selected]
      ac <- accuracy_of(t)
      s <- mean(xs, na.rm = TRUE) - mean(x, na.rm = TRUE)
      h2 <- h2_of(t)
      data.frame(trait = short_trait(t), in_index = t %in% names(idx_traits_cfg),
                 weight = if (t %in% names(idx_traits_cfg)) as.numeric(opt(idx_traits_cfg[[t]], "weight", 0)) else 0,
                 direction = if (t %in% names(idx_traits_cfg)) opt(idx_traits_cfg[[t]], "direction", "increase") else "",
                 mean_population = mean(x, na.rm = TRUE), mean_selected = mean(xs, na.rm = TRUE),
                 selection_differential = s, selection_differential_pct = 100 * s / abs(mean(x, na.rm = TRUE)),
                 h2 = h2,
                 expected_gain = if (!genotype_random && is.finite(h2)) h2 * s else s,
                 accuracy = ac$value, accuracy_basis = ac$basis,
                 stringsAsFactors = FALSE)
    }))
    # accuracy of the index: mean of its traits' accuracies, weighted by |weight|
    ia <- gains[gains$in_index & is.finite(gains$accuracy), ]
    index_accuracy <- if (!nrow(ia)) NA_real_ else if (sum(abs(ia$weight)) > 0) sum(abs(ia$weight) * ia$accuracy) / sum(abs(ia$weight)) else mean(ia$accuracy)
    index_result <- list(method = method, selection_pct = sel_pct, n_selected = n_sel, n_ranked = nrow(w2),
                         table = w2, gains = gains, accuracy = index_accuracy,
                         note = if (genotype_random) "Values are BLUPs (already shrunk by heritability): the expected gain equals the selection differential on BLUPs." else "Expected gain = h2 x selection differential on BLUEs.")
  }
}

# -----------------------------------------------------------------------------
# Step 5 - environmental zones
# -----------------------------------------------------------------------------
zone_results <- list()
lin_test <- function(d, envs) {
  # d: plot data with env, accession, rep_eff, trial, y
  d <- d[d$env %in% envs, ]
  common <- names(which(table(unique(d[, c("accession", "env")])$accession) == length(envs)))
  d <- d[d$accession %in% common, ]
  n_g <- length(common); n_e <- length(envs)
  if (n_g < 2 || n_e < 2) return(c(ss = NA, df = NA, f = NA, p = NA, n_g = n_g))
  cm <- tapply(d$y, list(d$accession, d$env), mean)
  nrep <- as.vector(tapply(d$y, list(d$accession, d$env), length))
  r_eff <- 1 / mean(1 / nrep[!is.na(nrep) & nrep > 0])
  inter <- sweep(sweep(cm, 1, rowMeans(cm)), 2, colMeans(cm)) + mean(cm)
  ss <- r_eff * sum(inter^2, na.rm = TRUE)
  df <- (n_g - 1) * (n_e - 1)
  d$accession <- factor(d$accession); d$env <- factor(d$env); d$er <- factor(paste(d$env, d$trial, d$rep_eff))
  fml <- if (n_levels(d$er) > n_e) y ~ env + er + accession + env:accession else y ~ env + accession + env:accession
  fit <- tryCatch(lm(fml, data = d), error = function(e) NULL)
  if (is.null(fit) || df.residual(fit) < 1) return(c(ss = ss, df = df, f = NA, p = NA, n_g = n_g))
  mse <- sum(residuals(fit)^2) / df.residual(fit)
  f <- (ss / df) / mse
  c(ss = ss, df = df, f = f, p = pf(f, df, df.residual(fit), lower.tail = FALSE), n_g = n_g)
}

lin_zones <- function(d, alpha) {
  envs <- sort(unique(d$env))
  if (length(envs) < 2) return(NULL)
  pairs <- combn(envs, 2, simplify = FALSE)
  pw <- do.call(rbind, lapply(pairs, function(p) { r <- lin_test(d, p); data.frame(env1 = p[1], env2 = p[2], ss = r["ss"], f = r["f"], p_value = r["p"], n_genotypes = r["n_g"]) }))
  pw$compatible <- !is.na(pw$p_value) & pw$p_value >= alpha
  remaining <- envs; groups <- list()
  while (length(remaining) >= 2) {
    cand <- pw[pw$env1 %in% remaining & pw$env2 %in% remaining & pw$compatible, ]
    if (!nrow(cand)) break
    cand <- cand[order(cand$ss), ]
    grp <- c(cand$env1[1], cand$env2[1])
    repeat {
      add <- setdiff(remaining, grp)
      if (!length(add)) break
      tests <- do.call(rbind, lapply(add, function(e) { r <- lin_test(d, c(grp, e)); data.frame(env = e, ss = r["ss"], p = r["p"]) }))
      tests <- tests[!is.na(tests$p) & tests$p >= alpha, ]
      if (!nrow(tests)) break
      grp <- c(grp, tests$env[which.min(tests$ss)])
    }
    groups[[length(groups) + 1]] <- grp
    remaining <- setdiff(remaining, grp)
  }
  for (e in remaining) groups[[length(groups) + 1]] <- e
  rownames(pw) <- NULL
  list(groups = groups, pairwise = pw)
}

cor_zones <- function(m, threshold, min_common) {
  # m: matrix accession x env of genotype values
  envs <- colnames(m)
  if (length(envs) < 2) return(NULL)
  cm <- matrix(NA_real_, length(envs), length(envs), dimnames = list(envs, envs))
  for (i in seq_along(envs)) for (j in seq_along(envs)) {
    ok <- !is.na(m[, i]) & !is.na(m[, j])
    cm[i, j] <- if (sum(ok) >= min_common) cor(m[ok, i], m[ok, j]) else NA
  }
  dist_m <- 1 - cm
  dist_m[is.na(dist_m)] <- 2
  diag(dist_m) <- 0
  hc <- hclust(as.dist(dist_m), method = "average")
  cl <- cutree(hc, h = 1 - threshold)
  groups <- lapply(sort(unique(cl)), function(k) names(cl)[cl == k])
  groups <- groups[order(-lengths(groups))]
  list(groups = groups, correlation = list(environments = envs[hc$order], matrix = round(cm[hc$order, hc$order], 4)))
}

if (isTRUE(opt(zones_cfg, "enabled", FALSE)) && !is.null(stage1_means)) {
  z_method <- opt(zones_cfg, "method", "correlation")
  z_alpha <- as.numeric(opt(zones_cfg, "alpha", 0.05))
  z_thr <- as.numeric(opt(zones_cfg, "threshold", 0.5))
  z_top <- as.numeric(opt(zones_cfg, "top_n", 10))
  targets <- unlist(opt(zones_cfg, "targets", list("index")))
  z_min_common <- max(5, as.numeric(opt(zones_cfg, "min_common", 5)))
  # minimum environments of a zone an accession must be tested in to be ranked
  # there (capped by the size of the zone); 1 = every accession, as before 1.6
  z_min_env <- max(1, suppressWarnings(as.integer(opt(zones_cfg, "min_env", 1))), na.rm = TRUE)

  # accessions that define the zones (the rankings always cover all accessions):
  # all, the checks (entry type check/control) or a Breedbase list (items added
  # by the web server)
  z_acc_cfg <- opt(zones_cfg, "accessions", list())
  z_acc_set <- opt(z_acc_cfg, "set", "all")
  z_acc_label <- "all accessions"
  z_acc <- NULL
  if (z_acc_set %in% c("checks", "list")) {
    all_acc <- unique(as.character(dat$accession))
    if (z_acc_set == "checks") {
      want <- names(acc_is_check)[acc_is_check %in% TRUE]
      what <- "check accessions"
      z_acc_label <- "check accessions"
    } else {
      want <- trimws(as.character(unlist(opt(z_acc_cfg, "items", list()))))
      lname <- opt(z_acc_cfg, "list_name", "")
      what <- paste0("accessions of the list", if (nzchar(lname)) paste0(" '", lname, "'") else "")
      z_acc_label <- what
      n_out <- length(setdiff(want, all_acc))
      if (n_out > 0 && length(intersect(want, all_acc)) >= 3)
        add_warning("Zoning: ", n_out, " of the ", length(unique(want)), " ", what, " are not in the dataset and were ignored.")
    }
    z_acc <- intersect(all_acc, want)
    if (length(z_acc) < 3) {
      add_warning("Zoning: only ", length(z_acc), " ", what, " in the dataset (at least 3 are needed to group environments); all accessions were used instead.")
      z_acc <- NULL
      z_acc_label <- "all accessions"
    } else if (length(z_acc) < z_min_common) {
      add_warning("Zoning: the zones rest on only ", length(z_acc), " ", what, "; correlations between environments on so few accessions are unreliable.")
      z_min_common <- length(z_acc)
    }
  }

  # environment-level genotype values (average of trial means inside an env)
  env_vals <- aggregate(value ~ accession + env + trait, data = stage1_means, FUN = mean)
  env_meta <- unique(dat[, c("env", "location", "year", "trial")])
  env_meta <- aggregate(cbind(location, year, trial) ~ env, data = env_meta, FUN = function(x) paste(unique(x), collapse = ", "))

  target_list <- list()
  for (tg in targets) {
    if (tg == "index") {
      if (length(idx_traits_cfg) == 0) { add_warning("Zoning on the index requires an enabled selection index."); next }
      # per environment index from z-scores of the environment means
      envs <- unique(env_vals$env)
      rows <- list()
      for (e in envs) {
        ev <- env_vals[env_vals$env == e, ]
        mat <- data.frame(accession = unique(ev$accession), stringsAsFactors = FALSE)
        for (t in names(idx_traits_cfg)) mat[[t]] <- ev$value[ev$trait == t][match(mat$accession, ev$accession[ev$trait == t])]
        if (!all(names(idx_traits_cfg) %in% unique(ev$trait))) next
        mat <- mat[complete.cases(mat), , drop = FALSE]
        if (nrow(mat) < 3) next
        rows[[length(rows) + 1]] <- data.frame(accession = mat$accession, env = e, value = compute_index(mat, idx_traits_cfg, opt(idx_cfg, "method", "zscore")))
      }
      if (!length(rows)) next
      target_list[["Selection index"]] <- list(values = do.call(rbind, rows), trait = NA)
    } else {
      full <- if (tg %in% traits_ok) tg else traits_ok[short_trait(traits_ok) == short_trait(tg)][1]
      if (is.na(full)) next
      target_list[[short_trait(full)]] <- list(values = env_vals[env_vals$trait == full, c("accession", "env", "value")], trait = full)
    }
  }

  # traits where lower values are better (from the index directions)
  decreasing_targets <- short_trait(names(idx_traits_cfg)[vapply(idx_traits_cfg, function(x) identical(opt(x, "direction", "increase"), "decrease"), logical(1))])

  for (tname in names(target_list)) {
    tv <- target_list[[tname]]
    m <- tapply(tv$values$value, list(tv$values$accession, tv$values$env), mean)
    # the zones are built on the chosen accessions only
    m_zone <- if (is.null(z_acc)) m else m[rownames(m) %in% z_acc, , drop = FALSE]
    method_used <- z_method
    zr <- NULL
    if (z_method == "lin" && !is.na(tv$trait)) {
      d <- dat[!is.na(dat[[tv$trait]]), ]
      if (!is.null(z_acc)) d <- d[as.character(d$accession) %in% z_acc, ]
      d$y <- d[[tv$trait]]
      zr <- lin_zones(d, z_alpha)
    } else {
      if (z_method == "lin") method_used <- "correlation"
      zr <- cor_zones(m_zone, z_thr, z_min_common)
    }
    if (is.null(zr)) { add_warning("Zoning for ", tname, " needs at least two environments."); next }
    membership <- do.call(rbind, lapply(seq_along(zr$groups), function(k) data.frame(zone = paste0("Zone ", k), env = zr$groups[[k]], stringsAsFactors = FALSE)))
    membership <- merge(membership, env_meta, by = "env", all.x = TRUE)
    membership <- membership[order(membership$zone, membership$env), ]
    # best accessions inside each zone
    top <- do.call(rbind, lapply(seq_along(zr$groups), function(k) {
      envs <- zr$groups[[k]]
      sub <- m[, colnames(m) %in% envs, drop = FALSE]
      v <- rowMeans(sub, na.rm = TRUE)
      n_env <- rowSums(!is.na(sub))
      v <- v[is.finite(v) & n_env >= min(z_min_env, length(envs))]
      if (!length(v)) return(NULL)
      ord <- names(sort(v, decreasing = !(tname %in% decreasing_targets)))
      ord <- head(ord, z_top)
      data.frame(zone = paste0("Zone ", k), rank = seq_along(ord), accession = ord, value = unname(v[ord]), n_env = unname(n_env[ord]), stringsAsFactors = FALSE)
    }))
    # every accession in every zone: mean, rank inside the zone (1 = best),
    # environments tested (where each genotype does best)
    higher_better <- !(tname %in% decreasing_targets)
    genotype_zones <- do.call(rbind, lapply(seq_along(zr$groups), function(k) {
      sub <- m[, colnames(m) %in% zr$groups[[k]], drop = FALSE]
      v <- rowMeans(sub, na.rm = TRUE)
      n_env <- rowSums(!is.na(sub))
      keep <- is.finite(v) & n_env >= min(z_min_env, length(zr$groups[[k]]))
      if (!any(keep)) return(NULL)
      v <- v[keep]; n_env <- n_env[keep]
      data.frame(zone = paste0("Zone ", k), accession = names(v), value = unname(v), n_env = unname(n_env),
                 rank = rank(if (higher_better) -v else v, ties.method = "min"), n_ranked = length(v), stringsAsFactors = FALSE, row.names = NULL)
    }))
    zone_results[[length(zone_results) + 1]] <- list(
      target = tname, method = method_used,
      n_zones = length(zr$groups),
      higher_is_better = higher_better,
      accessions_used = z_acc_label,
      n_accessions_used = if (is.null(z_acc)) nrow(m) else nrow(m_zone),
      min_env = z_min_env,
      membership = membership,
      pairwise = zr$pairwise, correlation = zr$correlation,
      top = top,
      genotype_zones = genotype_zones)
  }
}

# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------
wide_out <- wide
names(wide_out) <- c("accession", short_trait(names(wide)[-1]))
s1_out <- stage1_means
if (!is.null(s1_out)) s1_out$trait <- short_trait(s1_out$trait)
gv_out <- genotype_values
gv_out$trait_full <- gv_out$trait
gv_out$trait <- short_trait(gv_out$trait)
# parents of each accession, when the pedigree is known
if (!is.null(pedigree)) {
  wide_out$mother <- pedigree$mother[match(wide_out$accession, pedigree$accession)]
  wide_out$father <- pedigree$father[match(wide_out$accession, pedigree$accession)]
}
# breeding values of ancestors without phenotypes (pedigree model)
anc_out <- if (length(ancestor_values)) do.call(rbind, ancestor_values) else NULL
if (!is.null(anc_out)) anc_out$trait <- short_trait(anc_out$trait)

# CSV files for download
write_csv <- function(x, suffix) {
  if (is.null(x) || !nrow(x)) return(NULL)
  f <- paste0(output_prefix, "_", suffix, ".csv")
  write.csv(x, f, row.names = FALSE, na = "")
  basename(f)
}
files <- list(
  genotype_values = write_csv(wide_out, "genotype_values"),
  stage1_means = write_csv(s1_out, "stage1_means"),
  outliers = write_csv(outliers, "outliers"),
  ancestors = write_csv(anc_out, "ancestor_breeding_values"),
  index = if (!is.null(index_result)) write_csv({ x <- index_result$table; names(x) <- short_trait(names(x)); x }, "selection_index") else NULL,
  zones = if (length(zone_results)) write_csv(do.call(rbind, lapply(zone_results, function(z) cbind(target = z$target, z$membership))), "zones") else NULL
)

if (!is.null(index_result)) names(index_result$table) <- short_trait(names(index_result$table))

# plot level data for the field maps of the results dashboard: values after
# outlier removal and model residuals for every trait
plots_out <- data.frame(unit = dat$unit, trial = dat$trial, location = dat$location, year = dat$year,
                        accession = dat$accession, rep = dat$rep_eff, block = dat$block,
                        row = dat$row, col = dat$col, stringsAsFactors = FALSE)
resid_all <- if (length(residual_rows)) do.call(rbind, residual_rows) else NULL
for (t in traits) {
  st <- short_trait(t)
  plots_out[[st]] <- dat[[t]]
  if (!is.null(resid_all)) {
    rr <- resid_all[resid_all$trait == t, ]
    if (nrow(rr)) plots_out[[paste0("resid:", st)]] <- rr$resid[match(plots_out$unit, rr$unit)]
  }
}
variance_components <- if (length(variance_components)) do.call(rbind, variance_components) else NULL

trial_table <- do.call(rbind, lapply(trial_info, function(x) data.frame(
  trial = x$trial, location = x$location, year = x$year, design = x$design_label,
  spatial_layout = x$has_rowcol, n_plots = x$n_plots, n_accessions = x$n_accessions,
  factors_not_used = paste(unlist(lapply(names(FACTOR_LABEL), function(f) if (!x$support[[f]]$ok && !grepl("^(one replicate|one block|no row|no column|the blocks are the replicates)", x$support[[f]]$why))
    paste0(tolower(FACTOR_LABEL[[f]]), " (", x$support[[f]]$why, ")"))), collapse = "; "), stringsAsFactors = FALSE)))

result <- list(
  version = SF_VERSION,
  strategy = strategy,
  engine = engine,
  genetic_model = gen_model,
  genotype_effect = if (genotype_random) "random" else "fixed",
  value_label = if (!genotype_random) "BLUE" else if (gen_model == "pedigree") "EBV" else "BLUP",
  summary = list(n_plots = nrow(dat), n_accessions = n_levels(dat$accession), n_trials = length(trials),
                 n_environments = n_levels(dat$env), traits = short_trait(traits), traits_full = traits,
                 environment_unit = env_unit),
  trials = trial_table,
  treatments = unname(lapply(treatment_factors, function(f) {
    by_trial <- tapply(f$values, dat$trial, function(x) paste(sort(unique(x)), collapse = ", "))
    list(name = f$name, variable = f$var, source = f$source, levels = sort(unique(f$values)),
         used = f$var %in% trt_use, gxt = f$var %in% trt_gxt,
         by_trial = data.frame(trial = names(by_trial), levels = unname(by_trial), stringsAsFactors = FALSE))
  })),
  repeated = list(time = rep_time, gxtime = rep_gxtime, traits = repeated_info),
  multi_trait = if (length(multi_trait_out)) multi_trait_out else NULL,
  software = software_used(),
  covariates = unname(as.list(cov_label)),
  outliers = outliers,
  outlier_summary = outlier_summary,
  stage1 = stage1_summary,
  stage2 = stage2_summary,
  genotype_values = wide_out,
  genotype_values_long = gv_out,
  ancestor_values = anc_out,
  stage1_means = s1_out,
  variance_components = variance_components,
  plots = plots_out,
  recipe = recipe,
  index = index_result,
  zones = zone_results,
  files = files,
  warnings = warnings_log
)

writeLines(toJSON(result, dataframe = "rows", na = "null", auto_unbox = TRUE, digits = 8, null = "null"), output_file)
log_step("Done. Results written to ", output_file)
