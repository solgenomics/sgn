# Actual Sommer entrypoint; output schemas are shared across both engines.
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
source(file.path(dirname(normalizePath(script_path)), "mixed_models_sommer_common.R"))
for (argument in commandArgs(trailingOnly = TRUE)) eval(parse(text = argument))
if (!exists("datafile") || !exists("paramfile")) stop("Phenotype datafile and model paramfile are required.")
tryCatch(run_sommer_model(datafile, paramfile, spatial = TRUE), error = function(e) {
  writeLines(conditionMessage(e), paste0(datafile, ".model_error"))
  stop(e)
})
