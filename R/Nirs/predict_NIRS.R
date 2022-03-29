# Runs `waves` package with data from the NIRS Breedbase tool to predict phenotypes with trained NIRS models

# AUTHOR
# Jenna Hershberger (jmh579@cornell.edu)

# Load packages
library(dplyr)
library(magrittr)
library(devtools)
library(jsonlite)
library(waves)
library(stringr)
library(readr)

### Read in and assign arguments ####
args <- commandArgs(trailingOnly = TRUE)

# args[1] = new spectral data for prediction
dataset.input <- jsonlite::fromJSON(txt = args[1], flatten = T) %>%
  rename("unique.id" = observationUnitId) %>%
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "")) %>%
  dplyr::select("unique.id", num_range(prefix = "X", range = 1:100000))
print(dataset.input[1:10,1:10])

predictions <- predict_spectra(input.data = dataset.input,
                                     model.stats.location = args[2], # args[2] =  model performance statistics filepath
                                     model.location = args[3], # args[3] = model filepath
                                     model.method = args[4]) # args[4] = model method as a string

print(predictions)
write.csv(predictions, file = args[5], row.names = FALSE)
