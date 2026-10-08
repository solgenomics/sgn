rm(list = ls())

required_packages <- c("dplyr", "tidyr", "jsonlite")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required R package(s): ", paste(missing_packages, collapse = ", "))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 10) {
  stop("Usage: Rscript environment_stratification.R <phenotype_file> <trait> <alpha> <pairwise_json> <group_summary_json> <group_membership_json> <ungrouped_json> <summary_json> <anova_json> <message_file>")
}

phenotype_file <- args[1]
study_trait <- args[2]
alpha <- as.numeric(args[3])
pairwise_file <- args[4]
group_summary_file <- args[5]
group_membership_file <- args[6]
ungrouped_file <- args[7]
summary_file <- args[8]
anova_file <- args[9]
message_file <- args[10]

write_json_rows <- function(x, file) {
  json <- jsonlite::toJSON(x, dataframe = "rows", na = "null", auto_unbox = TRUE)
  writeLines(json, file)
}

write_message <- function(message) {
  writeLines(message, message_file)
}

empty_pairwise <- function() {
  data.frame(
    env1 = character(),
    env2 = character(),
    environments = character(),
    n_env = integer(),
    n_genotypes = integer(),
    r_eff = numeric(),
    ss_ge = numeric(),
    df_ge = numeric(),
    ms_ge = numeric(),
    message = character(),
    mse_error = numeric(),
    df_error = numeric(),
    f_value = numeric(),
    p_value = numeric(),
    compatible = logical()
  )
}

empty_group_summary <- function() {
  data.frame(
    group_id = character(),
    environments = character(),
    n_env = integer(),
    n_genotypes = integer(),
    r_eff = numeric(),
    ss_ge = numeric(),
    df_ge = numeric(),
    ms_ge = numeric(),
    message = character(),
    mse_error = numeric(),
    df_error = numeric(),
    f_value = numeric(),
    p_value = numeric(),
    compatible = logical()
  )
}

empty_group_membership <- function() {
  data.frame(group_id = character(), environment = character())
}

empty_ungrouped <- function() {
  data.frame(environment = character(), location = character(), trial = character(), year = character())
}

empty_anova <- function() {
  data.frame(
    design = character(),
    term = character(),
    df = numeric(),
    sum_sq = numeric(),
    mean_sq = numeric(),
    f_value = numeric(),
    p_value = numeric(),
    message = character()
  )
}

normalize_column_name <- function(x) {
  x <- gsub("\\.CO.*", "", x)
  x <- gsub("\\|CO_.*", "", x)
  x <- gsub("\\.", " ", x)
  x
}

find_column <- function(data, candidates, label) {
  matches <- candidates[candidates %in% colnames(data)]
  if (length(matches) == 0) {
    stop("Could not find required column for ", label, ". Tried: ", paste(candidates, collapse = ", "))
  }
  matches[1]
}

harmonic_mean <- function(x) {
  x <- x[!is.na(x) & x > 0]
  if (length(x) == 0) return(NA_real_)
  length(x) / sum(1 / x)
}

clean_display_values <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- x[x != ""]
  unique(x)
}

environment_display_label <- function(environment, location, trial, year) {
  parts <- clean_display_values(c(location, trial, year))
  if (length(parts) == 0) {
    return(as.character(environment))
  }
  paste(parts, collapse = " / ")
}

complete_environment_info <- function(env_info) {
  if (nrow(env_info) == 0) {
    env_info$environment_label <- character()
    return(env_info)
  }

  env_info$location <- as.character(env_info$location)
  env_info$trial <- as.character(env_info$trial)
  env_info$year <- as.character(env_info$year)
  env_info$location[is.na(env_info$location)] <- ""
  env_info$trial[is.na(env_info$trial)] <- ""
  env_info$year[is.na(env_info$year)] <- ""
  env_info$environment_label <- mapply(
    environment_display_label,
    env_info$environment,
    env_info$location,
    env_info$trial,
    env_info$year,
    USE.NAMES = FALSE
  )
  env_info
}

add_environment_metadata <- function(results, env_info, env_col = "environment") {
  if (nrow(results) == 0 || !(env_col %in% colnames(results))) {
    return(results)
  }
  dplyr::left_join(results, env_info, by = stats::setNames("environment", env_col))
}

add_pairwise_environment_metadata <- function(pairwise, env_info) {
  if (nrow(pairwise) == 0) {
    return(pairwise)
  }

  env1_info <- env_info %>%
    dplyr::rename(
      env1 = environment,
      env1_name = environment_label,
      env1_location = location,
      env1_trial = trial,
      env1_year = year
    )
  env2_info <- env_info %>%
    dplyr::rename(
      env2 = environment,
      env2_name = environment_label,
      env2_location = location,
      env2_trial = trial,
      env2_year = year
    )

  pairwise %>%
    dplyr::left_join(env1_info, by = "env1") %>%
    dplyr::left_join(env2_info, by = "env2") %>%
    dplyr::select(
      env1_location,
      env1_trial,
      env1_year,
      env1_name,
      env2_location,
      env2_trial,
      env2_year,
      env2_name,
      dplyr::everything(),
      -env1,
      -env2,
      -environments
    )
}

environment_summary_by_group <- function(group_summary, group_membership) {
  if (nrow(group_summary) == 0 || nrow(group_membership) == 0) {
    return(group_summary %>% dplyr::select(-dplyr::any_of("environments")))
  }

  display_summary <- group_membership %>%
    dplyr::group_by(group_id) %>%
    dplyr::summarise(
      environments = paste(clean_display_values(environment_label), collapse = ", "),
      locations = paste(clean_display_values(location), collapse = ", "),
      trials = paste(clean_display_values(trial), collapse = ", "),
      years = paste(clean_display_values(year), collapse = ", "),
      .groups = "drop"
    )

  group_summary %>%
    dplyr::select(-dplyr::any_of("environments")) %>%
    dplyr::left_join(display_summary, by = "group_id") %>%
    dplyr::select(group_id, environments, locations, trials, years, dplyr::everything())
}

has_factor_levels <- function(data, column) {
  column %in% names(data) && dplyr::n_distinct(data[[column]][!is.na(data[[column]])]) > 1
}

has_numeric_levels <- function(data, column) {
  column %in% names(data) && dplyr::n_distinct(data[[column]][!is.na(data[[column]])]) > 1
}

detect_design <- function(data) {
  design_text <- ""
  if ("study_design" %in% names(data)) {
    design_text <- paste(unique(tolower(as.character(data$study_design))), collapse = " ")
  }

  has_environment <- has_factor_levels(data, "environment")
  has_accession <- has_factor_levels(data, "accession_name")
  has_rep <- has_factor_levels(data, "rep_number")
  has_block <- has_factor_levels(data, "block_number")
  has_row <- has_numeric_levels(data, "row_number")
  has_col <- has_numeric_levels(data, "col_number")
  block_differs_from_rep <- has_rep && has_block && any(as.character(data$block_number) != as.character(data$rep_number), na.rm = TRUE)
  is_row_column_design <- grepl("row[- ]?column|row.*column|column.*row|spatial", design_text)

  if (is_row_column_design) {
    design_label <- "Row-column"
    design_message <- "Detected row and column layout; row and column are fitted within environment when those terms have at least two levels."
    design_terms <- c(
      if (has_rep) "environment:rep_number",
      if (has_row) "environment:row_number",
      if (has_col) "environment:col_number"
    )
  } else if (grepl("rcbd|randomized complete block|randomised complete block", design_text)) {
    design_label <- "RCBD"
    design_message <- "Detected randomized complete block layout; blocks are fitted within environment when block has at least two levels."
    design_terms <- c(
      if (has_block) "environment:block_number" else if (has_rep) "environment:rep_number"
    )
  } else if (grepl("alpha|lattice|incomplete", design_text) || block_differs_from_rep) {
    design_label <- "Incomplete block / alpha-lattice"
    design_message <- "Detected replicate and block layout; blocks are fitted within replicate and environment when those terms have at least two levels."
    design_terms <- c(
      if (has_rep) "environment:rep_number",
      if (has_rep && has_block) "environment:rep_number:block_number"
    )
  } else if (grepl("augmented", design_text) || (has_block && !has_rep)) {
    design_label <- "Augmented / block-only"
    design_message <- "Detected block-only layout; blocks are fitted within environment when block has at least two levels."
    design_terms <- c(if (has_block) "environment:block_number")
  } else if (has_rep) {
    design_label <- "RCBD"
    design_message <- "Detected randomized complete block layout; blocks are fitted within environment when available."
    design_terms <- c(
      if (has_block) "environment:block_number" else "environment:rep_number"
    )
  } else {
    design_label <- "CRD"
    design_message <- "No usable blocking, replicate, row, or column layout detected; using CRD model."
    design_terms <- character()
  }

  model_terms <- c(
    if (has_environment) "environment",
    design_terms,
    if (has_accession) "accession_name",
    if (has_environment && has_accession) "environment:accession_name"
  )
  model_terms <- unique(model_terms)
  formula_text <- if (length(model_terms) > 0) {
    paste("phenotype ~", paste(model_terms, collapse = " + "))
  } else {
    "phenotype ~ 1"
  }

  list(
    design = design_label,
    formula = stats::as.formula(formula_text),
    message = design_message
  )
}

prepare_design_factors <- function(data) {
  d <- data %>%
    dplyr::mutate(
      environment = factor(environment),
      accession_name = factor(accession_name),
      rep_number = factor(rep_number),
      block_number = factor(block_number),
      row_number = factor(row_number),
      col_number = factor(col_number)
    )
  d
}

calculate_anova <- function(data) {
  d <- prepare_design_factors(data)
  design_info <- detect_design(d)

  fit <- tryCatch(lm(design_info$formula, data = d, na.action = stats::na.omit), error = function(e) e)
  if (inherits(fit, "error")) {
    return(data.frame(design = design_info$design, term = "ERROR", df = NA_real_, sum_sq = NA_real_, mean_sq = NA_real_, f_value = NA_real_, p_value = NA_real_, message = fit$message))
  }

  tab <- as.data.frame(anova(fit))
  tab$term <- rownames(tab)
  rownames(tab) <- NULL

  tab %>%
    dplyr::transmute(
      design = design_info$design,
      term = term,
      df = Df,
      sum_sq = `Sum Sq`,
      mean_sq = `Mean Sq`,
      f_value = `F value`,
      p_value = `Pr(>F)`,
      message = design_info$message
    )
}

lin_ss_ge <- function(data, envs) {
  d <- data %>% dplyr::filter(environment %in% envs)

  common_genotypes <- d %>%
    dplyr::distinct(accession_name, environment) %>%
    dplyr::count(accession_name, name = "n_env") %>%
    dplyr::filter(n_env == length(envs)) %>%
    dplyr::pull(accession_name)

  d <- d %>% dplyr::filter(accession_name %in% common_genotypes)

  n_gen <- length(common_genotypes)
  n_env <- length(envs)

  if (n_gen < 2 || n_env < 2) {
    return(list(
      summary = data.frame(
        environments = paste(envs, collapse = ", "),
        n_env = n_env,
        n_genotypes = n_gen,
        r_eff = NA_real_,
        ss_ge = NA_real_,
        df_ge = NA_real_,
        ms_ge = NA_real_,
        message = "Not enough genotypes or environments"
      ),
      common_genotypes = common_genotypes
    ))
  }

  cell_means <- d %>%
    dplyr::group_by(accession_name, environment) %>%
    dplyr::summarise(
      mean_y = mean(phenotype, na.rm = TRUE),
      n_rep = dplyr::n(),
      .groups = "drop"
    )

  wide <- cell_means %>%
    dplyr::select(accession_name, environment, mean_y) %>%
    tidyr::pivot_wider(names_from = environment, values_from = mean_y) %>%
    dplyr::arrange(accession_name)

  Y <- wide %>%
    dplyr::select(dplyr::all_of(envs)) %>%
    as.matrix()
  storage.mode(Y) <- "numeric"

  r_eff <- harmonic_mean(cell_means$n_rep)
  row_mean <- rowMeans(Y, na.rm = TRUE)
  col_mean <- colMeans(Y, na.rm = TRUE)
  grand_mean <- mean(Y, na.rm = TRUE)

  interaction_matrix <- sweep(Y, 1, row_mean, "-")
  interaction_matrix <- sweep(interaction_matrix, 2, col_mean, "-")
  interaction_matrix <- interaction_matrix + grand_mean

  ss_ge <- r_eff * sum(interaction_matrix^2, na.rm = TRUE)
  df_ge <- (n_gen - 1) * (n_env - 1)
  ms_ge <- ss_ge / df_ge

  list(
    summary = data.frame(
      environments = paste(envs, collapse = ", "),
      n_env = n_env,
      n_genotypes = n_gen,
      r_eff = r_eff,
      ss_ge = ss_ge,
      df_ge = df_ge,
      ms_ge = ms_ge,
      message = "OK"
    ),
    common_genotypes = common_genotypes
  )
}

lin_error_mse <- function(data, envs, common_genotypes) {
  d <- data %>%
    dplyr::filter(
      environment %in% envs,
      accession_name %in% common_genotypes
    ) %>%
    prepare_design_factors()

  design <- detect_design(d)
  fit <- tryCatch(lm(design$formula, data = d, na.action = stats::na.omit), error = function(e) e)

  if (inherits(fit, "error")) {
    return(list(mse = NA_real_, df_error = NA_real_, message = fit$message))
  }

  df_error <- df.residual(fit)
  if (df_error <= 0) {
    return(list(mse = NA_real_, df_error = df_error, message = "No residual degrees of freedom"))
  }

  list(mse = sum(residuals(fit)^2, na.rm = TRUE) / df_error, df_error = df_error, message = design$message)
}

lin_test_group <- function(data, envs, alpha = 0.05) {
  ss_obj <- lin_ss_ge(data, envs)
  ss_tab <- ss_obj$summary
  common_genotypes <- ss_obj$common_genotypes

  if (is.na(ss_tab$ss_ge)) {
    ss_tab$f_value <- NA_real_
    ss_tab$p_value <- NA_real_
    ss_tab$compatible <- NA
    return(ss_tab)
  }

  mse_obj <- lin_error_mse(data = data, envs = envs, common_genotypes = common_genotypes)

  if (is.na(mse_obj$mse)) {
    ss_tab$mse_error <- NA_real_
    ss_tab$df_error <- mse_obj$df_error
    ss_tab$f_value <- NA_real_
    ss_tab$p_value <- NA_real_
    ss_tab$compatible <- NA
    ss_tab$message <- mse_obj$message
    return(ss_tab)
  }

  f_value <- ss_tab$ms_ge / mse_obj$mse
  p_value <- pf(q = f_value, df1 = ss_tab$df_ge, df2 = mse_obj$df_error, lower.tail = FALSE)

  ss_tab$mse_error <- mse_obj$mse
  ss_tab$df_error <- mse_obj$df_error
  ss_tab$f_value <- f_value
  ss_tab$p_value <- p_value
  ss_tab$compatible <- p_value >= alpha
  ss_tab
}

lin_group_environments <- function(data, alpha = 0.05) {
  all_envs <- sort(unique(as.character(data$environment)))

  if (length(all_envs) < 2) {
    return(list(
      pairwise = empty_pairwise(),
      group_summary = empty_group_summary(),
      group_membership = empty_group_membership(),
      ungrouped = data.frame(environment = all_envs)
    ))
  }

  env_pairs <- combn(all_envs, 2, simplify = FALSE)

  pairwise <- dplyr::bind_rows(lapply(env_pairs, function(x) {
    x <- as.character(x)
    res <- lin_test_group(data = data, envs = x, alpha = alpha)
    res$env1 <- x[1]
    res$env2 <- x[2]
    res
  })) %>%
    dplyr::select(env1, env2, dplyr::everything()) %>%
    dplyr::arrange(ss_ge)

  remaining_envs <- all_envs
  groups <- list()
  group_tests <- list()
  group_id <- 1

  while (length(remaining_envs) >= 2) {
    candidate_pairs <- pairwise %>%
      dplyr::filter(env1 %in% remaining_envs, env2 %in% remaining_envs, compatible == TRUE) %>%
      dplyr::arrange(ss_ge)

    if (nrow(candidate_pairs) == 0) {
      break
    }

    current_group <- c(candidate_pairs$env1[1], candidate_pairs$env2[1])

    repeat {
      candidates_to_add <- setdiff(remaining_envs, current_group)
      if (length(candidates_to_add) == 0) {
        break
      }

      add_tests <- dplyr::bind_rows(lapply(candidates_to_add, function(candidate_env) {
        res <- lin_test_group(data = data, envs = c(current_group, candidate_env), alpha = alpha)
        res$candidate_env <- candidate_env
        res
      })) %>%
        dplyr::filter(compatible == TRUE) %>%
        dplyr::arrange(ss_ge)

      if (nrow(add_tests) == 0) {
        break
      }

      current_group <- c(current_group, add_tests$candidate_env[1])
    }

    final_test <- lin_test_group(data = data, envs = current_group, alpha = alpha)
    final_test$group_id <- paste0("Group_", group_id)

    groups[[group_id]] <- current_group
    group_tests[[group_id]] <- final_test
    remaining_envs <- setdiff(remaining_envs, current_group)
    group_id <- group_id + 1
  }

  if (length(group_tests) > 0) {
    group_summary <- dplyr::bind_rows(group_tests) %>% dplyr::select(group_id, dplyr::everything())
    group_membership <- dplyr::bind_rows(lapply(seq_along(groups), function(i) {
      data.frame(group_id = paste0("Group_", i), environment = groups[[i]])
    }))
  } else {
    group_summary <- empty_group_summary()
    group_membership <- empty_group_membership()
  }

  list(
    pairwise = pairwise,
    group_summary = group_summary,
    group_membership = group_membership,
    ungrouped = data.frame(environment = remaining_envs)
  )
}

main <- function() {
  if (is.na(alpha) || alpha <= 0 || alpha >= 1) {
    stop("Alpha must be a number between 0 and 1.")
  }

  pheno <- read.table(phenotype_file, sep = "\t", header = TRUE, check.names = FALSE, quote = "", comment.char = "", stringsAsFactors = FALSE)
  colnames(pheno) <- normalize_column_name(colnames(pheno))
  study_trait <- normalize_column_name(gsub("\\.", " ", study_trait))

  trait_col <- find_column(pheno, c(study_trait), "selected trait")
  accession_col <- find_column(pheno, c("germplasmName", "accession_name", "accessionName", "stockName"), "accession")
  location_col <- find_column(pheno, c("locationName", "location", "studyLocation"), "location")
  trial_col <- c("studyName", "trialName", "trial_name", "projectName")
  year_col <- c("year", "Year", "season")
  design_col <- c("studyDesign", "study_design", "trialDesign", "design")
  rep_col <- c("replicate", "rep_number", "repNumber", "rep")
  block_col <- c("blockNumber", "block_number", "block", "block_number")
  row_col <- c("rowNumber", "row_number", "Y", "y")
  col_col <- c("colNumber", "col_number", "X", "x")

  location <- as.character(pheno[[location_col]])
  trial <- rep("", nrow(pheno))
  year <- rep("", nrow(pheno))
  environment_parts <- list(location)
  if (any(trial_col %in% colnames(pheno))) {
    trial <- as.character(pheno[[trial_col[trial_col %in% colnames(pheno)][1]]])
    environment_parts <- c(environment_parts, list(trial))
  }
  if (any(year_col %in% colnames(pheno))) {
    year <- as.character(pheno[[year_col[year_col %in% colnames(pheno)][1]]])
    environment_parts <- c(environment_parts, list(year))
  }

  environment <- do.call(paste, c(environment_parts, sep = "_"))
  study_design <- if (any(design_col %in% colnames(pheno))) {
    pheno[[design_col[design_col %in% colnames(pheno)][1]]]
  } else {
    ""
  }
  rep_number <- if (any(rep_col %in% colnames(pheno))) {
    pheno[[rep_col[rep_col %in% colnames(pheno)][1]]]
  } else {
    "1"
  }
  block_number <- if (any(block_col %in% colnames(pheno))) {
    pheno[[block_col[block_col %in% colnames(pheno)][1]]]
  } else {
    "1"
  }
  row_number <- if (any(row_col %in% colnames(pheno))) {
    pheno[[row_col[row_col %in% colnames(pheno)][1]]]
  } else {
    "1"
  }
  col_number <- if (any(col_col %in% colnames(pheno))) {
    pheno[[col_col[col_col %in% colnames(pheno)][1]]]
  } else {
    "1"
  }

  df <- data.frame(
    environment = as.character(environment),
    location = location,
    trial = trial,
    year = year,
    study_design = as.character(study_design),
    accession_name = as.character(pheno[[accession_col]]),
    rep_number = as.character(rep_number),
    block_number = as.character(block_number),
    row_number = as.character(row_number),
    col_number = as.character(col_number),
    phenotype = as.numeric(gsub(",", ".", as.character(pheno[[trait_col]]))),
    stringsAsFactors = FALSE
  ) %>%
    dplyr::filter(!is.na(environment), !is.na(accession_name), !is.na(phenotype), accession_name != "")

  env_info <- df %>%
    dplyr::distinct(environment, location, trial, year) %>%
    dplyr::arrange(location, trial, year) %>%
    complete_environment_info()

  anova_results <- calculate_anova(df)

  summary <- data.frame(
    trait = trait_col,
    alpha = alpha,
    n_environments = dplyr::n_distinct(df$environment),
    n_genotypes = dplyr::n_distinct(df$accession_name),
    n_observations = nrow(df),
    stringsAsFactors = FALSE
  )

  if (summary$n_environments < 2) {
    write_json_rows(empty_pairwise(), pairwise_file)
    write_json_rows(empty_group_summary(), group_summary_file)
    write_json_rows(empty_group_membership(), group_membership_file)
    write_json_rows(env_info, ungrouped_file)
    write_json_rows(summary, summary_file)
    write_json_rows(anova_results, anova_file)
    write_message("The selected trait must be measured in at least two environments.")
    return(invisible(NULL))
  }

  lin_results <- lin_group_environments(data = df, alpha = alpha)

  lin_results$pairwise <- add_pairwise_environment_metadata(lin_results$pairwise, env_info)
  lin_results$group_membership <- add_environment_metadata(lin_results$group_membership, env_info)
  lin_results$ungrouped <- add_environment_metadata(lin_results$ungrouped, env_info)
  lin_results$group_summary <- environment_summary_by_group(lin_results$group_summary, lin_results$group_membership)

  write_json_rows(lin_results$pairwise, pairwise_file)
  write_json_rows(lin_results$group_summary, group_summary_file)
  write_json_rows(lin_results$group_membership, group_membership_file)
  write_json_rows(lin_results$ungrouped, ungrouped_file)
  write_json_rows(summary, summary_file)
  write_json_rows(anova_results, anova_file)

  group_count <- nrow(lin_results$group_summary)
  ungrouped_count <- nrow(lin_results$ungrouped)
  write_message(paste0(
    "Environment stratification finished. ",
    group_count,
    " compatible group(s) found; ",
    ungrouped_count,
    " environment(s) left ungrouped."
  ))
}

tryCatch(
  main(),
  error = function(e) {
    write_json_rows(empty_pairwise(), pairwise_file)
    write_json_rows(empty_group_summary(), group_summary_file)
    write_json_rows(empty_group_membership(), group_membership_file)
    write_json_rows(empty_ungrouped(), ungrouped_file)
    write_json_rows(data.frame(error = e$message), summary_file)
    write_json_rows(empty_anova(), anova_file)
    write_message(paste("Environment stratification failed:", e$message))
    stop(e)
  }
)
