 #SNOPSIS

 #prepares trait phenotype data for histogram plotting


 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(phenoAnalysis)


allArgs     <- commandArgs()

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                   what = "character")

allTraitsPhenoFile <- grep("phenotype_data", inputFiles, value = TRUE)
message('pheno file: ', allTraitsPhenoFile)

traitsFile <- grep("traits", inputFiles, value = TRUE)
message('traits file: ', traitsFile)
traits  <- scan(traitsFile,  what = "character")
trait  <- strsplit(traits, "\t")
message("trait: ", trait)

traitPhenoFile <- grep("phenotype_data", outputFiles, value = TRUE)
message('pheno file: ', traitPhenoFile)


if (is.null(grep("phenotype_data", allTraitsPhenoFile))) {
  stop("Phenotype dataset missing.")
}

if (is.null(grep("phenotype_trait", traitPhenoFile))) {
  stop("Output file is missing.")
}

if (is.null(trait)) {
  stop("trait name is missing.")
}

allTraitsPhenoData <- read.table(allTraitsPhenoFile,
                                 header = TRUE,
                                 row.names = NULL,
                                 sep = "\t",
                                 na.strings = c("NA", " ", "--", "-", ".", ".."),
                                 )

allTraitsPhenoData <- data.frame(fread(allTraitsPhenoFile,
                                       na.strings = c("NA", "", "--", "-", ".")
                                       ))

traitPhenoData <- getAdjMeans(allTraitsPhenoData,
                               traitName=trait,
                               calcAverages=TRUE)

write.table(traitPhenoData,
            file = traitPhenoFile,
            sep = "\t",
            quote = FALSE,
            )

q(save = "no", runLast = FALSE)
