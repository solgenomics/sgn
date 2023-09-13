 #SNOPSIS

 #runs phenotypic correlation analysis.
 #Correlation coeffiecients are stored in tabular and json formats

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(ltm)
#library(rjson)
library(jsonlite)
library(data.table)
library(phenoAnalysis)
library(dplyr)
#library(rbenchmark)
library(methods)

allArgs <- commandArgs()


outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                    what = "character")

message('inputFiles: ', inputFiles)

refererQtl <- grep("qtl", inputFiles, value=TRUE)

phenoDataFile      <- grep("\\/phenotype_data", inputFiles, value=TRUE)
formattedPhenoFile <- grep("formatted_phenotype_data", inputFiles, fixed = FALSE, value = TRUE)
metaFile       <-  grep("metadata", inputFiles, value=TRUE)
message('metaFiles: ', metaFile)
correCoefficientsFile     <- grep("pheno_corr_table", outputFiles, value=TRUE)
correCoefficientsJsonFile <- grep("pheno_corr_json", outputFiles, value=TRUE)

formattedPhenoData <- c()
phenoData          <- c()


if ( length(refererQtl) != 0 ) {
   phenoDataFile      <- grep("\\/phenodata", inputFiles, value=TRUE)

   phenoData <- data.frame(fread(phenoDataFile,
				header=TRUE,
        sep=",",
        na.strings=c("NA", "-", " ", ".", "..")))
}
# else {
#
#     phenoData <- data.frame(fread(phenoDataFile,
#                                      header = TRUE,
#                                      sep="\t",
#                                      na.strings = c("NA", "", "--", "-", ".", "..")
#                                    ))
# }

metaData <- scan(metaFile, what="character")

allTraitNames <- c()
nonTraitNames <- c()
naTraitNames  <- c()

if (length(refererQtl) != 0) {

  allNames      <- names(phenoData)
  nonTraitNames <- c("ID")
  allTraitNames <- allNames[! allNames %in% nonTraitNames]

}

correPhenoData <- c(0)

if (length(refererQtl) == 0  ) {
    averagedPhenoData <- cleanAveragePhenotypes(inputFiles, metaDataFile = metaFile)
    allNames <- names(averagedPhenoData)
    nonTraitNames <- metaData
    allTraitNames <- allNames[! allNames %in% nonTraitNames]

  rownames(averagedPhenoData) <- NULL
  correPhenoData <- averagedPhenoData
} else {
  message("qtl stuff")
  correPhenoData <- phenoData %>%
                        group_by(ID) %>%
                        summarise_if(is.numeric, mean, na.rm=TRUE) %>%
                        select(-ID) %>%
                        round(., 2) %>%
                        data.frame

}

coefpvalues <- rcor.test(correPhenoData,
                         method="pearson",
                         use="pairwise"
                         )

coefficients <- coefpvalues$cor.mat
#remove rows and columns that are all "NA"
coefficients <- data.frame(coefficients)
 if (any(is.na(coefficients))) {
  coefficients <- coefficients[ , colSums(is.na(coefficients)) < nrow(coefficients)] 
}

pvalues[upper.tri(pvalues)]           <- NA
coefficients[upper.tri(coefficients)] <- NA
coefficients <- data.frame(coefficients)

pvalues <- coefpvalues$cor.mat
pvalues[lower.tri(pvalues)] <- coefpvalues$p.values[, 3]
pvalues <- round(pvalues, 3)
pvalues[upper.tri(pvalues)] <- NA
pvalues <- data.frame(pvalues)

allcordata   <- coefpvalues$cor.mat
allcordata[upper.tri(allcordata)] <- coefpvalues$p.values[, 3]
diag(allcordata) <- 1
allcordata   <- round(allcordata, 3)

traits <- colnames(coefficients)

correlationList <- list(
                     labels = traits,
                    values  = coefficients,
                    pvalues = pvalues
                   )

correlationJson <- jsonlite::toJSON(correlationList)

write.table(allcordata,
       file = correCoefficientsFile,
       sep  = "\t",
       row.names = TRUE,
       quote = FALSE
       )

write(correlationJson,
       file = correCoefficientsJsonFile)

message("Done running correlation.")
q(save = "no", runLast = FALSE)
