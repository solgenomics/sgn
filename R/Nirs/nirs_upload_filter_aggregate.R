# Filter on upload and aggregate
# Jenna Hershberger 
# jmh579@cornell.edu
# 06/29/2020

library(tidyverse)
library(waves)
library(jsonlite)

#### Read in raw JSON ####
args <- commandArgs(trailingOnly = TRUE)
# one arg -- temp directory filepath
setwd(args[1])

# # TEST
# raw.spectra <- jsonlite::fromJSON(txt = "./nirs_Vs2AF_spectra_train.json", flatten = T) %>% 
#   dplyr::select(observationUnitId, starts_with("nirs_spectra")) %>%
#   type_convert(cols(.default = col_double(), observationUnitId = col_character()))

raw.spectra <- jsonlite::fromJSON(txt = raw_spectra.json, flatten = T) %>% 
  type_convert(cols(.default = col_double(), observationUnitId = col_character()))
wls <- colnames(raw.spectra) %>% 
  str_subset("nirs_spectra.") %>% 
  str_remove("nirs_spectra.") %>% 
  readr::parse_number()

#### Generate plot and identify outliers ####
spec.plot <- raw.spectra %>% 
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "")) %>%
  #rownames_to_column(var = "unique.id") %>% 
  PlotSpectra(wavelengths = wls, num.col.before.spectra = 7, window.size = 15)

#### Output plot ####
ggsave(plot = spec.plot, filename = "outlier_plot.png", units = "in", height = 7, width = 10)

#### Identify outliers ####
chisq95 <- qchisq(.95, df = length(wls))
spectra.tagged <- raw.spectra %>% 
  na.omit() %>% 
  FilterSpectra(., filter = F, return.distances = T,
                num.col.before.spectra = 7,
                window.size = 15) %>% # TODO write trycatch with different window sizes?
  mutate(outlier = ifelse(.data$h.distances > chisq95, T, F)) %>% 
  dplyr::select(id:observationUnitId, outlier, starts_with("X"), -h.distances) 

#### Generate CSV with outlier metadata ####
  if(sum(spectra.tagged$outlier > 0)){
    outlier.df <- spectra.tagged %>% dplyr::filter(outlier) %>%
            dplyr::select(-starts_with("X")) %>% distinct()
    write.csv(outlier.df, file = paste0(temp.filepath, "outliers.csv"))
  } else{
    cat("No outliers detected.\n") # TODO what is the best way to print this message to webpage?
  }

#### Output raw JSON with added outlier tags ####
spectra.tagged %>% 
  nest(nirs_metadata = id:outlier, nirs_spectra = starts_with("X")) %>% 
  jsonlite::toJSON() %>% 
  jsonlite::write_json(x = ., path = "raw_spectra_tagged.json") 

#### Aggregate on observationUnitName basis ####
agg.function <- function(x) suppressWarnings(mean(as.numeric(as.character(x)), na.rm= T))
agg.spectra <- spectra.tagged %>% 
  dplyr::filter(!outlier) %>% 
  aggregate(by = c("observationUnitId"), FUN = agg.function)

#### Output filtered and aggregated JSON ####
agg.spectra %>% 
  nest(nirs_metadata = id:outlier, nirs_spectra = starts_with("X")) %>% 
  jsonlite::toJSON() %>%
  jsonlite::write_json(x = ., path = "spectra_filtered_aggregated.json") 
