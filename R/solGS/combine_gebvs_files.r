#combines gebvs of traits of a population
# Isaak Y Tecle

library(phenoAnalysis)

options(echo = FALSE)

allArgs    <- commandArgs()
inFile     <- grep("gebv_files", allArgs, value = TRUE)
outputFile <- grep("combined_gebvs", allArgs, value = TRUE)
inputFiles <- scan(inFile, what = "character")

combinedGebvs <- mergeVariables(inputFiles)

if (length(outputFile) != 0 ) {
  write.table(combinedGebvs,
              file = outputFile,
              sep = "\t",
              quote = FALSE,
              col.names = NA,
              )
}
 
q(save = "no", runLast = FALSE)
