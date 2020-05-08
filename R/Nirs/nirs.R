library(dplyr)
library(magrittr)
library(devtools)
library(rjson)

# install_github("GoreLab/waves", auth_token = github_pat())
library(waves)

# error handling 
# TODO where do I check for genotype and/or environment overlap for the CVs? Here or in controller?
# Check that number and wls of test and training dfs match
# Check that spectrometer types match

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
cv.scheme.input <- args[7]
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
  df.ready <- as.data.frame(fromJSON(args[8])) %>% 
    dplyr::select(observationUnitName, all_of(pheno), starts_with("X"))

  # args[9] = test data.frame: observationUnit level data with phenotypes and spectra in JSON format
  if(args[9] != "NULL"){
    test.ready <- as.data.frame(fromJSON(args[9])) %>% 
      dplyr::select(observationUnitName, all_of(pheno), starts_with("X"))
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
  trial1.ready <- as.data.frame(fromJSON(args[10])) %>% 
    dplyr::select(observationUnitName, all_of(pheno), starts_with("X"))
  trial2.ready <- as.data.frame(fromJSON(args[11])) %>% 
    dplyr::select(observationUnitName, all_of(pheno), starts_with("X"))
  
  # args[12] = trial3
  trial3.input <- NULL
  if(args[12] != "NULL"){
    trial3.ready <- as.data.frame(fromJSON(args[12])) %>% 
      dplyr::select(observationUnitName, all_of(pheno), starts_with("X"))
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

# TODO output results summary table and variable importance results
# TODO save model

# args[13] = output file name
output.filepath <- args[13]

write.table(results.df, output.filepath, row.names = F)



