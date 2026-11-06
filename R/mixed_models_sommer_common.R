# Load the explicit analytical recorded-design-tag contract.
design_source <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) design_source <- frame$ofile
if (is.null(design_source)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    design_source <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) design_source <- invocation[file_index[1] + 1L]
  }
}
if (is.null(design_source) || is.na(design_source) || !nzchar(design_source)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(design_source)), "design_replication.R"), local = TRUE)

# Shared, version-aware Sommer execution for ordinary and spline mixed models.
# Genotype outputs use public marginal predictions and trait-unit BLUPs.
prepare_sommer_spline_basis <- function(data) {
  # Reuse the package's exact spline basis. Current spl2Dc still returns a
  # legacy covariance list, whereas mmes requires a public vsm v2 descriptor.
  legacy <- with(data, sommer::spl2Dc(rowNumber, colNumber, at.var = locationDbId))
  columns <- colnames(legacy$Z[[1]])
  if (!all(vapply(legacy$Z, function(z) identical(colnames(z), columns), logical(1)))) {
    stop("Spatial fields with incompatible spline bases require separate analyses.")
  }
  kernel <- as.matrix(legacy$Gu)
  if (!isTRUE(all.equal(unname(kernel), diag(nrow(kernel)), check.attributes = FALSE))) {
    stop("This Sommer interface requires qualification for the installed nonidentity spline kernel.")
  }
  list(basis = Reduce(`+`, legacy$Z), kernel = legacy$Gu)
}

normalize_sommer_random <- function(formula, modern) {
  if (!modern) return(formula)
  translate <- function(term) {
    if (!is.call(term)) return(term)
    name <- as.character(term[[1]])
    if (name == "vsr") {
      arguments <- as.list(term)[-1]
      if (length(arguments) == 1L && is.symbol(arguments[[1]])) {
        # A simple legacy vsr(factor) is an iid factor intercept.
        return(as.call(list(as.name("vsm"), as.call(list(as.name("ism"), arguments[[1]])))))
      }
      if (length(arguments) == 2L && identical(as.character(arguments[[1]]), "locationDbId") &&
          is.symbol(arguments[[2]]) && as.character(arguments[[2]]) %in% c("Rowf", "Colf")) {
        return(as.call(list(as.name("vsm"),
          as.call(list(as.name("dsm"), arguments[[1]])),
          as.call(list(as.name("ism"), arguments[[2]])))))
      }
      stop("This Sommer interface supports factor random intercepts and the standard spatial row/column terms; use lme4 for other random-slope terms.")
    }
    if (name %in% c("spl2Da", "spl2Dc")) {
      arguments <- as.list(term)[-1]
      if (length(arguments) != 3L || !identical(as.character(arguments[[1]]), "rowNumber") ||
          !identical(as.character(arguments[[2]]), "colNumber") ||
          !identical(names(arguments)[3], "at.var") ||
          !identical(as.character(arguments[[3]]), "locationDbId")) {
        stop("The Sommer spatial interface supports the standard rowNumber/colNumber spline scoped by locationDbId.")
      }
      return(quote(vsm(dsm(locationDbId), ism(.sommerSplineBasis), Gu = .sommerSplineKernel)))
    }
    for (i in seq.int(2L, length(term))) term[[i]] <- translate(term[[i]])
    term
  }
  result <- formula
  result[[2]] <- translate(formula[[2]])
  result
}

run_sommer_model <- function(datafile, paramfile, spatial = FALSE) {
  suppressPackageStartupMessages(library(sommer))
  parameters <- new.env(parent = environment())
  sys.source(paramfile, envir = parameters)
  traits <- parameters$dependent_variables
  if (length(traits) != 1L) stop("The Sommer engines support one selected trait per analysis.")
  trait <- traits[1]
  data <- with_design_replication(read_analysis_phenotypes(datafile, check.names = TRUE))
  if (!trait %in% names(data)) stop("The selected trait was not found in the phenotype data: ", trait)
  if (!is.numeric(data[[trait]])) stop("The selected trait must be numeric.")
  data <- data[!is.na(data[[trait]]), , drop = FALSE]
  if (!nrow(data)) stop("No observed records remain for the selected trait.")
  assert_genotype_name_identity(data)
  for (column in intersect(c("germplasmName", "studyYear", "designReplicate", "blockNumber", "locationDbId"), names(data))) {
    data[[column]] <- factor(data[[column]])
  }
  if (!"germplasmName" %in% names(data) || anyNA(data$germplasmName)) stop("Nonmissing germplasmName values are required for genotype output.")
  fixed_text <- parameters$fixed_model
  random_text <- parameters$random_model
  if (spatial) {
    for (column in c("locationDbId", "rowNumber", "colNumber")) {
      if (!column %in% names(data) || anyNA(data[[column]])) stop("Spatial analysis requires nonmissing ", column, " metadata.")
    }
    data$rowNumber <- as.numeric(data$rowNumber)
    data$colNumber <- as.numeric(data$colNumber)
    if (any(!is.finite(data$rowNumber)) || any(!is.finite(data$colNumber))) stop("Spatial row/column coordinates must be numeric.")
    data$Rowf <- factor(data$rowNumber)
    data$Colf <- factor(data$colNumber)
    fixed_text <- gsub("locationName", "locationDbId", fixed_text, fixed = TRUE)
    random_text <- gsub("locationName", "locationDbId", random_text, fixed = TRUE)
  }
  fixed_formula <- canonical_design_formula(as.formula(fixed_text), data)
  validate_design_group_terms(fixed_formula, data)
  fixed_genotype <- "germplasmName" %in% all.vars(fixed_formula)
  exports <- getNamespaceExports("sommer")
  modern <- "mmes" %in% exports && "predict.mmes" %in% exports
  legacy <- "mmer" %in% exports && "predict.mmer" %in% exports
  if (!modern && !legacy) stop("The installed Sommer version lacks a supported fit/prediction API (mmes or legacy mmer with predict.mmer).")
  if (modern && spatial) {
    spline <- prepare_sommer_spline_basis(data)
    .sommerSplineBasis <- spline$basis
    .sommerSplineKernel <- spline$kernel
  }
  random_formula <- if (nzchar(random_text)) normalize_sommer_random(canonical_design_formula(as.formula(random_text, env = environment()), data), modern) else NULL
  if (!is.null(random_formula)) validate_design_group_terms(random_formula, data)
  random_genotype <- !is.null(random_formula) && "germplasmName" %in% all.vars(random_formula)
  if (fixed_genotype == random_genotype) stop("Select germplasmName either as a fixed effect or as one random genotype intercept.")
  fit_function <- getExportedValue("sommer", if (modern) "mmes" else "mmer")
  arguments <- list(fixed = fixed_formula, rcov = ~ units, data = data)
  if (!is.null(random_formula)) arguments$random <- random_formula
  if ("verbose" %in% names(formals(fit_function))) arguments$verbose <- FALSE
  if ("dateWarning" %in% names(formals(fit_function))) arguments$dateWarning <- FALSE
  fit <- do.call(fit_function, arguments)
  if (!isTRUE(fit$convergence)) stop("The Sommer model did not converge; revise the selected factors or spatial design before saving genotype output.")
  table <- fit$Dtable
  if (!all(c("term", "type", "include", "average") %in% names(table))) stop("Sommer did not return the supported prediction-term table.")
  mentions_genotype <- vapply(as.character(table$term), function(term) "germplasmName" %in% all.vars(str2lang(term)), logical(1))
  if (random_genotype && sum(table$type == "random" & mentions_genotype) != 1L) stop("Genotype output requires exactly one random genotype-intercept term.")
  table$include <- mentions_genotype
  # Fixed effects are marginalised over their levels. Other random effects,
  # including spatial effects, are excluded from adjusted genotype means.
  table$average <- table$type == "fixed"
  predict_function <- if (modern) stats::predict else getExportedValue("sommer", "predict.mmer")
  prediction <- predict_function(fit, Dtable = table, D = "germplasmName")$pvals
  value_column <- intersect(c("predicted.value", "predicted_value"), names(prediction))
  if (!"germplasmName" %in% names(prediction) || length(value_column) != 1L || any(!is.finite(prediction[[value_column]]))) stop("Sommer did not return estimable genotype marginal means.")
  adjusted <- data.frame(germplasmName = as.character(prediction$germplasmName), estimate = prediction[[value_column]])
  names(adjusted)[2] <- trait
  if (anyDuplicated(adjusted$germplasmName) || !setequal(adjusted$germplasmName, as.character(data$germplasmName))) stop("Sommer genotype predictions do not match the analysed genotype IDs.")
  if (random_genotype) {
    term <- as.character(table$term[table$type == "random" & mentions_genotype])
    if (modern) {
      values <- fit$uList[[term]]
      if (is.null(values) || !is.matrix(values) || ncol(values) != 1L) stop("Sommer did not return supported trait-unit genotype BLUPs.")
      raw <- data.frame(germplasmName = rownames(values), estimate = values[,1])
    } else {
      values <- fit$U[[term]]
      if (is.null(values) || length(values) != 1L) stop("Sommer did not return supported legacy genotype BLUPs.")
      values <- values[[1]]
      raw <- data.frame(germplasmName = names(values), estimate = as.numeric(values))
    }
    names(raw)[2] <- trait
    if (anyDuplicated(raw$germplasmName) || !setequal(raw$germplasmName, adjusted$germplasmName)) stop("Sommer BLUPs do not match the analysed genotype IDs.")
    write.table(raw, paste0(datafile,".BLUPs"), quote = FALSE, sep = "\t", row.names = FALSE)
    write.table(adjusted, paste0(datafile,".adjustedBLUPs"), quote = FALSE, sep = "\t", row.names = FALSE)
  } else {
    write.table(adjusted, paste0(datafile,".BLUEs"), quote = FALSE, sep = "\t", row.names = FALSE)
    write.table(adjusted, paste0(datafile,".adjustedBLUEs"), quote = FALSE, sep = "\t", row.names = FALSE)
  }
  invisible(fit)
}
