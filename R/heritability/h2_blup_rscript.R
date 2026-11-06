# Phenotype heritability with explicit, categorical study-design factors.
library(rjson)
library(dplyr)
library(methods)
library(lmerTest)
# Resolve the helper both for Rscript and for source()-based regression tests.
script_path <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) script_path <- frame$ofile
if (is.null(script_path)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    script_path <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) script_path <- invocation[file_index[1] + 1L]
  }
}
if (is.null(script_path) || is.na(script_path) || !nzchar(script_path)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(script_path)), "design_factors.R"), local = TRUE)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 5L) stop("Phenotype input, selected trait and three output files are required.")
pheno <- read_analysis_phenotypes(args[1])
normalize_trait_header <- function(x) gsub("[./]", " ", gsub("[.|]CO_.*", "", x))
study_trait <- normalize_trait_header(args[2])
h2File <- args[3]
h2CsvFile <- args[4]
errorFile <- args[5]
errorMessages <- character()
Heritability <- data.frame(trait = character(), Hert = numeric(), Vg = numeric(), Ve = numeric(), Vres = numeric())

tryCatch({
  original_names <- names(pheno)
  trait_names <- grep("CO_", original_names, value = TRUE)
  names(pheno) <- normalize_trait_header(original_names)
  if (anyDuplicated(names(pheno))) stop("Trait headers are ambiguous after ontology-name normalization.")
  trait_names <- normalize_trait_header(trait_names)
  if (!length(trait_names) && study_trait %in% names(pheno)) trait_names <- study_trait
  if (!study_trait %in% trait_names) stop("The selected trait was not found in the phenotype data.")
  if (!is.numeric(pheno[[study_trait]])) stop("The selected trait is not numeric.")
  if (mean(is.na(pheno[[study_trait]])) > 0.6) stop("More than 60% of selected trait data are missing.")
  for (outcome in trait_names) {
    fit <- fit_heritability_trait(pheno, outcome, include_location = TRUE, include_year = TRUE)
    H2 <- fit$Vg / (fit$Vg + fit$Ve + fit$Vres)
    Heritability <- rbind(Heritability, data.frame(trait = outcome, Hert = round(H2, 3), Vg = round(fit$Vg, 3), Ve = round(fit$Ve, 2), Vres = round(fit$Vres, 3)))
  }
}, error = function(e) {
  errorMessages <<- conditionMessage(e)
  # An invalid trait/design must not leave a partial successful result.
  Heritability <<- Heritability[0, , drop = FALSE]
})

h2_json <- jsonlite::toJSON(na.omit(Heritability))
jsonlite::write_json(h2_json, h2File)
write.csv(Heritability, file = h2CsvFile)
if (length(errorMessages)) {
  writeLines(errorMessages, errorFile)
  stop(paste(errorMessages, collapse = "; "))
}
