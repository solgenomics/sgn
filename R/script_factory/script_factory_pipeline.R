# =============================================================================
# Breedbase Script Factory - analysis pipeline
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
#   4. Selection index (weighted Z-score or Mulamba & Mock rank sum) with
#      selection differentials and expected genetic gains.
#   5. Environmental zoning (Lin 1982 GxE F-test grouping or genetic
#      correlation clustering) for each trait and/or the selection index.
#
# Usage:
#   Rscript script_factory_pipeline.R <phenotype_file> <recipe_json> <output_json> [exclusions_json] [output_prefix]
#
# When exported from the Script Factory page, the recipe is embedded at the top
# of the script as RECIPE_JSON and the usage becomes:
#   Rscript my_script.R <phenotype_file> <output_json>
#
# Author: Breedbase Script Factory
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(lme4)
})

SF_VERSION <- "1.4"

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
  warnings_log <<- c(warnings_log, msg)
  message("WARNING: ", msg)
}

log_step <- function(...) message("[script_factory] ", paste0(...))

# safe accessor with default
opt <- function(x, name, default) {
  if (is.null(x) || is.null(x[[name]])) return(default)
  v <- x[[name]]
  if (is.list(v) && length(v) == 0) return(default)
  v
}

short_trait <- function(x) sub("\\|.*$", "", x)

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

for (t in traits) dat[[t]] <- suppressWarnings(as.numeric(pheno[[t]]))
for (k in names(treatment_factors)) dat[[k]] <- treatment_factors[[k]]$values
if (length(treatment_factors)) log_step("Treatments: ", paste(vapply(treatment_factors, function(f) paste0(f$name, " (", length(unique(f$values)), " levels)"), ""), collapse = ", "),
                                        "; in the models: ", if (length(c(trt_use, trt_gxt))) paste(unique(c(trt_use, trt_gxt)), collapse = ", ") else "none")
traits <- traits[vapply(traits, function(t) sum(!is.na(dat[[t]])) > 0, logical(1))]
if (length(traits) == 0) stop("None of the selected traits has numeric data in this dataset. Available traits: ", paste(short_trait(available_traits), collapse = ", "))
log_step("Traits: ", paste(short_trait(traits), collapse = ", "))

# -----------------------------------------------------------------------------
# Design detection per trial
# -----------------------------------------------------------------------------
n_levels <- function(x) length(unique(x[!is.na(x) & x != ""]))

detect_trial_design <- function(d) {
  txt <- tolower(paste(unique(d$design_raw[!is.na(d$design_raw)]), collapse = " "))
  n_rep <- n_levels(d$rep)
  n_block <- n_levels(d$block)
  has_rowcol <- sum(!is.na(d$row) & !is.na(d$col)) >= 0.9 * nrow(d) && n_levels(d$row) > 1 && n_levels(d$col) > 1
  block_ne_rep <- n_rep > 0 && n_block > 0 && any(d$block != d$rep, na.rm = TRUE)
  replicated <- any(table(d$accession) > 1)

  design <- if (grepl("row.?col|rowcol|spatial|p-rep|prep", txt)) {
    "row_column"
  } else if (grepl("augmented|madii|\\bmad\\b|aug", txt)) {
    "augmented"
  } else if (grepl("alpha|lattice|incomplete", txt) || (n_rep > 1 && n_block > n_rep && block_ne_rep)) {
    "alpha_lattice"
  } else if (grepl("rcbd|randomized complete block|randomised complete block", txt) || n_rep > 1 || n_block > 1) {
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
flag_outlier <- function(idx, trait, reason) {
  if (length(idx) == 0) return(invisible())
  outlier_rows[[length(outlier_rows) + 1]] <<- data.frame(
    unit = dat$unit[idx], trial = dat$trial[idx], accession = dat$accession[idx],
    trait = trait, value = dat[[trait]][idx], reason = reason, stringsAsFactors = FALSE)
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

n_before <- sapply(traits, function(t) sum(!is.na(dat[[t]])))

if (out_method == "iqr") {
  g <- group_vector(out_group)
  for (t in traits) {
    y <- dat[[t]]
    for (lvl in unique(g)) {
      ii <- which(g == lvl & !is.na(y))
      if (length(ii) < 4) next
      q <- quantile(y[ii], c(0.25, 0.75), type = 7, names = FALSE)
      iqr <- q[2] - q[1]
      lo <- q[1] - iqr_k * iqr
      hi <- q[2] + iqr_k * iqr
      bad <- ii[y[ii] < lo | y[ii] > hi]
      flag_outlier(bad, t, sprintf("IQR (k = %.2g) within %s", iqr_k, gsub("_", " x ", out_group)))
      dat[[t]][bad] <- NA
    }
  }
} else if (out_method == "madr") {
  # Bernal-Vasquez, Utz & Piepho (2016): Bonferroni-Holm test on residuals
  # re-scaled by the median absolute deviation (BH-MADR).
  for (t in traits) {
    for (tr in trials) {
      ii <- which(dat$trial == tr & !is.na(dat[[t]]))
      d <- dat[ii, ]
      if (nrow(d) < 6 || n_levels(d$accession) < 2) next
      fml <- if (n_levels(d$rep_eff) > 1) y ~ accession + rep_eff else y ~ accession
      d$y <- d[[t]]
      fit <- tryCatch(lm(fml, data = d), error = function(e) NULL)
      if (is.null(fit) || df.residual(fit) < 2) next
      r <- residuals(fit)
      madv <- mad(r, constant = 1.4826)
      if (!is.finite(madv) || madv <= 0) next
      z <- r / madv
      p <- 2 * pnorm(-abs(z))
      bad <- ii[p.adjust(p, "holm") < madr_alpha]
      flag_outlier(bad, t, sprintf("BH-MADR (alpha = %.2g)", madr_alpha))
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
      for (t in tt) {
        bad <- ii[!is.na(dat[[t]][ii])]
        flag_outlier(bad, t, "Excluded individually")
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
  # average the non-accession columns over the data (equal weights over levels)
  cn <- colnames(X)
  acc_cols <- paste0("accession", acc_levels)
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
# BLUPF90 engine
# -----------------------------------------------------------------------------
# The mixed models can be fitted with blupf90+ (BLUPF90 family, Misztal et al.;
# Fortran, sparse AI-REML) instead of lme4. Phenotype-only models. R only
# writes the data and parameter files in the native BLUPF90 format and reads
# the solutions back:
#   - every factor is coded as consecutive integers here (no renumf90 needed),
#     so the solutions map straight back to names;
#   - fixed factors are 'cross' effects, numeric covariates 'cov' effects
#     (nested in a factor for terms such as trial:rowN);
#   - genotype BLUEs: when the other fixed effects need few columns they are
#     coded as centred covariates instead, which makes each genotype solution
#     an estimable BLUE (mean over the other fixed effects) with an exact
#     standard error, the quantity accession_blues() computes for lme4 fits.
# The program is looked up in $BLUPF90_DIR, then in the PATH. The parameter and
# data files of every fit are kept in <output_prefix>_blupf90/ so the analysis
# can be inspected or re-run outside Breedbase.

f90_program <- function() {
  dir <- Sys.getenv("BLUPF90_DIR")
  if (nzchar(dir) && file.exists(file.path(dir, "blupf90+"))) return(file.path(dir, "blupf90+"))
  p <- Sys.which("blupf90+")
  if (nzchar(p)) unname(p) else ""
}

engine <- opt(recipe, "engine", "lme4")   # lme4 | blupf90
if (!engine %in% c("lme4", "blupf90")) engine <- "lme4"
if (engine == "blupf90" && !nzchar(f90_program())) {
  add_warning("BLUPF90+ is not installed on the analysis server; the models were fitted with lme4 instead.")
  engine <- "lme4"
}
use_f90 <- engine == "blupf90"
f90_keep_dir <- paste0(output_prefix, "_blupf90")
f90_n_fits <- 0
F90_DENSE_MAX <- 60   # max. fixed covariate columns for exact BLUE standard errors

# split the right-hand side of a lme4 formula into fixed terms and random
# grouping terms; random terms other than (1|a), (1|a:b) or (1|a/b) are
# returned in 'unsupported'
split_lme4_terms <- function(rhs) {
  rhs <- gsub("\\s+", "", rhs)
  random <- character(); unsupported <- character()
  for (m in regmatches(rhs, gregexpr("\\([^()]*\\|[^()]*\\)", rhs))[[1]]) {
    inner <- substr(m, 2, nchar(m) - 1)
    lhs <- sub("\\|.*$", "", inner); grp <- sub("^[^|]*\\|", "", inner)
    if (lhs != "1" || grepl("[^A-Za-z0-9_.:/]", grp)) { unsupported <- c(unsupported, m); next }
    parts <- strsplit(grp, "/", fixed = TRUE)[[1]]
    for (k in seq_along(parts)) random <- c(random, paste(parts[1:k], collapse = ":"))
  }
  fixed_txt <- gsub("-", "+-", gsub("\\([^()]*\\|[^()]*\\)", "", rhs), fixed = TRUE)
  fixed <- strsplit(fixed_txt, "+", fixed = TRUE)[[1]]
  fixed <- fixed[nzchar(fixed) & !fixed %in% c("0", "1", "-1")]
  if (any(grepl("^-", fixed))) unsupported <- c(unsupported, fixed[grepl("^-", fixed)])
  fixed <- fixed[!grepl("^-", fixed)]
  list(fixed = unique(fixed), random = unique(random), unsupported = unsupported)
}

# integer codes 1..n of the combination of factor columns (0 = missing)
f90_codes <- function(d, vars) {
  key <- do.call(paste, c(lapply(vars, function(v) as.character(d[[v]])), sep = "\r"))
  na <- Reduce(`|`, lapply(vars, function(v) is.na(d[[v]])))
  f <- factor(ifelse(na, NA, key))
  list(code = ifelse(is.na(f), 0L, as.integer(f)), n = nlevels(f), labels = gsub("\r", ":", levels(f), fixed = TRUE))
}

# Pedigree of a set of accessions: the accessions first (codes 1..n), then all
# their known ancestors; mother / father as codes (0 = unknown).
ped_codes <- function(acc_levels) {
  P <- pedigree
  keep <- character(); todo <- acc_levels
  while (length(todo)) {
    keep <- union(keep, todo)
    i <- match(todo, P$accession)
    par <- c(P$mother[i], P$father[i])
    todo <- setdiff(par[!is.na(par)], keep)
  }
  ids <- c(acc_levels, setdiff(keep, acc_levels))
  i <- match(ids, P$accession)
  s <- match(P$mother[i], ids); d <- match(P$father[i], ids)
  s[is.na(s)] <- 0L; d[is.na(d)] <- 0L
  data.frame(id = ids, code = seq_along(ids), s = s, d = d, stringsAsFactors = FALSE)
}

# Fit y ~ genotype + fixed_terms + random_terms with blupf90+.
#   d                data with columns y, accession, unit and the model variables
#   fixed_terms      fixed terms other than the genotype (formula syntax: a, a:b, a*b, a:x)
#   random_terms     random grouping factors, e.g. "rep_eff" or "accession:trial"
#   genotype_random  genotype as random (BLUPs) or fixed (BLUEs)
#   w                optional weights (residual variance divided by w)
#   fixed_mean_by    factor over which the fixed part is averaged into the
#                    population mean of the BLUPs (as for lme4: mean over trials)
#   label            name of the folder the BLUPF90 files are kept in
# Returns genotype values (value, se), variance components named as lme4
# names them, residuals and notes.
f90_fit <- function(d, fixed_terms = character(), random_terms = character(), genotype_random = TRUE,
                    w = NULL, fixed_mean_by = NULL, label = "model", ped = NULL) {
  n <- nrow(d)
  if (n < 3) stop("not enough observations")
  acc <- factor(d$accession)
  if (!is.null(ped) && !genotype_random) stop("a pedigree needs the genotype as random effect")
  notes <- character()

  labs <- if (length(fixed_terms)) attr(terms(as.formula(paste("~", paste(fixed_terms, collapse = " + ")))), "term.labels") else character()
  labs <- setdiff(labs, "accession")
  is_num <- function(v) is.numeric(d[[v]])

  # dense coding (exact BLUE standard errors) when the genotype is fixed and
  # the other fixed effects need few columns
  X <- matrix(numeric(0), n, 0)
  dense <- FALSE
  if (!genotype_random && length(labs)) {
    fml_x <- as.formula(paste("~", paste(labs, collapse = " + ")))
    mm <- model.matrix(fml_x, data = model.frame(fml_x, d, na.action = na.pass))
    mm <- mm[, colnames(mm) != "(Intercept)", drop = FALSE]
    if (ncol(mm) <= F90_DENSE_MAX) {
      dense <- TRUE
      Xc <- sweep(mm, 2, colMeans(mm))
      R <- mm - apply(mm, 2, function(v) ave(v, acc))     # part not explained by the genotype
      keep <- colSums(R^2) > 1e-8 * pmax(1, colSums(mm^2))
      idx <- if (any(keep)) { q <- qr(R[, keep, drop = FALSE], tol = 1e-7); which(keep)[sort(q$pivot[seq_len(q$rank)])] } else integer()
      X <- Xc[, idx, drop = FALSE]
    }
  }

  cols <- list(y = d$y)
  if (!is.null(w)) cols$w <- w
  eff <- character()
  fx <- list()          # native fixed effects: how to rebuild the fixed part
  add_col <- function(name, v) { cols[[name]] <<- v; length(cols) }

  if (!genotype_random) eff <- c(eff, paste(add_col("acc", as.integer(acc)), nlevels(acc), "cross"))
  if (dense) {
    for (j in seq_len(ncol(X))) eff <- c(eff, paste(add_col(paste0("x", j), X[, j]), 1, "cov"))
  } else {
    for (lab in labs) {
      vars <- strsplit(lab, ":", fixed = TRUE)[[1]]
      nums <- vars[vapply(vars, is_num, logical(1))]
      facs <- setdiff(vars, nums)
      if (length(nums) > 1) { notes <- c(notes, paste0(lab, " (product of covariates, not supported by BLUPF90+)")); next }
      if (length(nums) == 1) {
        x <- d[[nums]]; x <- x - mean(x, na.rm = TRUE); x[is.na(x)] <- 0
        if (length(facs)) {
          cd <- f90_codes(d, facs)
          fpos <- add_col(paste0("f_", lab), cd$code)
          xpos <- add_col(paste0("x_", lab), x)
          eff <- c(eff, paste(xpos, cd$n, "cov", fpos))
          fx[[length(fx) + 1]] <- list(effect = length(eff), code = cd$code, x = x)
        } else {
          eff <- c(eff, paste(add_col(paste0("x_", lab), x), 1, "cov"))
          fx[[length(fx) + 1]] <- list(effect = length(eff), code = rep(1L, n), x = x)
        }
      } else {
        cd <- f90_codes(d, facs)
        if (cd$n < 2) next
        eff <- c(eff, paste(add_col(paste0("f_", lab), cd$code), cd$n, "cross"))
        fx[[length(fx) + 1]] <- list(effect = length(eff), code = cd$code, x = rep(1, n), name = lab, labels = cd$labels)
      }
    }
  }
  # overall mean when nothing else absorbs it
  if (genotype_random && !any(vapply(fx, function(f) all(f$x == 1), logical(1)))) {
    eff <- c(eff, paste(add_col("mu", rep(1L, n)), 1, "cross"))
    fx[[length(fx) + 1]] <- list(effect = length(eff), code = rep(1L, n), x = rep(1, n))
  }

  first_random <- length(eff) + 1
  rcodes <- list()
  if (genotype_random) {
    rcodes$accession <- if (is.null(ped)) list(code = as.integer(acc), n = nlevels(acc), labels = levels(acc))
                        else list(code = match(as.character(acc), ped$id), n = nrow(ped), labels = ped$id)
  }
  for (rt in random_terms) {
    cd <- f90_codes(d, strsplit(rt, ":", fixed = TRUE)[[1]])
    if (cd$n >= 2) rcodes[[rt]] <- cd
  }
  for (rt in names(rcodes)) eff <- c(eff, paste(add_col(paste0("r_", rt), rcodes[[rt]]$code), rcodes[[rt]]$n, "cross"))
  n_random <- length(rcodes)
  if (n_random == 0) stop("the model has no random effect")

  f90_n_fits <<- f90_n_fits + 1
  wd <- file.path(f90_keep_dir, sprintf("%03d_%s", f90_n_fits, gsub("[^A-Za-z0-9_.-]+", "_", label)))
  dir.create(wd, recursive = TRUE, showWarnings = FALSE)
  data_mat <- as.data.frame(cols)
  write.table(format(data_mat, digits = 15, scientific = FALSE, trim = TRUE), file.path(wd, "data.txt"),
              quote = FALSE, row.names = FALSE, col.names = FALSE)
  writeLines(names(cols), file.path(wd, "data_columns.txt"))
  v0 <- max(var(d$y), 1e-6) / (n_random + 1)
  par <- c("# BLUPF90+ parameter file written by the Breedbase Script Factory",
           paste0("# model: y ~ ", if (genotype_random) "(1|accession)" else "accession",
                  if (length(labs)) paste0(" + ", paste(labs, collapse = " + ")),
                  if (length(random_terms)) paste0(" + ", paste0("(1|", names(rcodes)[names(rcodes) != "accession"], ")", collapse = " + ")),
                  if (dense) "   [fixed effects other than accession as centred covariates]"),
           "# columns of data.txt: see data_columns.txt",
           "DATAFILE", "data.txt", "NUMBER_OF_TRAITS", "1", "NUMBER_OF_EFFECTS", length(eff),
           "OBSERVATION(S)", "1", "WEIGHT(S)", if (is.null(w)) "" else "2",
           "EFFECTS: POSITIONS_IN_DATAFILE NUMBER_OF_LEVELS TYPE_OF_EFFECT[EFFECT NESTED]", eff,
           "RANDOM_RESIDUAL VALUES", format(v0, digits = 10))
  for (k in seq_len(n_random)) {
    animal <- !is.null(ped) && names(rcodes)[k] == "accession"
    par <- c(par, "RANDOM_GROUP", first_random + k - 1, "RANDOM_TYPE", if (animal) "add_animal" else "diagonal",
             "FILE", if (animal) "pedigree.txt" else "", "(CO)VARIANCES", format(v0, digits = 10))
  }
  par <- c(par, "OPTION method VCE", "OPTION use_yams", "OPTION sol se", "OPTION missing -999999999", "OPTION residual",
           "OPTION conv_crit 1e-9", "OPTION maxrounds 200")
  writeLines(par[!grepl("^#", par)], file.path(wd, "f90.par"))
  if (!is.null(ped)) {
    # animal, mother, father, 3 - number of known parents (BLUPF90 add_animal)
    write.table(data.frame(ped$code, ped$s, ped$d, 3L - (ped$s > 0) - (ped$d > 0)), file.path(wd, "pedigree.txt"),
                quote = FALSE, row.names = FALSE, col.names = FALSE)
  }
  writeLines(par[grepl("^#", par)], file.path(wd, "README.txt"))
  for (f in fx) if (!is.null(f$labels)) {
    write.table(data.frame(code = seq_along(f$labels), level = f$labels),
                file.path(wd, paste0("levels_", gsub(":", "_x_", f$name), ".txt")), sep = "\t", quote = FALSE, row.names = FALSE)
  }
  if (!genotype_random) write.table(data.frame(code = seq_len(nlevels(acc)), level = levels(acc)), file.path(wd, "levels_accession.txt"), sep = "\t", quote = FALSE, row.names = FALSE)
  for (k in names(rcodes)) {
    # level codes of each random effect, to read the solutions file by name
    write.table(data.frame(code = seq_len(rcodes[[k]]$n), level = rcodes[[k]]$labels),
                file.path(wd, paste0("levels_", gsub(":", "_x_", k), ".txt")), sep = "\t", quote = FALSE, row.names = FALSE)
  }

  # blupf90+ keeps large arrays on the stack (segfaults with the 8 MB default)
  cmd <- paste("ulimit -s unlimited 2>/dev/null || ulimit -s $(ulimit -H -s) 2>/dev/null;",
               "export OMP_STACKSIZE=64M; cd", shQuote(wd), "&& echo f90.par |", shQuote(f90_program()), "> blupf90.out 2>&1")
  t0 <- proc.time()[["elapsed"]]
  system(cmd)
  elapsed <- proc.time()[["elapsed"]] - t0
  out <- tryCatch(readLines(file.path(wd, "blupf90.out")), error = function(e) character())
  sol_file <- file.path(wd, "solutions")
  if (!file.exists(sol_file)) {
    stop("blupf90+ failed: ", paste(utils::tail(trimws(out[nzchar(trimws(out))]), 2), collapse = " | "))
  }
  sol <- read.table(sol_file, skip = 1, col.names = c("trait", "effect", "level", "solution", "se"))
  fe <- utils::tail(grep("Final Estimates", out), 1)
  if (!length(fe)) stop("blupf90+ did not converge: ", paste(utils::tail(trimws(out), 2), collapse = " | "))
  blk <- out[fe:length(out)]
  vc <- c()
  for (i in grep("variance\\(s\\) for effect", blk)) {
    e <- as.integer(sub(".*effect\\s+([0-9]+).*", "\\1", blk[i]))
    vc[names(rcodes)[e - first_random + 1]] <- as.numeric(trimws(blk[i + 1]))
  }
  vc["Residual"] <- as.numeric(trimws(blk[grep("Residual variance", blk)[1] + 1]))
  if (any(!is.finite(vc))) stop("blupf90+ returned invalid variance components")
  rounds <- length(grep("In round", out))
  if (rounds >= 200) notes <- c(notes, "AI-REML stopped at 200 rounds before full convergence")

  yr <- tryCatch(read.table(file.path(wd, "yhat_residual")), error = function(e) NULL)
  resid <- if (!is.null(yr) && nrow(yr) == n) yr[[ncol(yr)]] else rep(NA_real_, n)
  unlink(file.path(wd, c("fspak90.ord", "AI_inv.mat", "yhat_residual")))

  # fixed part of every observation (estimable whatever generalized inverse
  # blupf90+ used for redundant equations)
  fixed_part <- rep(0, n)
  for (f in fx) {
    s <- sol[sol$effect == f$effect, ]
    b <- s$solution[match(f$code, s$level)]
    b[is.na(b)] <- 0
    fixed_part <- fixed_part + b * f$x
  }
  # solutions of every random effect, by level name
  random <- list()
  for (k in seq_along(rcodes)) {
    u <- sol[sol$effect == first_random + k - 1, ]
    random[[names(rcodes)[k]]] <- data.frame(level = rcodes[[k]]$labels[u$level], solution = u$solution, se = u$se, stringsAsFactors = FALSE)
  }
  e1 <- sol[sol$effect == 1, ]
  mu <- if (!is.null(fixed_mean_by)) mean(tapply(fixed_part, fixed_mean_by, mean)) else mean(fixed_part)
  if (genotype_random) {
    u <- random$accession
    gv <- data.frame(accession = levels(acc), stringsAsFactors = FALSE)
    i <- match(gv$accession, u$level)
    gv$value <- mu + u$solution[i]; gv$se <- u$se[i]
  } else {
    # dense coding: the solution is the BLUE; native coding: genotype solution
    # plus the mean fixed part (estimable for connected data), no exact SE
    gv <- data.frame(accession = levels(acc)[e1$level], value = e1$solution + mean(fixed_part),
                     se = if (dense || !length(fx)) e1$se else NA_real_, stringsAsFactors = FALSE)
    if (!dense && length(fx)) notes <- c(notes, paste0("standard errors of the BLUEs are not reported: the fixed effects other than accession need more than ", F90_DENSE_MAX, " columns"))
  }
  log_step("  blupf90+ ", label, ": ", n, " records, ", rounds, " AI-REML rounds, ", sprintf("%.1f s", elapsed))
  list(values = gv, vc = vc, resid = resid, notes = notes, seconds = elapsed, rounds = rounds, dir = wd,
       random = random, mu = mu, engine = "BLUPF90+")
}

# -----------------------------------------------------------------------------
# Genetic model and model fitting shared by stage 2 and the single stage
# -----------------------------------------------------------------------------
gen_cfg <- opt(recipe, "genetic", list())
gen_model <- opt(gen_cfg, "model", "iid")      # iid | parents | pedigree
check_opt <- opt(gen_cfg, "check", "auto")     # auto | fixed | none
if (!gen_model %in% c("iid", "parents", "pedigree")) gen_model <- "iid"
if (gen_model == "pedigree" && !nzchar(f90_program())) {
  add_warning("The pedigree (A matrix) model is fitted with BLUPF90+, which is not installed on this server; accessions were treated as unrelated.")
  gen_model <- "iid"
}
if (gen_model != "iid") {
  n_known <- if (is.null(pedigree)) 0 else sum(unique(dat$accession) %in% pedigree$accession[!is.na(pedigree$mother) | !is.na(pedigree$father)])
  if (n_known == 0) {
    add_warning("No accession of this dataset has known parents, so the ", if (gen_model == "pedigree") "pedigree (A matrix)" else "mother / father", " model could not be used; accessions were treated as unrelated.")
    gen_model <- "iid"
  } else log_step("Genetic model: ", gen_model, " (", n_known, " accessions with known parents)")
}
acc_is_check <- tapply(dat$check == "check", dat$accession, any)

# Fit 'y ~ ...' (lme4 syntax) with the engine of the recipe and the genetic
# model. Returns genotype values, variance components (lme4 names),
# residuals, the solutions of every random effect, ancestors' breeding values
# (pedigree model) and notes.
fit_model <- function(d, fml_txt, genotype_random, w = NULL, label = "model") {
  rhs <- sub("^\\s*y\\s*~", "", fml_txt)
  sp <- split_lme4_terms(rhs)
  has_random <- grepl("\\|", rhs)
  ped_on <- genotype_random && gen_model == "pedigree" && "accession" %in% sp$random
  notes <- character()
  fit <- NULL
  # Pedigree (A matrix) models are fitted with BLUPF90+ whatever the engine of
  # the recipe; without BLUPF90+ the accessions are treated as unrelated (lme4).
  if (ped_on && !nzchar(f90_program())) {
    notes <- c(notes, "the pedigree model needs BLUPF90+, which is not installed; accessions were treated as unrelated")
  } else if ((use_f90 || ped_on) && has_random) {
    if (length(sp$unsupported)) {
      notes <- c(notes, paste0("BLUPF90+ cannot fit ", paste(sp$unsupported, collapse = ", "), "; lme4 was used",
                               if (ped_on) " and accessions were treated as unrelated"))
    } else {
      fit <- tryCatch(f90_fit(d, setdiff(sp$fixed, "accession"), setdiff(sp$random, "accession"), genotype_random,
                              w = w, fixed_mean_by = d$trial, label = label, ped = if (ped_on) ped_codes(levels(factor(d$accession)))),
                      error = function(e) { notes <<- c(notes, paste0("BLUPF90+ failed (", conditionMessage(e), "); lme4 was used",
                                                                      if (ped_on) " and accessions were treated as unrelated")); NULL })
    }
  }
  if (is.null(fit)) {
    # lme4 / lm; unknown parents become one '(unknown)' level
    for (v in intersect(c("mother", "father"), all.vars(as.formula(fml_txt)))) d[[v]] <- ifelse(is.na(d[[v]]), "(unknown)", d[[v]])
    fml <- as.formula(fml_txt)
    d$.w <- if (is.null(w)) rep(1, nrow(d)) else w
    m <- if (has_random) fit_quietly(lmer(fml, data = d, weights = .w, REML = TRUE)) else fit_quietly(lm(fml, data = d, weights = .w))
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
    if (genotype_random) {
      fp <- predict(m, re.form = NA)
      mu <- mean(tapply(fp, d$trial, mean))
      u <- random$accession
      gv <- data.frame(accession = u$level, value = mu + u$solution, se = u$se, stringsAsFactors = FALSE)
    } else {
      gv <- accession_blues(m, d)
      mu <- NA_real_
    }
    fit <- list(values = gv, vc = vc, resid = as.numeric(residuals(m)), notes = character(), random = random, mu = mu, engine = "R")
  }
  fit$notes <- c(notes, fit$notes)
  fit$ancestors <- NULL
  # whether the pedigree was really used (R/lme4 fallbacks treat accessions as unrelated)
  fit$pedigree <- isTRUE(ped_on) && !identical(fit$engine, "R")
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
    # breeding values of ancestors without phenotypes (pedigree model)
    if (ped_on && !is.null(fit$random$accession)) {
      a <- fit$random$accession
      a <- a[!a$level %in% gv$accession, ]
      if (nrow(a)) fit$ancestors <- data.frame(accession = a$level, value = fit$mu + a$solution, se = a$se, stringsAsFactors = FALSE)
    }
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
    if (n_levels(d$row) > 1) terms <- c(terms, "(1|rep_eff:row_f)")
    if (n_levels(d$col) > 1) terms <- c(terms, "(1|rep_eff:col_f)")
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
cov_name <- function(full) paste0("cov_", gsub("[^A-Za-z0-9]+", "_", short_trait(full)))

# factors used by the single-stage models (builder and custom formula)
add_model_factors <- function(d) {
  d$rowN <- d$row; d$colN <- d$col
  d$accession <- factor(d$accession); d$trial <- factor(d$trial)
  d$location <- factor(d$location); d$year <- factor(d$year)
  d$rep <- factor(d$rep_eff); d$block <- factor(d$block)
  d$tr_rep <- factor(paste(d$trial, d$rep_eff))
  d$tr_block <- factor(paste(d$trial, d$rep_eff, d$block))
  d$tr_row <- factor(ifelse(is.na(d$rowN), NA, paste(d$trial, d$rowN)))
  d$tr_col <- factor(ifelse(is.na(d$colN), NA, paste(d$trial, d$colN)))
  d$row <- factor(d$rowN); d$col <- factor(d$colN)
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

fit_stage1 <- function(d, info, trait) {
  d <- d[!is.na(d$y), ]
  res <- list(trial = info$trial, trait = short_trait(trait), design = info$design_label,
              n = nrow(d), n_accessions = n_levels(d$accession), mean = mean(d$y),
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
  df_res <- nrow(d) - n_levels(d$accession) - max(0, n_levels(d$rep_eff) - 1) - trt_df
  within <- tapply(d$y, d$accession, function(v) if (length(v) > 1) sum((v - mean(v))^2) else 0)
  if (df_res < 2 || sum(within) <= 1e-10 * max(1, sum((d$y - mean(d$y))^2))) {
    why <- if (df_res < 2) sprintf("only %d residual degree(s) of freedom", max(0, df_res)) else "the replicated plots have identical values"
    add_warning(info$trial, " / ", short_trait(trait), ": no error variance can be estimated (", why, "); accession means were used without standard errors.")
    return(raw_means(paste0("Accession means (no error estimate: ", why, ")"), paste0("No error variance: ", why, ".")))
  }


  use_spats <- (s1_model == "spats" || (s1_model == "auto" && info$has_rowcol)) && info$has_rowcol

  if (use_spats && requireNamespace("SpATS", quietly = TRUE)) {
    nr <- n_levels(d$row); nc <- n_levels(d$col)
    nseg <- c(max(1, ceiling(nc / 2)), max(1, ceiling(nr / 2)))
    has_rep <- n_levels(d$rep_eff) > 1
    d$rowN <- d$row; d$colN <- d$col
    rc_random <- c(if (nr > 1) "row_f", if (nc > 1) "col_f")
    # Candidate specifications: replicate as fixed effect first; when blocks
    # are aligned with rows/columns the fixed replicate effect is collinear
    # with the spatial surface, so fall back to replicate as random effect.
    fx <- function(v) if (length(v)) as.formula(paste("~", paste(v, collapse = " + "))) else NULL
    specs <- list(
      list(fixed = fx(c(if (has_rep) "rep_eff", trt_fx)), random = rc_random, label = paste0(if (has_rep) " + rep" else "", trt_lab), rlabel = ""),
      list(fixed = fx(trt_fx), random = c(if (has_rep) "rep_eff", rc_random), label = trt_lab, rlabel = if (has_rep) " + (1|rep)" else "")
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
                           if (length(rc_random)) " + (1|row) + (1|col)" else "")
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
  terms <- design_terms(design, d)

  # BLUPF90+: same model, genotype fixed (BLUEs, residual variance) and random
  # (genotypic variance, heritability). Designs without random terms are plain
  # least squares and stay in R.
  if (use_f90 && length(terms)) {
    rterms <- sub("^\\(1\\|(.*)\\)$", "\\1", terms)
    lab <- paste0("stage1_", info$trial, "_", short_trait(trait))
    fF <- tryCatch(f90_fit(d, trt_fx, rterms, FALSE, label = paste0(lab, "_blue")), error = function(e) e)
    if (!inherits(fF, "error")) {
      res$model <- paste0("BLUPF90+: ", model_text(design, c(trt_fx, terms), FALSE))
      res$var_e <- unname(fF$vc["Residual"])
      fR <- tryCatch(f90_fit(d, trt_fx, rterms, TRUE, label = paste0(lab, "_blup")), error = function(e) e)
      if (!inherits(fR, "error")) {
        res$var_g <- unname(fR$vc["accession"])
        r_bar <- 1 / mean(1 / as.numeric(table(d$accession)))
        res$h2 <- unname(res$var_g / (res$var_g + fR$vc["Residual"] / r_bar))
      }
      res$cv <- 100 * sqrt(res$var_e) / abs(res$mean)
      return(list(summary = res, means = fF$values, resid = data.frame(unit = d$unit, resid = fF$resid)))
    }
    add_warning("BLUPF90+ could not fit ", info$trial, " / ", short_trait(trait), " (", conditionMessage(fF), "); lme4 was used for this trial.")
  }

  fml_fixed <- as.formula(model_text(design, c(trt_fx, terms), FALSE))
  fit <- if (length(terms)) fit_quietly(lmer(fml_fixed, data = d, REML = TRUE)) else fit_quietly(lm(fml_fixed, data = d))
  if (inherits(fit, "error")) {
    # fall back to the simplest model
    terms <- character()
    fml_fixed <- y ~ accession
    fit <- fit_quietly(lm(y ~ accession, data = d))
    if (inherits(fit, "error")) { res$message <- conditionMessage(fit); return(list(summary = res, means = NULL)) }
    res$message <- "Design model failed; fitted y ~ accession."
  }
  if (!inherits(fit, "merMod") && df.residual(fit) < 1) {
    res$message <- "No residual degrees of freedom"
    return(list(summary = res, means = NULL))
  }
  means <- accession_blues(fit, d)
  res$model <- paste(deparse(fml_fixed, width.cutoff = 500), collapse = "")
  res$var_e <- if (inherits(fit, "merMod")) sigma(fit)^2 else summary(fit)$sigma^2

  fml_random <- as.formula(model_text(design, c(trt_fx, terms), TRUE))
  fr <- fit_quietly(lmer(fml_random, data = d, REML = TRUE))
  if (!inherits(fr, "error")) {
    vc <- var_comp(fr)
    res$var_g <- unname(vc["accession"])
    r_bar <- 1 / mean(1 / as.numeric(table(d$accession)))
    res$h2 <- res$var_g / (res$var_g + vc["Residual"] / r_bar)
    res$h2 <- unname(res$h2)
  }
  res$cv <- 100 * sqrt(res$var_e) / abs(res$mean)
  list(summary = res, means = means, resid = data.frame(unit = d$unit, resid = as.numeric(residuals(fit))))
}

# -----------------------------------------------------------------------------
# Step 3 - models
# -----------------------------------------------------------------------------
strategy <- opt(recipe, "strategy", "two_stage")
s2_cfg <- opt(recipe, "stage2", list())
ss_cfg <- opt(recipe, "single", list())
genotype_random <- identical(opt(if (strategy == "two_stage") s2_cfg else ss_cfg, "genotype", "random"), "random")
weighting <- opt(s2_cfg, "weighting", "inverse_se2")

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
      if (!is.null(r$summary)) stage1_summary[[length(stage1_summary) + 1]] <- as.data.frame(r$summary, stringsAsFactors = FALSE)
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

if (strategy == "two_stage") {
  # Stage 2 -------------------------------------------------------------------
  for (t in traits) {
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
      res$model <- paste0(c(BLUPF90 = "BLUPF90+: ", R = "")[[sub("\\+$", "", f2$engine)]],
                          sub("^y ~", "BLUE ~", fml_txt), if (isTRUE(f2$pedigree)) ", accession ~ N(0, A s2a)",
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
  ss_cov <- unlist(opt(ss_cfg, "covariates", list()))

  # covariates: any numeric column of the phenotype file (usually another trait)
  cov_vars <- character()
  for (cv in ss_cov) {
    full <- if (cv %in% names(pheno)) cv else available_traits[short_trait(available_traits) == short_trait(cv)][1]
    if (is.na(full) || is.null(full)) { add_warning("Covariate '", short_trait(cv), "' is not in this dataset and was skipped."); next }
    vn <- cov_name(full)
    dat[[vn]] <- suppressWarnings(as.numeric(pheno[[full]]))
    cov_vars <- c(cov_vars, vn)
  }

  if (ss_mode == "custom") {
    custom <- parse_custom_formula(opt(ss_cfg, "formula", ""), c(cov_vars, names(treatment_factors)))
    genotype_random <- custom$genotype_random
  }

  for (t in traits) {
    d <- dat[!is.na(dat[[t]]), ]
    d$y <- d[[t]]
    if (nrow(d) < 3) next
    log_step("Single stage: ", short_trait(t))
    d <- add_model_factors(d)
    n_tr <- n_levels(d$trial)
    dropped <- character()
    used_vars <- c("y", "accession")

    if (ss_mode == "custom") {
      if (cov_name(t) %in% custom$vars) { add_warning(short_trait(t), " is a covariate of the custom formula; it cannot be analysed with its own value as covariate and was skipped."); next }
      fml_txt <- custom$text
      one <- Filter(function(v) v %in% c("trial", "location", "year", "check", "rep", "block") && n_levels(d[[v]]) < 2, custom$vars)
      if (length(one)) {
        add_warning(short_trait(t), ": the custom formula uses ", paste0("'", one, "'", collapse = ", "), " but ", if (length(one) > 1) "these variables have" else "it has",
                    " a single level in the data", if ("check" %in% one) " (no entry is marked as check)" else "", "; remove ", if (length(one) > 1) "them" else "it", " from the formula.")
        next
      }
      used_vars <- unique(c(used_vars, setdiff(custom$vars, c("mother", "father"))))   # unknown parents are allowed
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
      # replicates within trials
      rep_on <- if (ss_rep == "auto") n_levels(d$tr_rep) > n_tr else ss_rep != "none"
      if (rep_on) add_term(if (ss_rep == "fixed") "tr_rep" else "(1|tr_rep)", n_levels(d$tr_rep) > n_tr, "replicate within trial (one replicate per trial)", "tr_rep")
      # incomplete blocks within replicates
      block_on <- if (ss_block == "auto") any(designs %in% c("alpha_lattice", "augmented")) && n_levels(d$tr_block) > n_levels(d$tr_rep) else ss_block != "none"
      if (block_on) add_term(if (ss_block == "fixed") "tr_block" else "(1|tr_block)", n_levels(d$tr_block) > n_levels(d$tr_rep), "block within replicate (blocks equal replicates)", "tr_block")
      # rows and columns within trials
      rc_on <- if (ss_rowcol == "auto") any(designs == "row_column") || all_rc else ss_rowcol != "none"
      if (rc_on) {
        add_term("(1|tr_row)", n_levels(d$tr_row) > n_tr && sum(!is.na(d$row)) > 0, "row within trial (no row numbers)", "tr_row")
        add_term("(1|tr_col)", n_levels(d$tr_col) > n_tr && sum(!is.na(d$col)) > 0, "column within trial (no column numbers)", "tr_col")
      }
      # linear field trend within trials
      if (ss_trend == "linear") {
        rc_ok <- sum(!is.na(d$rowN) & !is.na(d$colN)) >= 0.9 * nrow(d) && n_levels(d$rowN) > 1
        add_term(if (n_tr > 1) "trial:rowN + trial:colN" else "rowN + colN", rc_ok, "linear row/column trend (row and column numbers missing)", c("trial", "rowN", "colN"))
      }
      # genotype x environment interactions
      for (gx in ss_gxe) {
        n_lv <- n_levels(d[[gx]])
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
        ok <-sum(!is.na(d[[cv]])) > 0.5 * nrow(d) && n_levels(d[[cv]]) > 1
        add_term(cv, ok, paste0("covariate ", sub("^cov_", "", cv), " (missing or constant)"), cv)
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
    if (gen_model == "pedigree" && !genotype_random) dropped <- c(dropped, "pedigree relationship (needs the genotype as random effect)")

    # keep only the plots that have every variable of the model
    cc <- complete.cases(d[, intersect(used_vars, names(d)), drop = FALSE])
    if (sum(!cc) > 0) add_warning(short_trait(t), ": ", sum(!cc), " plot(s) without values for all model terms were left out of the single-stage model.")
    d <- droplevels(d[cc, ])
    n_tr <- n_levels(d$trial)
    if (length(dropped)) add_warning(short_trait(t), ": term(s) not supported by the data were left out of the model: ", paste(dropped, collapse = "; "), ".")

    res <- list(trait = short_trait(t), n_trials = n_tr, n_accessions = n_levels(d$accession), mean = mean(d$y),
                var_g = NA_real_, var_ge = NA_real_, var_e = NA_real_, h2 = NA_real_, model = "",
                dropped_terms = paste(dropped, collapse = "; "), message = "OK", engine_used = NA_character_, pedigree_used = FALSE)
    r_bar <- 1 / mean(1 / as.numeric(table(d$accession)))
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
    res$model <- paste0(c(BLUPF90 = "BLUPF90+: ", R = "")[[sub("\\+$", "", f1$engine)]], fml_txt,
                        if (isTRUE(f1$pedigree)) ", accession ~ N(0, A s2a)")
    res$var_e <- unname(vc["Residual"])
    gv <- f1$values
    rs <- f1$resid
    if (!is.null(f1$ancestors)) { f1$ancestors$trait <- t; ancestor_values[[length(ancestor_values) + 1]] <- f1$ancestors }

    for (k in names(vc)) {
      lab <- k
      for (v in names(treatment_factors)) lab <- sub(v, treatment_factors[[v]]$name, lab, fixed = TRUE)
      variance_components[[length(variance_components) + 1]] <- data.frame(trait = short_trait(t), component = lab, variance = unname(vc[k]), stringsAsFactors = FALSE)
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
      res$h2 <- unname(res$var_g / (res$var_g + gxe_part + res$var_e / r_bar))
    }
    add_residuals(d$unit, t, rs)
    gv$trait <- t
    genotype_values[[length(genotype_values) + 1]] <- gv
    stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res, stringsAsFactors = FALSE)
  }
}
stage2_summary <- if (length(stage2_summary)) do.call(rbind, stage2_summary) else NULL
genotype_values <- if (length(genotype_values)) do.call(rbind, genotype_values) else NULL
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
    gains <- do.call(rbind, lapply(traits_ok, function(t) {
      x <- w2[[t]]; xs <- x[w2$selected]
      s <- mean(xs, na.rm = TRUE) - mean(x, na.rm = TRUE)
      h2 <- h2_of(t)
      data.frame(trait = short_trait(t), in_index = t %in% names(idx_traits_cfg),
                 weight = if (t %in% names(idx_traits_cfg)) as.numeric(opt(idx_traits_cfg[[t]], "weight", 0)) else 0,
                 direction = if (t %in% names(idx_traits_cfg)) opt(idx_traits_cfg[[t]], "direction", "increase") else "",
                 mean_population = mean(x, na.rm = TRUE), mean_selected = mean(xs, na.rm = TRUE),
                 selection_differential = s, selection_differential_pct = 100 * s / abs(mean(x, na.rm = TRUE)),
                 h2 = h2,
                 expected_gain = if (!genotype_random && is.finite(h2)) h2 * s else s,
                 stringsAsFactors = FALSE)
    }))
    index_result <- list(method = method, selection_pct = sel_pct, n_selected = n_sel, n_ranked = nrow(w2),
                         table = w2, gains = gains,
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
    method_used <- z_method
    zr <- NULL
    if (z_method == "lin" && !is.na(tv$trait)) {
      d <- dat[!is.na(dat[[tv$trait]]), ]
      d$y <- d[[tv$trait]]
      zr <- lin_zones(d, z_alpha)
    } else {
      if (z_method == "lin") method_used <- "correlation"
      zr <- cor_zones(m, z_thr, max(5, as.numeric(opt(zones_cfg, "min_common", 5))))
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
      v <- v[is.finite(v)]
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
      keep <- is.finite(v)
      if (!any(keep)) return(NULL)
      v <- v[keep]; n_env <- n_env[keep]
      data.frame(zone = paste0("Zone ", k), accession = names(v), value = unname(v), n_env = unname(n_env),
                 rank = rank(if (higher_better) -v else v, ties.method = "min"), n_ranked = length(v), stringsAsFactors = FALSE, row.names = NULL)
    }))
    zone_results[[length(zone_results) + 1]] <- list(
      target = tname, method = method_used,
      n_zones = length(zr$groups),
      higher_is_better = higher_better,
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
# BLUPF90+ parameter and data files of every model, to inspect or re-run them
if (use_f90 && dir.exists(f90_keep_dir)) {
  tgz <- paste0(output_prefix, "_blupf90.tar.gz")
  ok <- tryCatch({
    old_wd <- setwd(dirname(f90_keep_dir)); on.exit(setwd(old_wd), add = TRUE)
    utils::tar(basename(tgz), files = basename(f90_keep_dir), compression = "gzip", tar = "internal")
    setwd(old_wd)
    TRUE
  }, error = function(e) { add_warning("The BLUPF90+ files could not be packed: ", conditionMessage(e)); FALSE })
  if (ok) { files$blupf90 <- basename(tgz); unlink(f90_keep_dir, recursive = TRUE) }
}

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
  spatial_layout = x$has_rowcol, n_plots = x$n_plots, n_accessions = x$n_accessions, stringsAsFactors = FALSE)))

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
