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
source(file.path(dirname(normalizePath(design_source)), "../design_replication.R"), local = TRUE)

# Shared design factors for the two phenotype heritability consumers.
# These fixed design effects do not add a new H2 variance component/estimand.
canonical_trial_design <- function(x) {
  x <- trimws(tolower(as.character(x)))
  if (anyNA(x) || any(x == "")) stop("A declared studyDesign is required for heritability analysis.")
  canonical <- vapply(x, function(design) {
    if (grepl("^crd$|completely randomized|completely randomised", design)) return("CRD")
    if (grepl("^rcbd$|randomized complete block|randomised complete block", design)) return("RCBD")
    if (grepl("alpha|lattice|incomplete", design)) return("Incomplete block")
    if (grepl("augmented", design)) return("Augmented")
    stop("Unsupported studyDesign for heritability analysis: ", design)
  }, character(1))
  if (length(unique(canonical)) != 1L) stop("Mixed study designs require separate heritability analyses.")
  canonical[1]
}

# Standard sum-to-zero contrasts within each parent design group. Block
# contrasts sum to zero across block levels within replicate/environment;
# replicate contrasts sum to zero across replicates within environment. They
# cannot absorb an environment mean as fully dummy-coded nested IDs would.
nested_design_contrasts <- function(parent, child, prefix) {
  pieces <- list()
  for (group in levels(droplevels(factor(parent)))) {
    rows <- which(as.character(parent) == group)
    levels_in_group <- droplevels(factor(child[rows]))
    if (nlevels(levels_in_group) < 2L) next
    contrast <- contr.sum(nlevels(levels_in_group))
    piece <- matrix(0, nrow = length(parent), ncol = ncol(contrast))
    piece[rows, ] <- contrast[as.integer(levels_in_group), , drop = FALSE]
    colnames(piece) <- paste(prefix, group, seq_len(ncol(piece)), sep = "_")
    pieces[[length(pieces) + 1L]] <- piece
  }
  if (!length(pieces)) return(matrix(numeric(), nrow = length(parent), ncol = 0))
  do.call(cbind, pieces)
}

prepare_heritability_design <- function(data) {
  if (!"studyDesign" %in% names(data)) stop("The phenotype data must include studyDesign.")
  if (!"germplasmName" %in% names(data)) stop("The phenotype data must include germplasmName.")
  assert_genotype_name_identity(data)
  design <- canonical_trial_design(data$studyDesign)
  scope <- intersect(c("studyDbId", "studyName", "locationName", "studyYear"), names(data))
  scope <- scope[vapply(scope, function(column) any(!is.na(data[[column]]) & trimws(as.character(data[[column]])) != ""), logical(1))]
  if (!length(scope)) stop("Study or location metadata is required to scope design blocks.")
  scope_ids <- lapply(scope, function(column) {
    values <- as.character(data[[column]])
    if (anyNA(values) || any(trimws(values) == "")) stop("Missing design environment metadata: ", column)
    match(values, unique(values))
  })
  data$.trialEnvironment <- do.call(interaction, c(scope_ids, list(drop = TRUE)))
  data$germplasmName <- factor(data$germplasmName)
  if ("locationName" %in% names(data)) data$locationName <- factor(data$locationName)
  if ("studyYear" %in% names(data)) data$studyYear <- factor(data$studyYear)
  fixed_terms <- character()
  require_factor <- function(column) {
    if (!column %in% names(data)) stop(design, " requires ", column, " metadata.")
    values <- as.character(data[[column]])
    if (anyNA(values) || any(trimws(values) == "")) stop(design, " requires nonmissing ", column, " metadata.")
    factor(values)
  }
  if (design %in% c("RCBD", "Augmented", "Incomplete block")) {
    data$blockNumber <- require_factor("blockNumber")
    if (any(vapply(split(data$blockNumber, data$.trialEnvironment), function(x) length(unique(x)) < 2L, logical(1)))) {
      stop(design, " requires at least two actual blocks in each study/environment; replicate occurrence numbers are not a substitute.")
    }
    if (design == "Incomplete block") {
      data$designReplicate <- factor(recorded_design_replicates(data))
      if (anyNA(data$designReplicate) || any(trimws(as.character(data$designReplicate)) == "")) stop("Incomplete block designs require nonmissing recorded design replication tags.")
      if (any(vapply(split(data$designReplicate, data$.trialEnvironment), function(x) length(unique(x)) < 2L, logical(1)))) {
        stop("Incomplete block designs require at least two replicates in each study/environment.")
      }
      data$.trialReplicate <- interaction(data$.trialEnvironment, data$designReplicate, drop = TRUE)
      if (any(vapply(split(data$blockNumber, data$.trialReplicate), function(x) length(unique(x)) < 2L, logical(1)))) {
        stop("Incomplete block designs require at least two blocks within each replicate.")
      }
      data$.trialBlock <- interaction(data$.trialReplicate, data$blockNumber, drop = TRUE)
      effects <- cbind(
        nested_design_contrasts(data$.trialEnvironment, data$designReplicate, "replicate"),
        nested_design_contrasts(data$.trialReplicate, data$blockNumber, "block")
      )
      data$.h2DesignEffects <- I(effects)
      fixed_terms <- ".h2DesignEffects"
    } else {
      data$.trialBlock <- interaction(data$.trialEnvironment, data$blockNumber, drop = TRUE)
      data$.h2DesignEffects <- I(nested_design_contrasts(data$.trialEnvironment, data$blockNumber, "block"))
      fixed_terms <- ".h2DesignEffects"
    }
  }
  # A CRD has no blocking effect for its recorded replication tag.
  list(data = data, fixed_terms = fixed_terms, design = design)
}

fit_heritability_trait <- function(data, outcome, include_location = FALSE, include_year = FALSE) {
  required <- c(if (include_location) "locationName", if (include_year) "studyYear")
  for (column in required) {
    if (!column %in% names(data) || anyNA(data[[column]]) || any(trimws(as.character(data[[column]])) == "")) {
      stop("Nonmissing ", column, " metadata is required for the selected heritability model.")
    }
  }
  prepared <- prepare_heritability_design(data)
  data <- prepared$data
  data$.h2Response <- data[[outcome]]
  if (!is.numeric(data$.h2Response)) stop("The selected trait must be numeric: ", outcome)
  terms <- c("(1|germplasmName)", prepared$fixed_terms)
  if (include_location && "locationName" %in% names(data) && nlevels(data$locationName) > 1L) terms <- c(terms, "(1|locationName)")
  if (include_year && "studyYear" %in% names(data) && nlevels(data$studyYear) > 1L) terms <- c(terms, "studyYear")
  if ("(1|locationName)" %in% terms) {
    # A global fixed intercept overlaps the random-location mean as usual;
    # all remaining location contrasts must remain identifiable after design
    # and year adjustments, including after trait-specific missing values.
    observed <- !is.na(data$.h2Response)
    fixed_terms <- prepared$fixed_terms
    if ("studyYear" %in% terms) fixed_terms <- c(fixed_terms, "studyYear")
    fixed_formula <- if (length(fixed_terms)) stats::reformulate(fixed_terms) else ~ 1
    X <- model.matrix(fixed_formula, data = data[observed, , drop = FALSE])
    locations <- droplevels(data$locationName[observed])
    if (nlevels(locations) < 2L) stop("At least two observed locations are required for the random-location component.")
    Z <- model.matrix(~ 0 + locations)
    if (qr(cbind(X, Z))$rank - qr(X)$rank < nlevels(locations) - 1L) {
      stop("Location means are confounded with fixed design/year terms; a separate location variance is not identifiable.")
    }
  }
  model <- lmer(stats::reformulate(terms, response = ".h2Response"), data = data, na.action = na.exclude)
  variance <- as.data.frame(VarCorr(model))
  component <- function(group) {
    values <- variance$vcov[variance$grp == group & is.na(variance$var2)]
    if (length(values)) as.numeric(values[1]) else 0
  }
  list(model = model, Vg = component("germplasmName"), Ve = component("locationName"), Vres = component("Residual"))
}
