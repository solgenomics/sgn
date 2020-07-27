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
# TODO Check that number and wls of test and training dfs match
# TODO Check that spectrometer types match

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


if(is.null(cv.scheme)){
  # args[8] = training data.frame: observationUnit level data with phenotypes and spectra in JSON format
  # TODO do we need to read in a separate pheno file or will it be included in the json with spectra?
  df.ready <- jsonlite::fromJSON(txt = args[8], flatten = T) %>% 
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
  
  wls <- ncol(df.ready) - 2

  # Test model
  results.df <- TestModelPerformance(train.data = df.ready, num.iterations = num.iterations, 
                                     test.data = test.ready, preprocessing = preprocessing, 
                                     wavelengths = wls, tune.length = tune.length, 
                                     model.method = model.method, output.summary = TRUE,
                                     rf.variable.importance = rf.var.importance, 
                                     stratified.sampling = stratified.sampling, cv.scheme = NULL,
                                     trial1 = NULL, trial2 = NULL, trial3 = NULL)
  
} else{
  training.input <- NULL
  test.input <- NULL
  
  # args[10:11] = trial1 and trial2
  trial1.ready <- jsonlite::fromJSON(args[10]) %>% rename(reference = pheno, uniqueid = observationunitid) %>%
    %>% rename_at(vars(starts_with("nirs_spectra")), funs(str_replace(., "nirs_spectra.", "X")))
  trial2.ready <- jsonlite::fromJSON(args[11]) %>% rename(reference = pheno, uniqueid = observationunitid) %>%
    %>% rename_at(vars(starts_with("nirs_spectra")), funs(str_replace(., "nirs_spectra.", "X")))
  
  # args[12] = trial3
  trial3.input <- NULL
  if(args[12] != "NULL"){
    trial3.ready <- jsonlite::fromJSON(args[12]) %>% rename(reference = pheno, uniqueid = observationunitid) %>%
    %>% rename_at(vars(starts_with("nirs_spectra")), funs(str_replace(., "nirs_spectra.", "X")))
  }
  
  wls <- ncol(trial1.ready) - 2
  
  # Test model
  results.df <- TestModelPerformance(train.data = NULL, num.iterations = num.iterations, 
                                     test.data = NULL, preprocessing = preprocessing, 
                                     wavelengths = wls, tune.length = tune.length, 
                                     model.method = model.method, output.summary = TRUE,
                                     rf.variable.importance = rf.var.importance, 
                                     stratified.sampling = FALSE, cv.scheme = cv.scheme,
                                     trial1 = trial1.ready, trial2 = trial2.ready, 
                                     trial3 = trial3.ready)
  
}

if(rf.var.importance){
  var.imp <- results.df[[2]]
  results.df <- results.df[[1]]
}

# TODO output results summary table, variable importance results, and figure
# TODO save model

# args[13] = table output file name
write.table(x = results.df, file = args[13], row.names = F)

# argsp[14] = figure output file name
ggsave(filename = args[14], plot = results.plot, device = "png")

# args[15] = variable importance results output file name
if(rf.var.importance){
  write.table(var.imp, file = args[15], row.names = F)
  # args[16] = variable importance figure output file name
  ggsave(filename = args[16], plot = results.plot, device = "png")
}



