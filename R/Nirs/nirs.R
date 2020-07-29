# Runs `waves` package with data from the NIRS Breedbase tool to generate phenotypic predictions

# AUTHOR
# Jenna Hershberger (jmh579@cornell.edu)

# Load packages
library(dplyr)
library(magrittr)
library(devtools)
library(jsonlite)
library(waves)

# Error handling
# TODO where do I check for genotype and/or environment overlap for the CVs? Here or in controller?

#### Read in and assign arguments ####
args <- commandArgs(trailingOnly = TRUE)

# args[1] = phenotype of interest (string with ontology name)
pheno <- args[1]

# args[2] = test preprocessing methods boolean
preprocessing <- ifelse(args[2]=="TRUE", TRUE, FALSE)

# args[3] = number of sampling iterations
num.iterations <- as.numeric(args[3])

# args[4] = model algorithm
model.method <- args[4]

# args[5] = tune length
tune.length <- as.numeric(args[5])

# args[6] = Random Forest variable importance
rf.var.importance <- ifelse(args[6]=="TRUE", TRUE, FALSE)

# args[7] = CV method as string
cv.scheme <- args[7]
## Set cv.scheme to NULL if != CV1, CV2, CV0, or CV00
stratified.sampling <- TRUE
if(cv.scheme == "random"){
  stratified.sampling <- FALSE
  cv.scheme <- NULL
} else if(cv.scheme == "stratified"){
  cv.scheme <- NULL
}

# args[8] = training data.frame: observationUnit level data with phenotypes and spectra in JSON format
train.ready <- jsonlite::fromJSON(txt = args[8], flatten = T) %>%
  rename(uniqueid = observationUnitId) %>%
  rename_at(vars(starts_with("trait.")), ~paste0("reference")) %>%
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "X"))

# args[9] = test data.frame: observationUnit level data with phenotypes and spectra in JSON format
if(args[9] != "NULL"){
  test.ready <- jsonlite::fromJSON(txt = args[9], flatten = T) %>%
  rename(uniqueid = observationUnitId) %>%
  rename_at(vars(starts_with("trait.")), ~paste0("reference")) %>%
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "X"))
} else{
  test.input <- NULL
}

wls <- ncol(train.ready) - 2

if(is.null(cv.scheme)){
  # Test model using non-specialized cv scheme
  results.df <- TestModelPerformance(train.data = train.ready, num.iterations = num.iterations,
                                     test.data = test.ready, preprocessing = preprocessing,
                                     wavelengths = wls, tune.length = tune.length,
                                     model.method = model.method, output.summary = TRUE,
                                     rf.variable.importance = rf.var.importance,
                                     stratified.sampling = stratified.sampling, cv.scheme = NULL,
                                     trial1 = NULL, trial2 = NULL, trial3 = NULL)
} else{
  # Test model using specialized cv scheme
  results.df <- TestModelPerformance(train.data = NULL, num.iterations = num.iterations,
                                     test.data = NULL, preprocessing = preprocessing,
                                     wavelengths = wls, tune.length = tune.length,
                                     model.method = model.method, output.summary = TRUE,
                                     rf.variable.importance = rf.var.importance,
                                     stratified.sampling = FALSE, cv.scheme = cv.scheme,
                                     trial1 = training.input, trial2 = test.input,
                                     trial3 = NULL)

}

if(rf.var.importance){
  var.imp <- results.df[[2]]
  results.df <- results.df[[1]]
}

# args[10] = table output file name
write.table(x = results.df, file = args[10], row.names = F)

# args[11] = figure output file name
ggsave(filename = args[11], plot = results.plot, device = "png")

# args[12] = variable importance results output file name
if(rf.var.importance){
  write.table(var.imp, file = args[12], row.names = F)
  # args[13] = variable importance figure output file name
  ggsave(filename = args[13], plot = results.plot, device = "png")
}
