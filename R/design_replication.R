# Analytical phenotype tables use the existing replicate metadata slot for
# the recorded design tag. Operational accession occurrences are not factors.
# All group codes remain text: "01", "1", "0" and "NA" are distinct tags.
read_analysis_phenotypes <- function(file, sep = "\t", check.names = FALSE,
                                     quote = "", fill = TRUE) {
  data <- read.table(file, header = TRUE, sep = sep, check.names = check.names,
                     quote = quote, comment.char = "", fill = fill,
                     stringsAsFactors = FALSE, colClasses = "character",
                     na.strings = character(), fileEncoding = "UTF-8")
  text_columns <- c("replicate", "designReplicate", "design_rep_number", "blockNumber",
                    "block_number", "germplasmName", "observationUnitName", "studyName",
                    "locationName", "studyDesign", "entryType", "programName", "notes",
                    "germplasmDbId", "observationUnitDbId", "studyDbId", "locationDbId")
  missing_values <- c("NA", "", "--", "-", ".", "..")
  for (column in setdiff(names(data), text_columns)) {
    data[[column]] <- type.convert(data[[column]], as.is = TRUE, na.strings = missing_values)
  }
  for (column in intersect(c("replicate", "designReplicate", "design_rep_number", "blockNumber", "block_number"), names(data))) {
    # Empty is how the native unquoted table represents a recorded NULL tag.
    # Never reinterpret a nonempty tag such as "NA" as missing metadata.
    data[[column]][!is.na(data[[column]]) & data[[column]] == ""] <- NA_character_
  }
  data
}

recorded_design_column <- function(data, required = TRUE) {
  for (column in c("designReplicate", "design_rep_number", "replicate")) {
    if (column %in% names(data)) return(column)
  }
  if (required) stop("The analytical input is missing its recorded design replication metadata.")
  NULL
}

recorded_design_replicates <- function(data, required = TRUE) {
  column <- recorded_design_column(data, required)
  if (is.null(column)) return(rep(NA_character_, nrow(data)))
  as.character(data[[column]])
}

with_design_replication <- function(data) {
  if (!"designReplicate" %in% names(data)) {
    data$designReplicate <- recorded_design_replicates(data)
  }
  data
}

canonical_design_formula <- function(formula, data) {
  if (!"designReplicate" %in% names(data)) return(formula)
  translate <- function(term) {
    if (is.symbol(term) && identical(as.character(term), "replicate")) return(as.name("designReplicate"))
    if (is.call(term)) for (i in seq_along(term)[-1]) term[[i]] <- translate(term[[i]])
    term
  }
  result <- formula
  for (i in seq_along(result)[-1]) result[[i]] <- translate(result[[i]])
  result
}

validate_design_group_terms <- function(formula, data) {
  groups <- intersect(all.vars(formula), c("replicate", "designReplicate", "blockNumber"))
  if (!length(groups)) return(invisible(NULL))
  if (!"studyDesign" %in% names(data) || anyNA(data$studyDesign) || any(trimws(data$studyDesign) == "")) {
    stop("Declare studyDesign before fitting recorded design-group effects.")
  }
  crd <- grepl("^crd$|completely randomized|completely randomised", tolower(trimws(data$studyDesign)))
  if (any(crd)) stop("A CRD has no experimental blocking groups. Remove recorded replicate/block effects from this model.")
  for (column in groups) {
    values <- as.character(data[[column]])
    if (anyNA(values) || any(trimws(values) == "")) {
      stop("Recorded design metadata is missing for ", column, "; accession occurrence labels cannot replace it.")
    }
  }
  invisible(NULL)
}

# Standard single-trial models used by phenoAnalysis, with a genuine unblocked
# CRD branch. Do not let the package add a random effect for CRD occurrence tags.
analysis_run_anova <- function(trialData, traitName = NULL, genotypeEffectType = "fixed", logReturn = FALSE) {
  if (is.null(traitName) || !traitName %in% names(trialData)) stop("The selected trait was not found.")
  if (!"studyDesign" %in% names(trialData)) stop("The analytical input must declare studyDesign.")
  assert_genotype_name_identity(trialData)
  if ("studyName" %in% names(trialData) && length(unique(trialData$studyName)) != 1L) stop("Fit single-trial design adjustments before combining trials.")
  designs <- unique(tolower(trimws(as.character(trialData$studyDesign))))
  if (length(designs) != 1L || is.na(designs) || designs == "") stop("One declared studyDesign is required for adjustment.")
  design <- designs[1]
  data <- trialData
  data$germplasmName <- factor(data$germplasmName)
  data$trait <- data[[traitName]]
  if (!is.numeric(data$trait)) stop("The selected trait must be numeric.")
  if(!genotypeEffectType %in% c("fixed","random")) stop("Choose fixed or random genotype effects.")
  genotype <- if (genotypeEffectType == "fixed") "germplasmName" else "(1|germplasmName)"
  if (grepl("^crd$|completely randomized|completely randomised", design)) {
    model_formula <- stats::reformulate(genotype, response = "trait")
  } else if (grepl("rcbd|randomi[sz]ed complete block|augmented", design)) {
    if (!"blockNumber" %in% names(data) || anyNA(data$blockNumber) || any(trimws(data$blockNumber) == "")) stop("Recorded blockNumber metadata is required; occurrence labels cannot replace it.")
    data$blockNumber <- factor(data$blockNumber)
    if (nlevels(data$blockNumber) < 2L) stop("At least two recorded blocks are required for this adjustment.")
    model_formula <- stats::reformulate(c(genotype, "(1|blockNumber)"), response = "trait")
  } else if (grepl("alpha|lattice|incomplete", design)) {
    data$replicate <- factor(recorded_design_replicates(data))
    if (anyNA(data$replicate) || nlevels(data$replicate) < 2L) stop("Incomplete-block adjustment requires at least two nonmissing recorded design replication tags.")
    if (!"blockNumber" %in% names(data) || anyNA(data$blockNumber)) stop("Incomplete-block adjustment requires recorded blockNumber metadata.")
    data$blockNumber <- factor(data$blockNumber)
    if (any(vapply(split(data$blockNumber, data$replicate), function(x) length(unique(x)) < 2L, logical(1)))) stop("Incomplete-block adjustment requires at least two blocks in every recorded replication group.")
    model_formula <- stats::reformulate(c(genotype, "(1|replicate/blockNumber)"), response = "trait")
  } else {
    stop("No supported design adjustment is available for studyDesign: ", design)
  }
  model <- if (length(lme4::findbars(model_formula))) lmerTest::lmer(model_formula, data = data, na.action = na.exclude) else stats::lm(model_formula, data = data, na.action = na.exclude)
  if (df.residual(model) <= 0L) stop("The design has no residual degrees of freedom for an ANOVA error estimate.")
  log <- paste0("Recorded-design adjustment for ", traitName, " (", design, "); no accession occurrence number is a blocking factor.\n")
  if (logReturn) list(modelOut = model, log = log) else model
}

analysis_adjusted_means <- function(trialData = NULL, traitName = NULL, modelOut = NULL,
                                    genotypeEffectType = "fixed", adjMeansVariable = "germplasmName",
                                    calcAverages = FALSE, logReturn = FALSE) {
  log <- character()
  if (!is.null(trialData) && adjMeansVariable == "germplasmName") assert_genotype_name_identity(trialData)
  if (is.null(modelOut)) {
    fit <- tryCatch(analysis_run_anova(trialData, traitName, genotypeEffectType, logReturn = TRUE),error=function(e) e)
    if(inherits(fit,"error")) {
      if(!calcAverages) stop(fit)
      # Existing solGS callers explicitly request arithmetic averages when a
      # design adjustment is unavailable. Label that output and record why.
      warning("Design adjustment unavailable: ",conditionMessage(fit)," Returning explicitly requested arithmetic means.")
      result <- aggregate(trialData[[traitName]],list(trialData[[adjMeansVariable]]),mean,na.rm=TRUE)
      names(result) <- c(adjMeansVariable,paste0(traitName,"_Arithmetic_mean"))
      log <- paste0("ANOVA adjustment was unavailable: ",conditionMessage(fit),"\nThe ",traitName," values are arithmetic averages, not adjusted means.\n")
      return(if(logReturn) list(adjMeans=result,log=log) else result)
    }
    modelOut <- fit$modelOut
    log <- fit$log
  }
  if (genotypeEffectType == "fixed") {
    means <- as.data.frame(emmeans::emmeans(modelOut, specs = adjMeansVariable))
    result <- means[,c(adjMeansVariable,"emmean"),drop = FALSE]
    result[[2]] <- round(result[[2]],2)
    names(result)[2] <- paste0(traitName,"_Adjusted_means_fixed_effects")
  } else {
    effect <- lme4::ranef(modelOut)[[adjMeansVariable]]
    if (is.null(effect) || ncol(effect) != 1L) stop("Adjusted genotype means require a single genotype random intercept.")
    fixed_mean <- as.data.frame(emmeans::emmeans(modelOut, ~ 1))$emmean[1]
    result <- data.frame(identity = rownames(effect), value = round(effect[[1]]+fixed_mean,5))
    names(result) <- c(adjMeansVariable,paste0(traitName,"_Adjusted_means_random_effects"))
  }
  if (logReturn) list(adjMeans = result, log = log) else result
}

analysis_anova_table <- function(modelOut, tableType = "text", traitName = NULL, ...) {
  table <- stats::anova(modelOut)
  capture.output(stargazer::stargazer(table,type=tableType,title=paste0("ANOVA result: ",traitName),summary=FALSE,digits=2,header=FALSE,...))
}

# Name-keyed genotype fits/results cannot distinguish distinct known IDs with
# one label, or one known ID with conflicting labels. Legacy name-only inputs
# remain supported; operational and plot-only readers do not call this guard.
assert_genotype_name_identity <- function(data, id_column = "germplasmDbId",
                                           name_column = "germplasmName") {
  if (!all(c(id_column, name_column) %in% names(data))) return(invisible(TRUE))
  ids <- as.character(data[[id_column]])
  labels <- as.character(data[[name_column]])
  known <- !is.na(ids) & !ids %in% c("", "0", "NA", "--", "-", ".", "..") &
           !is.na(labels) & nzchar(labels)
  pairs <- unique(data.frame(id = ids[known], label = labels[known], stringsAsFactors = FALSE))
  if (anyDuplicated(pairs$label)) {
    stop("A genotype name maps to multiple known germplasm IDs; this name-keyed analysis cannot represent them separately.")
  }
  if (anyDuplicated(pairs$id)) {
    stop("A known germplasm ID maps to multiple genotype names; this name-keyed analysis requires consistent genotype metadata.")
  }
  invisible(TRUE)
}
