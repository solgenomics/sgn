# Filter on upload and aggregate
# Jenna Hershberger
# jmh579@cornell.edu
# 06/29/2020

library(tidyverse)
library(waves)
library(jsonlite)

#### Read in raw JSON ####
# args:
# 1. Input JSON filepath
# 2. Output filepath for aggregated JSON
# 3. Output filepath for raw JSON with outliers tagged
# 4. Output filepath for .png plot of spectra
# 5. Output filepath for csv of outliers to display to user along with plot

args <- commandArgs(trailingOnly = TRUE)

raw.spectra <- jsonlite::fromJSON(txt = args[1], flatten = T) %>%
  type_convert(cols(.default = col_double(), observationUnitId = col_character(), device_type = col_character())) %>%
  dplyr::select(observationUnitId, device_type, starts_with("nirs_spectra") )

wls <- colnames(raw.spectra) %>%
  str_subset("nirs_spectra.") %>%
  str_remove("nirs_spectra.") %>%
  readr::parse_number()

#### Generate plot and identify outliers ####
print(raw.spectra[1:20,1:20])

spec.plot <- raw.spectra %>%
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "")) %>%
  rownames_to_column(var = "unique.id") %>%
  PlotSpectra(wavelengths = wls, num.col.before.spectra = 3, window.size = 15)

#### Output plot ####
ggsave(plot = spec.plot, filename = args[4], units = "in", height = 7, width = 10)

#### Identify outliers ####
chisq95 <- qchisq(.95, df = length(wls))
spectra.tagged <- raw.spectra %>%
  na.omit() %>%
  FilterSpectra(., filter = F, return.distances = T,
                num.col.before.spectra = 2,
                window.size = 15) %>% # TODO write trycatch with different window sizes?
  mutate(outlier = ifelse(.data$h.distances > chisq95, T, F)) %>%
  dplyr::select(id:observationUnitId, outlier, starts_with("nirs_spectra"), -h.distances)

#### Generate CSV with outlier metadata ####
  if(sum(spectra.tagged$outlier > 0)){
    outlier.df <- spectra.tagged %>% dplyr::filter(outlier) %>%
            dplyr::select(-starts_with("nirs_spectra")) %>% distinct()
    write.csv(outlier.df, file = args[5])
  } else{
    cat("No outliers detected.\n") # TODO what is the best way to print this message to webpage?
  }

#### Output raw JSON with added outlier tags ####
spectra.tagged %>%
  nest(nirs_metadata = id:outlier, nirs_spectra = starts_with("nirs_spectra")) %>%
  jsonlite::toJSON() %>%
  jsonlite::write_json(x = ., path = args[3])

#### Aggregate on observationUnitName basis ####
agg.function <- function(x) suppressWarnings(mean(as.numeric(as.character(x)), na.rm= T))
agg.spectra <- spectra.tagged %>%
  dplyr::filter(!outlier) %>%
  aggregate(by = c("observationUnitId"), FUN = agg.function)

#### Output filtered and aggregated JSON ####
agg.spectra %>%
  nest(nirs_metadata = id:outlier, nirs_spectra = starts_with("X")) %>%
  jsonlite::toJSON() %>%
  jsonlite::write_json(x = ., path = args[2])
