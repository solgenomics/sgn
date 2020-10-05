# Visualize spectra
# Jenna Hershberger
# jmh579@cornell.edu
# 10/02/2020

library(tidyverse)
library(waves)
library(jsonlite)

#### Read in raw JSON ####
# args:
# 1. Input JSON filepath
# 2. Output filepath for .png plot of spectra

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
  PlotSpectra(wavelengths = wls, num.col.before.spectra = 3, window.size = 100)

#### Output plot ####
ggsave(plot = spec.plot, filename = args[2], units = "in", height = 7, width = 10)
