# Analytical replicate is the recorded design tag, never the field counter.
design_source <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) design_source <- frame$ofile
if (is.null(design_source)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    design_source <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) design_source <- invocation[file_index[1] + 1L]
  }
}
if (is.null(design_source) || is.na(design_source) || !nzchar(design_source)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(design_source)), "../design_replication.R"), local = TRUE)

 #SNOPSIS

 #prepares trait phenotype data for histogram plotting


 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(phenoAnalysis)
library(dplyr)

allArgs     <- commandArgs()

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                   what = "character")

allTraitsPhenoFile <- grep("phenotype_data", inputFiles, value = TRUE)
message('pheno file: ', allTraitsPhenoFile)

metaDataFile <- grep("metadata_file", inputFiles, value = TRUE)
message('metadata  file: ', metaDataFile)

traitsFile <- grep("traits", inputFiles, value = TRUE)
message('traits file: ', traitsFile)
traits  <- scan(traitsFile,  what = "character")
trait  <- unlist(strsplit(traits, "\t"), use.names = FALSE)
if (length(trait) != 1L) stop("Select one trait for the histogram.")
message("trait: ", trait)

traitPhenoMeansFile <- grep("phenotype_data", outputFiles, value = TRUE)
message('pheno file: ', traitPhenoMeansFile)

traitRawPhenoFile <- grep("trait_raw_phenodata", outputFiles, value = TRUE)
message('raw pheno file: ', traitRawPhenoFile)


if (is.null(grep("phenotype_data", allTraitsPhenoFile))) {
  stop("Phenotype dataset missing.")
}

if (is.null(grep("phenotype_trait", traitPhenoMeansFile))) {
  stop("Output file is missing.")
}

if (is.null(trait)) {
  stop("trait name is missing.")
}

allTraitsPhenoData <- read_analysis_phenotypes(allTraitsPhenoFile)

traitPhenoMeansData <- analysis_adjusted_means(allTraitsPhenoData,
                               traitName=trait,
                               calcAverages=TRUE)

keepMetaCols <- c('observationUnitName', 'germplasmName', 'studyDbId', 'locationName',
                                              'studyYear', 'replicate', 'blockNumber')

traitRawPhenoData <- allTraitsPhenoData %>%
                                    select(c(keepMetaCols, trait))


write.table(traitPhenoMeansData,
            file = traitPhenoMeansFile,
            sep = "\t",
            quote = FALSE,
            )

write.table(traitRawPhenoData,
                file = traitRawPhenoFile,
                sep = "\t",
                na = 'NA',
                quote = FALSE,
                )

q(save = "no", runLast = FALSE)
