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

SF_VERSION <- "1.1"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

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

requested <- unlist(opt(recipe, "traits", list()))
if (length(requested) == 0) {
  traits <- available_traits
} else {
  # match on full name first, then on the short (display) name, so that a
  # recipe built on one dataset can be used on another one
  traits <- character()
  for (t in requested) {
    if (t %in% names(pheno)) {
      traits <- c(traits, t)
    } else {
      m <- available_traits[short_trait(available_traits) == short_trait(t)]
      if (length(m) > 0) traits <- c(traits, m[1]) else add_warning("Trait '", t, "' is not in this dataset and was skipped.")
    }
  }
}
traits <- unique(traits)
for (t in traits) dat[[t]] <- suppressWarnings(as.numeric(pheno[[t]]))
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
  } else if (grepl("augmented|madii|aug", txt)) {
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
  V <- as.matrix(vcov(fit))
  keep <- !is.na(beta)
  beta <- beta[keep]; X <- X[, keep, drop = FALSE]; V <- V[names(beta), names(beta), drop = FALSE]
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
  se <- sqrt(pmax(0, rowSums((L %*% V) * L)))
  data.frame(accession = acc_levels, value = est, se = se, stringsAsFactors = FALSE)
}

fit_quietly <- function(expr) {
  withCallingHandlers(
    tryCatch(expr, error = function(e) e),
    warning = function(w) invokeRestart("muffleWarning"),
    message = function(m) invokeRestart("muffleMessage"))
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
FORMULA_VARS <- c("accession", "trial", "location", "year", "rep", "block", "row", "col", "rowN", "colN")

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
    specs <- list(
      list(fixed = if (has_rep) ~ rep_eff else NULL, random = rc_random, label = if (has_rep) " + rep" else "", rlabel = ""),
      list(fixed = NULL, random = c(if (has_rep) "rep_eff", rc_random), label = "", rlabel = if (has_rep) " + (1|rep)" else "")
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
  if (design == "unreplicated") {
    means <- aggregate(y ~ accession, data = d, FUN = mean)
    names(means)[2] <- "value"
    means$accession <- as.character(means$accession)
    means$se <- NA_real_
    res$model <- "Unreplicated: raw values (no error estimate)"
    res$message <- "Trial is unreplicated; values are raw observations."
    return(list(summary = res, means = means))
  }

  terms <- design_terms(design, d)
  fml_fixed <- as.formula(model_text(design, terms, FALSE))
  fit <- if (length(terms)) fit_quietly(lmer(fml_fixed, data = d, REML = TRUE)) else fit_quietly(lm(y ~ accession, data = d))
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

  fml_random <- as.formula(model_text(design, terms, TRUE))
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
      r <- if (strategy == "two_stage") fit_stage1(d, trial_info[[tr]], t) else {
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
                model = "", message = "OK")
    if (n_tr == 1) {
      gv <- data.frame(accession = m$accession, value = m$value, se = m$se)
      res$model <- "Single trial: stage 1 means"
      s1 <- stage1_summary[stage1_summary$trait == short_trait(t), ]
      res$h2 <- s1$h2[1]; res$var_g <- s1$var_g[1]
    } else {
      m$accession <- factor(m$accession); m$trial <- factor(m$trial)
      w <- if (weighting == "inverse_se2" && all(is.finite(m$se)) && all(m$se > 0)) 1 / m$se^2 else rep(1, nrow(m))
      m$w <- w / mean(w)
      if (genotype_random) {
        fit <- fit_quietly(lmer(value ~ trial + (1|accession), data = m, weights = w, REML = TRUE))
        if (inherits(fit, "error")) { res$message <- conditionMessage(fit); stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res); next }
        vc <- var_comp(fit)
        re <- ranef(fit, condVar = TRUE)$accession
        pv <- attr(re, "postVar")
        mu <- mean(fixef(fit)[1] + c(0, fixef(fit)[-1]))
        gv <- data.frame(accession = rownames(re), value = mu + re[, 1],
                         se = if (!is.null(pv)) sqrt(pv[1, 1, ]) * 1 else NA_real_)
        res$var_g <- unname(vc["accession"]); res$var_ge <- unname(vc["Residual"])
        variance_components[[length(variance_components) + 1]] <- data.frame(trait = short_trait(t), component = c("accession", "accession:trial + error"), variance = c(res$var_g, res$var_ge), stringsAsFactors = FALSE)
        e_bar <- 1 / mean(1 / as.numeric(table(m$accession)))
        res$h2 <- unname(res$var_g / (res$var_g + res$var_ge / e_bar))
        res$model <- paste0("lmer(BLUE ~ trial + (1|accession)", if (weighting == "inverse_se2") ", weights = 1/SE^2" else "", ")")
      } else {
        fit <- fit_quietly(lm(value ~ accession + trial, data = m, weights = w))
        if (inherits(fit, "error")) { res$message <- conditionMessage(fit); stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res); next }
        gv <- accession_blues(fit, m)
        res$var_ge <- summary(fit)$sigma^2
        res$model <- paste0("lm(BLUE ~ accession + trial", if (weighting == "inverse_se2") ", weights = 1/SE^2" else "", ")")
      }
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
    custom <- parse_custom_formula(opt(ss_cfg, "formula", ""), cov_vars)
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
      used_vars <- unique(c(used_vars, custom$vars))
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
      # covariates
      for (cv in cov_vars) {
        if (cv == cov_name(t)) next   # a trait is never its own covariate
        ok <-sum(!is.na(d[[cv]])) > 0.5 * nrow(d) && n_levels(d[[cv]]) > 1
        add_term(cv, ok, paste0("covariate ", sub("^cov_", "", cv), " (missing or constant)"), cv)
      }
      g_term <- if (genotype_random) "(1|accession)" else "accession"
      fml_txt <- paste("y ~", paste(c(g_term, terms), collapse = " + "))
    }

    # keep only the plots that have every variable of the model
    cc <- complete.cases(d[, intersect(used_vars, names(d)), drop = FALSE])
    if (sum(!cc) > 0) add_warning(short_trait(t), ": ", sum(!cc), " plot(s) without values for all model terms were left out of the single-stage model.")
    d <- droplevels(d[cc, ])
    n_tr <- n_levels(d$trial)
    if (length(dropped)) add_warning(short_trait(t), ": term(s) not supported by the data were left out of the model: ", paste(dropped, collapse = "; "), ".")

    res <- list(trait = short_trait(t), n_trials = n_tr, n_accessions = n_levels(d$accession), mean = mean(d$y),
                var_g = NA_real_, var_ge = NA_real_, var_e = NA_real_, h2 = NA_real_, model = "",
                dropped_terms = paste(dropped, collapse = "; "), message = "OK")
    fml <- as.formula(fml_txt)
    has_random <- grepl("\\|", fml_txt)
    fit <- if (has_random) fit_quietly(lmer(fml, data = d, REML = TRUE)) else fit_quietly(lm(fml, data = d))
    if (inherits(fit, "error")) {
      res$message <- conditionMessage(fit)
      stage2_summary[[length(stage2_summary) + 1]] <- as.data.frame(res, stringsAsFactors = FALSE)
      next
    }
    res$model <- paste(deparse(fml, width.cutoff = 500), collapse = "")
    r_bar <- 1 / mean(1 / as.numeric(table(d$accession)))
    res$var_e <- if (inherits(fit, "merMod")) sigma(fit)^2 else summary(fit)$sigma^2

    vc <- if (inherits(fit, "merMod")) var_comp(fit) else c(Residual = res$var_e)
    for (k in names(vc)) variance_components[[length(variance_components) + 1]] <- data.frame(trait = short_trait(t), component = k, variance = unname(vc[k]), stringsAsFactors = FALSE)
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
      re <- ranef(fit, condVar = TRUE)$accession
      pv <- attr(re, "postVar")
      # population mean: fixed part of the model averaged within and then over trials
      fp <- predict(fit, re.form = NA)
      mu <- mean(tapply(fp, d$trial, mean))
      gv <- data.frame(accession = rownames(re), value = mu + re[, 1], se = if (!is.null(pv)) sqrt(pv[1, 1, ]) else NA_real_)
      res$var_g <- unname(vc["accession"])
      res$h2 <- unname(res$var_g / (res$var_g + gxe_part + res$var_e / r_bar))
    } else {
      gv <- accession_blues(fit, d)
    }
    rs <- residuals(fit)
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
    zone_results[[length(zone_results) + 1]] <- list(
      target = tname, method = method_used,
      n_zones = length(zr$groups),
      membership = membership,
      pairwise = zr$pairwise, correlation = zr$correlation,
      top = top)
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
  spatial_layout = x$has_rowcol, n_plots = x$n_plots, n_accessions = x$n_accessions, stringsAsFactors = FALSE)))

result <- list(
  version = SF_VERSION,
  strategy = strategy,
  genotype_effect = if (genotype_random) "random" else "fixed",
  value_label = if (genotype_random) "BLUP" else "BLUE",
  summary = list(n_plots = nrow(dat), n_accessions = n_levels(dat$accession), n_trials = length(trials),
                 n_environments = n_levels(dat$env), traits = short_trait(traits), traits_full = traits,
                 environment_unit = env_unit),
  trials = trial_table,
  outliers = outliers,
  outlier_summary = outlier_summary,
  stage1 = stage1_summary,
  stage2 = stage2_summary,
  genotype_values = wide_out,
  genotype_values_long = gv_out,
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
