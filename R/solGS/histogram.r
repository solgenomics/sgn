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
trait  <- strsplit(traits, "\t")
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

traitRawPhenoData <- extractPhenotypes(inputFiles, metadata_file)

allTraitsPhenoData <- read.table(allTraitsPhenoFile,
                                 header = TRUE,
                                 row.names = NULL,
                                 sep = "\t",
                                 na.strings = c("NA", " ", "--", "-", ".", ".."),
                                 )

allTraitsPhenoData <- data.frame(fread(allTraitsPhenoFile,
                                       na.strings = c("NA", "", "--", "-", ".")
                                       ))

traitPhenoMeansData <- getAdjMeans(allTraitsPhenoData,
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
