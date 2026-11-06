# Compatibility for the single-field spl2D call in the existing Drone model.
# The supplied current Sommer spl2Dc basis and identity kernel were compared
# with the official Sommer 4.1.4 spl2D default (CRAN source, GPL >= 2):
# https://cran.r-project.org/src/contrib/Archive/sommer/sommer_4.1.4.tar.gz
# Ordered, shuffled and repeated coordinates have the same ordered incidence
# matrix and Z Gu Z'. This adapter uses the installed public implementation;
# no historical implementation or new spline kernel is copied here.
drone_spline_basis <- function(x.coord, y.coord) {
  variables <- c(deparse(substitute(x.coord)), deparse(substitute(y.coord)))
  if (!is.numeric(x.coord) || !is.numeric(y.coord)) {
    stop("Drone spline coordinates must be numeric.")
  }
  legacy <- sommer::spl2Dc(
    x.coord, y.coord, type = "PSANOVA", nsegments = c(10, 10),
    penaltyord = c(2, 2), degree = c(3, 3), nestorder = c(1, 1)
  )
  if (length(legacy$Z) != 1L) {
    stop("The legacy Drone spline adapter requires one spatial field.")
  }
  kernel <- as.matrix(legacy$Gu)
  if (!isTRUE(all.equal(unname(kernel), diag(nrow(kernel)),
                        check.attributes = FALSE, tolerance = 1e-12))) {
    stop("The installed Drone spline kernel needs explicit compatibility qualification.")
  }
  basis <- as.matrix(legacy$Z[[1]])
  attr(basis, "variables") <- variables
  basis
}

if (!exists("spl2D", mode = "function")) spl2D <- drone_spline_basis

# Legacy Sommer versions name this same spline term either by the first
# coordinate or by both coordinates. Resolve only those explicit contracts.
drone_spline_coefficients <- function(model, trait, basis) {
  terms <- intersect(c("u:rowNumber", "u:rowNumber:colNumber"), names(model$U))
  if (length(terms) != 1L) {
    stop("Sommer did not return one supported Drone spline coefficient term.")
  }
  coefficients <- model$U[[terms]][[trait]]
  if (is.null(coefficients) || length(coefficients) != ncol(basis)) {
    stop("Sommer spline coefficients do not match the supplied spatial basis.")
  }
  if (!is.null(colnames(basis)) && !is.null(names(coefficients))) {
    if (anyDuplicated(names(coefficients)) || !setequal(colnames(basis), names(coefficients))) {
      stop("Sommer spline coefficient IDs do not match the supplied basis columns.")
    }
    coefficients <- coefficients[colnames(basis)]
  }
  coefficients
}

# Standard Drone model CSV: eight metadata columns followed by encoded traits
# or time-point columns. Decode CSV quoting before categorical factor creation;
# literal "NA" is a valid recorded tag, whereas an empty tag records unknown.
# The existing fixed-trait workflow explicitly projects quantitative bins into
# its local replicate column. Only that caller opts into quantitative_replicate;
# recorded design tags are categorical by default and are never inferred.
drone_read_model_csv <- function(path, quantitative_replicate = FALSE) {
  data <- read.csv(path, header = TRUE, colClasses = "character",
                   na.strings = character(), check.names = FALSE,
                   stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  groups <- intersect(c("replicate", "block", "rowNumberFactor", "colNumberFactor",
                        "fixed_effect_trait_binned"), names(data))
  if (quantitative_replicate) groups <- setdiff(groups, "replicate")
  text_columns <- c(groups, "id", "plot_id", "studyDesign")
  for (column in groups) {
    data[[column]][data[[column]] == ""] <- NA_character_
    data[[column]] <- factor(data[[column]])
  }
  for (column in setdiff(names(data), text_columns)) {
    values <- data[[column]]
    missing <- is.na(values) | values %in% c("NA", "", "--", "-", ".", "..")
    numeric_values <- suppressWarnings(as.numeric(values))
    if (any(!missing & !is.finite(numeric_values))) {
      stop("Drone model CSV requires numeric values for ", column, ".")
    }
    numeric_values[missing] <- NA_real_
    data[[column]] <- numeric_values
  }
  data
}
