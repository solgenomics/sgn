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
# 2. Output filepath for aggregated spectra CSV
# 3. Output filepath for raw spectra with outliers tagged (CSV)
# 4. Output filepath for .png plot of spectra
# 5. Output filepath for csv of outliers to display to user along with plot

args <- commandArgs(trailingOnly = TRUE)

raw.spectra <- jsonlite::fromJSON(txt = args[1], flatten = T) %>%
  type_convert(cols(.default = col_double(), observationUnitId = col_character(),
  device_type = col_character())) %>%
  dplyr::select(observationUnitId, device_type, starts_with("nirs_spectra"))

wls <- colnames(raw.spectra) %>%
  str_subset("nirs_spectra.") %>%
  str_remove("nirs_spectra.") %>%
  readr::parse_number() %>%
  sort()

raw.spectra <- raw.spectra %>%
    dplyr::select(observationUnitId, device_type, paste0("nirs_spectra.X", wls))

#### Generate plot and identify outliers ####
spec.plot <- raw.spectra %>%
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "")) %>%
  rownames_to_column(var = "unique.id") %>%
  dplyr::select(-device_type) %>%
  plot_spectra(wls, num.col.before.spectra = 3, window.size = 100)

#### Output plot ####
ggsave(plot = spec.plot, filename = args[4], units = "in", height = 7, width = 10)

#### Identify outliers ####
chisq95 <- qchisq(.95, df = length(wls))
spectra.tagged <- raw.spectra %>%
  drop_na(observationUnitId, starts_with("nirs_spectra")) %>% # allows for case that no device type is present
  filter_spectra(., filter = F, return.distances = T,
                num.col.before.spectra = 2, # observationUnitId, device_type
                window.size = 100) %>% # TODO write trycatch with different window sizes?
  mutate(outlier = ifelse(.data$h.distances > chisq95, T, F)) %>%
  dplyr::select(observationUnitId, device_type, outlier, starts_with("nirs_spectra."))

#### Generate CSV with outlier metadata ####
  if(sum(spectra.tagged$outlier > 0)){
    outlier.df <- spectra.tagged %>%
            dplyr::filter(outlier) %>%
            dplyr::select(observationUnitId, device_type, outlier) %>%
            distinct()
    write.csv(outlier.df, file = args[5])
  } else{
    cat("No outliers detected.\n") # controller will recognize that there is no file and display message for user
  }

#### Output raw JSON with added outlier tags ####
spectra.tagged %>%
  mutate(id = NA,
    sample_id = NA,
    sampling_date = NA,
    device_id = NA,
    comments = NA) %>%
  rename(sample_name = observationUnitId) %>%
  dplyr::select(sample_name, starts_with("nirs_spectra")) %>%
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "")) %>%
  write.csv(x = ., file = args[3])

#### Aggregate on observationUnitName basis ####
agg.function <- function(x) suppressWarnings(mean(as.numeric(as.character(x)), na.rm= T))
agg.spectra <- spectra.tagged %>%
  dplyr::filter(!outlier) %>%
  dplyr::select(-outlier)

agg.spectra <- agg.spectra %>%
  aggregate(by = list(agg.spectra$observationUnitId, agg.spectra$device_type), FUN = agg.function)

#### Output filtered and aggregated JSON ####
agg.spectra %>%
  mutate(id = NA,
    sample_id = NA,
    sampling_date = NA,
    device_id = NA,
    comments = NA) %>%
  rename(sample_name = Group.1) %>%
  rename(device_type_rename = Group.2) %>%
  dplyr::select(sample_name, starts_with("nirs_spectra")) %>%
  rename_at(vars(starts_with("nirs_spectra")), ~str_replace(., "nirs_spectra.", "")) %>%
  write.csv(x=., file = args[2], row.names=FALSE)
