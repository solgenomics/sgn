# =============================================================================
# Breedbase Analysis Pipeline - ANOVA by experimental design
# =============================================================================
#
# Optional last step of an Analysis Pipeline run (recipe "anova": {"enabled":
# true}), after either model engine (R or BLUPF90+). It reads the results of
# the run (plot values after outlier removal, the design of every trial, the
# treatments in the models) and adds, for every trait:
#
#   - the analysis of variance of a fixed-effects model that follows the
#     design of each trial: 'breedtools' (detect_design) chooses the design
#     terms of every trial (replicates, blocks within replicates, rows and
#     columns), nested within trials. Model:
#       y = trial + design terms (within trial) + treatments + trial x treatment
#           + accession + accession x treatment + accession x trial + e
#     Sequential (type I) sums of squares, in that order, every term tested
#     against the residual mean square (F-test);
#   - optionally (recipe anova.scope: joint | per_trial | both) the full
#     analysis of each trial on its own (same model without trial terms);
#   - a summary of each trial (mean, CV, F-test of the accessions) and
#     Hartley's Fmax test of the homogeneity of the residual
#     variances of the trials (breedtools::hartley_fmax_test);
#   - comparisons of the means of the significant fixed factors (treatments,
#     accessions; Tukey HSD or Fisher LSD, letter groups); when a factor
#     interacts significantly with another one, its means are compared within
#     each level of the other factor;
#   - model checks: Shapiro-Wilk test of the residuals, Brown-Forsythe
#     (Levene) test of equal variances across treatment levels, normal Q-Q and
#     residual vs fitted values, largest standardized residuals.
#
# Usage:
#   Rscript script_factory_anova.R <results_json> <output_json>
# The output is the input with an "anova" entry added (the input is copied
# unchanged when the step cannot run). Input and output may be the same file.
#
# Required R packages: jsonlite, breedtools; estimability and multcompView
# (comparisons; installed with emmeans).
#
# Author: Chris Simoes ccs263@cornell.edu
# =============================================================================

suppressPackageStartupMessages(library(jsonlite))

ANOVA_MAX_LEVELS <- 50      # largest number of means compared at once
ANOVA_MAX_CELLS <- 2e7      # largest plots x model columns of the combined model
ANOVA_PLOT_POINTS <- 400    # points of each diagnostic plot

sfa_log <- function(...) message("[script_factory] ", paste0(...))
sfa_short <- function(x) sub("\\|.*$", "", x)
sfa_levels <- function(x) length(unique(x[!is.na(x) & x != ""]))
sfa_num <- function(x, digits = 6) { x <- suppressWarnings(as.numeric(x)); ifelse(is.finite(x), signif(x, digits), NA_real_) }

# breedtools reads the design from the study design text and the factors;
# the text is the design of the trial as the pipeline chose it (detected or
# set by the user in the model step)
SFA_DESIGN_TEXT <- c("Row-column" = "row-column", "Augmented" = "augmented", "Alpha-lattice" = "alpha lattice",
                     "RCBD" = "rcbd", "CRD" = "crd", "Unreplicated" = "")

# design factors of the combined model (built from the breedtools terms of
# each trial by sfa_design_columns)
SFA_DESIGN_LABELS <- list(f_rep = "Replicate (within trial)", f_block = "Block (within replicate / trial)",
                          f_row = "Row (within trial)", f_col = "Column (within trial)")

# Design of one trial with breedtools. Returns the design label, the message
# of breedtools and the design terms (breedtools names).
sfa_trial_design <- function(d, design_label) {
  txt <- unname(SFA_DESIGN_TEXT[match(design_label, names(SFA_DESIGN_TEXT))])
  std <- data.frame(environment = d$trial, study_design = if (is.na(txt[1])) "" else txt[1],
                    accession_name = d$accession, rep_number = d$rep, block_number = d$block,
                    row_number = d$row, col_number = d$col, phenotype = d$y, stringsAsFactors = FALSE)
  dd <- breedtools::detect_design(std)
  labels <- attr(terms(dd$formula), "term.labels")
  list(design = dd$design, message = dd$message, terms = grep("^environment:", labels, value = TRUE))
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# design factor columns of a trial from its breedtools terms: a factor the
# design does not use is constant within the trial (absorbed by the trial)
sfa_design_columns <- function(d, design_terms) {
  has <- function(t) t %in% design_terms
  env <- d$trial
  data.frame(
    f_rep = if (has("environment:rep_number")) paste(env, d$rep) else env,
    f_block = if (has("environment:rep_number:block_number")) paste(env, d$rep, d$block)
              else if (has("environment:block_number")) paste(env, d$block) else env,
    f_row = if (has("environment:row_number")) paste(env, d$row) else env,
    f_col = if (has("environment:col_number")) paste(env, d$col) else env,
    stringsAsFactors = FALSE)
}

# does a factor vary within at least `min_env` trials?
sfa_varies <- function(x, trial, min_env = 1) sum(tapply(x, trial, function(v) sfa_levels(v) > 1)) >= min_env

# display label of a model term (R may write an interaction's factors in
# another order than the formula)
sfa_key <- function(t) paste(sort(strsplit(t, ":", fixed = TRUE)[[1]]), collapse = ":")
sfa_label <- function(labels, t) {
  names(labels) <- vapply(names(labels), sfa_key, "")
  labels[[sfa_key(t)]] %||% t
}

# ANOVA table of a fitted lm (type I), with display labels
sfa_table <- function(fit, labels) {
  a <- as.data.frame(anova(fit))
  terms <- rownames(a)
  data.frame(term = terms, label = vapply(terms, function(t) sfa_label(labels, t), ""),
             df = a$Df, sum_sq = sfa_num(a$`Sum Sq`), mean_sq = sfa_num(a$`Mean Sq`),
             f_value = sfa_num(a$`F value`), p_value = sfa_num(a$`Pr(>F)`, 4), stringsAsFactors = FALSE, row.names = NULL)
}

# --- means comparisons --------------------------------------------------------
# Mean of each level of `fac` (within the rows `rows`): the average prediction
# of the model over those plots with `fac` set to the level (marginal means
# with the weights of the data). Differences between levels involve only the
# terms of the factor, so they are estimable whenever the design compares the
# levels. Returns the L matrix (one row per level).
sfa_lmatrix <- function(fit, data, fac, lv, rows) {
  tt <- delete.response(terms(fit))
  t(vapply(lv, function(l) {
    newdata <- data[rows, , drop = FALSE]
    newdata[[fac]] <- factor(l, levels = levels(data[[fac]]))
    mf <- model.frame(tt, newdata, xlev = fit$xlevels)
    colMeans(model.matrix(tt, mf, contrasts.arg = fit$contrasts))
  }, numeric(length(coef(fit)))))
}

# letter groups listed from the highest mean down: renamed so that the
# highest mean is in group 'a', the next new group 'b'...
sfa_relabel <- function(g) {
  seen <- character()
  for (x in g) seen <- c(seen, setdiff(strsplit(x, "")[[1]], seen))
  map <- setNames(c(letters, LETTERS)[seq_along(seen)], seen)
  vapply(g, function(x) paste(sort(map[strsplit(x, "")[[1]]]), collapse = ""), "", USE.NAMES = FALSE)
}

# compare the levels lv of fac (rows: plots of the group); test tukey | lsd
sfa_compare <- function(fit, data, fac, lv, rows, test, alpha, nb) {
  b <- coef(fit)
  ok <- !is.na(b)
  L <- sfa_lmatrix(fit, data, fac, lv, rows)
  rownames(L) <- lv
  est <- if (is.null(nb)) rep(TRUE, length(lv)) else estimability::is.estble(L, nb)
  dropped <- lv[!est]
  lv <- lv[est]; L <- L[est, , drop = FALSE]
  if (length(lv) < 2) return(list(means = NULL, dropped = dropped))
  V <- vcov(fit, complete = FALSE)
  m <- drop(L[, ok, drop = FALSE] %*% b[ok])
  se <- sqrt(pmax(0, diag(L[, ok, drop = FALSE] %*% V %*% t(L[, ok, drop = FALSE]))))
  dfe <- fit$df.residual
  k <- length(lv)
  pr <- utils::combn(k, 2)
  D <- L[pr[1, ], ok, drop = FALSE] - L[pr[2, ], ok, drop = FALSE]
  sed <- sqrt(pmax(0, rowSums((D %*% V) * D)))
  tval <- abs(drop(D %*% b[ok])) / sed
  p <- if (test == "lsd") 2 * pt(tval, dfe, lower.tail = FALSE) else ptukey(tval * sqrt(2), nmeans = k, df = dfe, lower.tail = FALSE)
  p[!is.finite(p)] <- 1
  # letters: highest mean first ('a')
  o <- order(-m)
  rank_of <- match(seq_len(k), o)
  names(p) <- paste(rank_of[pr[1, ]], rank_of[pr[2, ]], sep = "-")
  # multcompView wants the smaller name first only for display; any order works
  grp <- if (requireNamespace("multcompView", quietly = TRUE)) {
    lt <- multcompView::multcompLetters(p, threshold = alpha)$Letters
    sfa_relabel(unname(lt[as.character(seq_len(k))]))[rank_of]
  } else rep(NA_character_, k)
  # least significant difference / honest significant difference (balanced case: mean SED)
  q <- if (test == "lsd") qt(1 - alpha / 2, dfe) else qtukey(1 - alpha, k, dfe) / sqrt(2)
  means <- data.frame(level = lv, mean = sfa_num(m), se = sfa_num(se), group = grp, stringsAsFactors = FALSE)[o, , drop = FALSE]
  list(means = means, dropped = dropped, msd = sfa_num(q * mean(sed)), n_pairs = length(p), n_signif = sum(p < alpha))
}

# --- diagnostics --------------------------------------------------------------
sfa_thin <- function(n, keep = integer(), max = ANOVA_PLOT_POINTS) {
  if (n <= max) return(seq_len(n))
  sort(unique(c(round(seq(1, n, length.out = max)), keep)))
}

sfa_diagnostics <- function(fit, data, trt_vars, trt_names) {
  r <- residuals(fit)
  rs <- suppressWarnings(rstandard(fit))
  okr <- is.finite(rs) & abs(r) > 1e-12 * max(1, abs(fitted(fit)))
  out <- list(n = length(r))
  rr <- r[okr]
  if (length(rr) >= 3) {
    x <- if (length(rr) > 5000) { set.seed(1); sample(rr, 5000) } else rr
    sw <- tryCatch(shapiro.test(x), error = function(e) NULL)
    if (!is.null(sw)) out$shapiro <- list(w = sfa_num(sw$statistic, 4), p_value = sfa_num(sw$p.value, 4), n = length(x))
  }
  # equal variances across treatment levels (Brown-Forsythe: absolute
  # deviations from the level median)
  out$levene <- unname(Filter(Negate(is.null), lapply(seq_along(trt_vars), function(i) {
    g <- factor(data[[trt_vars[i]]])
    if (nlevels(g) < 2) return(NULL)
    dev <- abs(r - ave(r, g, FUN = median))
    a <- tryCatch(anova(lm(dev ~ g)), error = function(e) NULL)
    if (is.null(a) || !is.finite(a$`F value`[1])) return(NULL)
    list(factor = trt_names[i], f_value = sfa_num(a$`F value`[1], 4), df1 = a$Df[1], df2 = a$Df[2], p_value = sfa_num(a$`Pr(>F)`[1], 4))
  })))
  # Q-Q and residual vs fitted (standardized residuals; plots with leverage 1
  # have no residual)
  s <- rs[okr]; f <- fitted(fit)[okr]
  if (length(s) >= 3) {
    o <- order(s)
    th <- qnorm(ppoints(length(s)))
    i <- sfa_thin(length(s))
    out$qq <- unname(Map(function(a, b) c(sfa_num(a, 4), sfa_num(b, 4)), th[i], s[o][i]))
    big <- which(abs(s) > 3)
    j <- if (length(s) <= ANOVA_PLOT_POINTS) seq_along(s) else { set.seed(1); sort(unique(c(sample(seq_along(s), ANOVA_PLOT_POINTS), big))) }
    out$fitted <- unname(Map(function(a, b) c(sfa_num(a, 5), sfa_num(b, 4)), f[j], s[j]))
    top <- head(order(-round(abs(s), 6), as.character(data$unit[okr])), 10)   # ties: by plot name
    top <- top[abs(s[top]) > 3]
    dd <- data[okr, , drop = FALSE]
    out$large_residuals <- if (length(top)) data.frame(unit = dd$unit[top], trial = dd$trial[top], accession = as.character(dd$accession[top]),
                                                      value = sfa_num(dd$y[top]), std_residual = sfa_num(s[top], 3), stringsAsFactors = FALSE) else NULL
    out$n_large <- length(big)
  }
  out
}

# --- one trait ----------------------------------------------------------------
# joint = FALSE: only the summary of each trial and the homogeneity test (the
# per-trial analyses are run separately)
sfa_trait <- function(trait, plots, trials, trt, test, alpha, joint = TRUE) {
  notes <- character()
  y <- suppressWarnings(as.numeric(plots[[trait]]))
  keep <- is.finite(y) & !is.na(plots$accession) & plots$accession != ""
  d <- plots[keep, , drop = FALSE]
  d$y <- y[keep]
  for (k in c("rep", "block", "row", "col")) { v <- as.character(d[[k]]); v[is.na(v) | v == ""] <- "."; d[[k]] <- v }
  if (nrow(d) < 4) return(list(trait = trait, message = "Not enough plot values for an analysis of variance."))
  tr_names <- unique(d$trial)
  multi <- length(tr_names) > 1

  # design of every trial (breedtools) and the per-trial analysis
  design_of <- setNames(trials$design, trials$trial)
  by_trial <- list(); designs <- list()
  dcols <- data.frame(f_rep = character(nrow(d)), f_block = "", f_row = "", f_col = "", stringsAsFactors = FALSE)
  for (tr in tr_names) {
    idx <- which(d$trial == tr)
    dt <- d[idx, , drop = FALSE]
    des <- sfa_trial_design(dt, design_of[[tr]] %||% "Unreplicated")
    designs[[tr]] <- des
    dc <- sfa_design_columns(dt, des$terms)
    dcols[idx, ] <- dc
    row <- data.frame(trial = tr, design = des$design, n = nrow(dt), mean = sfa_num(mean(dt$y)), cv = NA_real_, df_error = NA_real_,
                      ms_error = NA_real_, f_accession = NA_real_, p_accession = NA_real_, stringsAsFactors = FALSE)
    dt <- cbind(dt, dc)
    tt <- c(Filter(function(f) sfa_levels(dt[[f]]) > 1, c("f_rep", "f_block", "f_row", "f_col")), if (sfa_levels(dt$accession) > 1) "accession")
    if (length(tt)) {
      for (f in tt) dt[[f]] <- factor(dt[[f]])
      ft <- tryCatch(lm(terms(reformulate(tt, "y"), keep.order = TRUE), data = dt), error = function(e) NULL)
      if (!is.null(ft) && ft$df.residual > 0) {
        a <- suppressWarnings(anova(ft))
        mse <- a["Residuals", "Mean Sq"]
        row$df_error <- ft$df.residual
        row$ms_error <- sfa_num(mse)
        row$cv <- if (abs(mean(dt$y)) > 0) sfa_num(100 * sqrt(mse) / abs(mean(dt$y)), 4) else NA_real_
        if ("accession" %in% rownames(a)) { row$f_accession <- sfa_num(a["accession", "F value"], 4); row$p_accession <- sfa_num(a["accession", "Pr(>F)"], 4) }
      }
    }
    by_trial[[tr]] <- row
  }
  by_trial <- do.call(rbind, by_trial)
  rownames(by_trial) <- NULL

  # Hartley's Fmax test across trials (breedtools)
  homog <- NULL
  ht <- by_trial[is.finite(by_trial$ms_error) & by_trial$df_error > 0 & by_trial$ms_error > 0, , drop = FALSE]
  if (nrow(ht) >= 2) {
    h <- tryCatch(breedtools::hartley_fmax_test(data.frame(environment = ht$trial, ms_error = ht$ms_error, df_error = ht$df_error), alpha = alpha, n_sim = 20000),
                  error = function(e) NULL)
    if (!is.null(h)) {
      h <- as.list(as.data.frame(h)[1, , drop = FALSE])
      fmax <- h$fmax_observed
      crit <- h$fmax_critical
      homog <- list(test = "Hartley's Fmax (breedtools)", n_trials = nrow(ht), fmax = sfa_num(fmax, 4), critical = sfa_num(crit, 4),
                    homogeneous = if (is.finite(fmax) && is.finite(crit)) fmax <= crit else NA)
    }
  }

  if (!joint) return(list(trait = trait, n = nrow(d), n_trials = length(tr_names), by_trial = by_trial, homogeneity = homog))

  # combined model (joint analysis across trials)
  d <- cbind(d, dcols)
  for (k in c("trial", "accession", "f_rep", "f_block", "f_row", "f_col")) d[[k]] <- factor(d[[k]])
  labels <- c(list(trial = "Trial", accession = "Accession", `trial:accession` = "Accession x trial", Residuals = "Residual"), SFA_DESIGN_LABELS)
  terms <- c(if (multi) "trial", Filter(function(f) sfa_varies(as.character(d[[f]]), d$trial), c("f_rep", "f_block", "f_row", "f_col")))
  trt_vars <- character(); trt_names <- character()
  for (t in trt) {
    v <- t$column
    if (is.null(plots[[v]])) next
    d[[t$variable]] <- factor(as.character(plots[[v]][keep]))
    if (!sfa_varies(as.character(d[[t$variable]]), d$trial)) { notes <- c(notes, paste0(t$name, " has one level in each trial: its effect is part of the trial effect.")); next }
    trt_vars <- c(trt_vars, t$variable); trt_names <- c(trt_names, t$name)
    labels[[t$variable]] <- t$name
    terms <- c(terms, t$variable)
    if (multi && sfa_varies(as.character(d[[t$variable]]), d$trial, 2)) {
      terms <- c(terms, paste0("trial:", t$variable)); labels[[paste0("trial:", t$variable)]] <- paste0(t$name, " x trial")
    }
  }
  terms <- c(terms, "accession")
  for (i in seq_along(trt_vars)) if (isTRUE(trt[[match(trt_vars[i], vapply(trt, `[[`, "", "variable"))]]$gxt)) {
    terms <- c(terms, paste0("accession:", trt_vars[i])); labels[[paste0("accession:", trt_vars[i])]] <- paste0("Accession x ", trt_names[i])
  }
  if (multi) terms <- c(terms, "trial:accession")

  ncols <- 1 + sum(vapply(unique(unlist(strsplit(terms, ":"))), function(f) nlevels(d[[f]]) - 1, 0)) +
    if (multi) nlevels(d$trial) * nlevels(d$accession) else 0
  if (as.numeric(nrow(d)) * ncols > ANOVA_MAX_CELLS) {
    return(list(trait = trait, n = nrow(d), by_trial = by_trial, homogeneity = homog, notes = I(notes),
                message = paste0("The combined model (", nrow(d), " plots, about ", round(ncols), " effects) is too large for a fixed-effects analysis of variance; the analyses of each trial are given.")))
  }
  fit_of <- function(tt) lm(terms(reformulate(tt, "y"), keep.order = TRUE), data = d)
  fit <- tryCatch(fit_of(terms), error = function(e) e)
  if (inherits(fit, "error")) return(list(trait = trait, n = nrow(d), by_trial = by_trial, homogeneity = homog, notes = I(notes), message = paste("The model could not be fitted:", conditionMessage(fit))))
  if (fit$df.residual == 0 && multi) {
    # unreplicated within trials: accession x trial is the error
    terms <- setdiff(terms, "trial:accession")
    fit <- fit_of(terms)
    notes <- c(notes, "The accessions are not replicated within trials: accession x trial is the error term.")
  }
  if (fit$df.residual == 0) {
    return(list(trait = trait, n = nrow(d), by_trial = by_trial, homogeneity = homog, notes = I(notes),
                message = "No residual degrees of freedom (no replicated plots): F-tests are not possible."))
  }
  tab <- sfa_table(fit, labels)
  p_of <- function(term) { i <- match(term, tab$term); if (is.na(i)) NA_real_ else tab$p_value[i] }
  signif <- function(term) { p <- p_of(term); is.finite(p) && p < alpha }

  # comparisons of the significant factors
  nb <- if (requireNamespace("estimability", quietly = TRUE)) estimability::nonest.basis(fit$qr) else NULL
  comparisons <- list()
  candidates <- c(trt_vars, "accession")
  for (fac in candidates) {
    if (!signif(fac)) next
    name <- sfa_label(labels, fac)
    # interaction partner: the user's accession x treatment first, then trial
    partners <- if (fac == "accession") c(trt_vars, if (multi) "trial") else c("accession", if (multi) "trial")
    ix_term <- function(p) intersect(c(paste0(p, ":", fac), paste0(fac, ":", p)), tab$term)
    by <- NULL
    for (p in partners) { it <- ix_term(p); if (length(it) && signif(it[1])) { by <- p; break } }
    groups <- if (is.null(by)) list(list(level = NULL, rows = seq_len(nrow(d)))) else
      lapply(levels(droplevels(d[[by]])), function(l) list(level = l, rows = which(d[[by]] == l)))
    n_lv <- nlevels(droplevels(d[[fac]]))
    if (n_lv > ANOVA_MAX_LEVELS) {
      notes <- c(notes, paste0(name, ": ", n_lv, " levels, more than the ", ANOVA_MAX_LEVELS, " compared at once; see the adjusted means of the pipeline."))
      next
    }
    if (!is.null(by) && length(groups) > ANOVA_MAX_LEVELS) {
      notes <- c(notes, paste0(name, " interacts with ", tolower(sfa_label(labels, by)), " (", length(groups), " levels): too many groups to compare ", tolower(name), " within each."))
      next
    }
    res <- lapply(groups, function(g) {
      lv <- levels(droplevels(d[[fac]][g$rows]))
      if (length(lv) < 2) return(NULL)
      cmp <- tryCatch(sfa_compare(fit, d, fac, lv, g$rows, test, alpha, nb), error = function(e) { notes <<- c(notes, paste0(name, ": comparison failed (", conditionMessage(e), ").")); NULL })
      if (is.null(cmp) || is.null(cmp$means)) return(NULL)
      if (length(cmp$dropped)) notes <<- c(notes, paste0(name, if (!is.null(g$level)) paste0(" (", g$level, ")"), ": ", length(cmp$dropped), " level(s) not estimable, left out (", paste(head(cmp$dropped, 5), collapse = ", "), if (length(cmp$dropped) > 5) "...", ")."))
      list(group = g$level, msd = cmp$msd, n_pairs = cmp$n_pairs, n_signif = cmp$n_signif, means = cmp$means)
    })
    res <- Filter(Negate(is.null), res)
    if (length(res)) comparisons[[length(comparisons) + 1]] <- list(term = fac, factor = name, by = if (is.null(by)) NULL else sfa_label(labels, by),
                                                                   test = if (test == "lsd") "Fisher LSD" else "Tukey HSD", alpha = alpha, groups = res)
  }

  mse <- sum(residuals(fit)^2) / fit$df.residual
  list(trait = trait, n = nrow(d), n_trials = length(tr_names),
       designs = data.frame(trial = names(designs), design = vapply(designs, `[[`, "", "design"),
                            terms = vapply(designs, function(x) paste(x$terms, collapse = " + "), ""), stringsAsFactors = FALSE, row.names = NULL),
       model = paste("y ~", paste(vapply(terms, function(t) sfa_label(labels, t), ""), collapse = " + ")),
       table = tab, mean = sfa_num(mean(d$y)), cv = sfa_num(100 * sqrt(mse) / abs(mean(d$y)), 4), r2 = sfa_num(summary(fit)$r.squared, 4),
       by_trial = by_trial, homogeneity = homog, comparisons = comparisons,
       diagnostics = sfa_diagnostics(fit, d, trt_vars, trt_names), notes = I(unique(notes)))
}

# --- run ----------------------------------------------------------------------
# Adds "anova" to the results JSON (text splice: the rest of the file is kept
# byte for byte).
sfa_write <- function(text, anova, out_file) {
  text <- sub("\\}\\s*$", "", text)
  add <- toJSON(anova, dataframe = "rows", na = "null", auto_unbox = TRUE, digits = NA, null = "null")
  tmp <- paste0(out_file, ".tmp")
  writeLines(paste0(text, ",\"anova\":", add, "}"), tmp, useBytes = TRUE)
  file.rename(tmp, out_file)
}

sf_anova_run <- function(in_file, out_file) {
  text <- paste(readLines(in_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  res <- fromJSON(text, simplifyVector = TRUE)
  cfg <- res$recipe$anova %||% list()
  test <- if (identical(cfg$test, "lsd")) "lsd" else "tukey"
  alpha <- suppressWarnings(as.numeric(cfg$alpha %||% 0.05))
  if (!is.finite(alpha) || alpha <= 0 || alpha >= 0.5) alpha <- 0.05
  # joint: one analysis across trials; per_trial: a full analysis of each
  # trial; both
  scope <- if (cfg$scope %||% "" %in% c("per_trial", "both")) cfg$scope else "joint"
  anova <- list(test = if (test == "lsd") "Fisher LSD" else "Tukey HSD", alpha = alpha, scope = scope)
  if (!requireNamespace("breedtools", quietly = TRUE)) {
    anova$message <- "The R package breedtools is not installed on this server: the analysis of variance by design was not run."
    sfa_log(anova$message)
  } else if (is.null(res$plots) || !NROW(res$plots)) {
    anova$message <- "No plot data in the results."
  } else {
    plots <- as.data.frame(res$plots, stringsAsFactors = FALSE)
    trials <- as.data.frame(res$trials, stringsAsFactors = FALSE)
    # treatments of the models (their value per plot: column treatment:<variable>)
    trt <- lapply(seq_len(NROW(res$treatments)), function(i) {
      t <- if (is.data.frame(res$treatments)) as.list(res$treatments[i, ]) else res$treatments[[i]]
      list(name = as.character(t$name), variable = paste0("t_", gsub("[^A-Za-z0-9]+", "_", t$variable)), column = paste0("treatment:", t$variable),
           use = isTRUE(t$used) || isTRUE(t$gxt), gxt = isTRUE(t$gxt))
    })
    trt <- Filter(function(t) t$use && t$column %in% names(plots), trt)
    anova$software <- paste0("breedtools ", as.character(utils::packageVersion("breedtools")), " (design of each trial, Hartley's Fmax test); R ", getRversion(), " (lm, anova)")
    anova$traits <- lapply(res$summary$traits, function(t) {
      sfa_log("ANOVA by design: ", t, if (scope == "joint") " (joint analysis)" else if (scope == "per_trial") " (each trial)" else " (joint analysis and each trial)")
      tryCatch({
        r <- sfa_trait(t, plots, trials, trt, test, alpha, joint = scope != "per_trial")
        has <- is.finite(suppressWarnings(as.numeric(plots[[t]])))
        tr_names <- unique(plots$trial[has])
        # full analysis of each trial (same model without the trial terms)
        if (scope != "joint" && (length(tr_names) > 1 || scope == "per_trial")) {
          r$trials <- lapply(tr_names, function(tr) {
            x <- tryCatch(sfa_trait(t, plots[plots$trial == tr, , drop = FALSE], trials, trt, test, alpha),
                          error = function(e) list(message = paste("The analysis of variance failed:", conditionMessage(e))))
            x$by_trial <- NULL; x$homogeneity <- NULL; x$trait <- NULL
            c(list(trial = tr), x)
          })
        }
        r
      }, error = function(e) list(trait = t, message = paste("The analysis of variance failed:", conditionMessage(e))))
    })
  }
  sfa_write(text, anova, out_file)
  invisible(anova)
}

if (!exists("SF_ANOVA_EMBEDDED")) {
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) < 1) stop("Usage: Rscript script_factory_anova.R <results_json> [output_json]")
  out <- if (length(a) >= 2) a[2] else a[1]
  ok <- tryCatch({ sf_anova_run(a[1], out); TRUE }, error = function(e) { message("ANOVA step failed: ", conditionMessage(e)); FALSE })
  # the run keeps its results when this step fails
  if (!ok && a[1] != out) file.copy(a[1], out, overwrite = TRUE)
}
