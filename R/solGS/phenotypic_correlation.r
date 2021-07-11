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
correCoefficientsFile     <- grep("corre_coefficients_table", outputFiles, value=TRUE)
correCoefficientsJsonFile <- grep("corre_coefficients_json", outputFiles, value=TRUE)

formattedPhenoData <- c()
phenoData          <- c()


if ( length(refererQtl) != 0 ) {
   phenoDataFile      <- grep("\\/phenodata", inputFiles, value=TRUE)

   phenoData <- data.frame(fread(phenoDataFile,
				header=TRUE,
                                   sep=",",
                                   na.strings=c("NA", "-", " ", ".", "..")
                                   ))
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

if (!is.null(correPhenoData) && length(refererQtl) == 0) {

    for (i in allTraitNames) {
      if (class(correPhenoData[, i]) != 'numeric') {
          correPhenoData[, i] <- as.numeric(as.character(correPhenoData[, i]))
      }

      if (all(is.nan(correPhenoData[, i]))) {
          correPhenoData[, i] <- sapply(correPhenoData[, i], function(x) ifelse(is.numeric(x), x, NA))
      }

      if (sum(is.na(correPhenoData[,i])) > (0.5 * nrow(correPhenoData))) {
          correPhenoData$i <- NULL
          naTraitNames <- c(naTraitNames, i)
          message('dropped trait ', i, ' no of missing values: ', sum(is.na(correPhenoData[,i])))
      }
  }
}

filteredTraits <- allTraitNames[!allTraitNames %in% naTraitNames]

coefpvalues <- rcor.test(correPhenoData,
                         method="pearson",
                         use="pairwise"
                         )

coefficients <- coefpvalues$cor.mat
allcordata   <- coefpvalues$cor.mat

allcordata[lower.tri(allcordata)] <- coefpvalues$p.values[, 3]
diag(allcordata) <- 1.00

pvalues <- as.matrix(allcordata)
pvalues <- round(pvalues, 2)

coefficients <- round(coefficients, 3)
allcordata   <- round(allcordata, 3)

#remove rows and columns that are all "NA"
if (apply(coefficients, 1, function(x)any(is.na(x))) ||
    apply(coefficients, 2, function(x)any(is.na(x))))
  {

    coefficients<-coefficients[-which(apply(coefficients, 1, function(x)all(is.na(x)))),
                               -which(apply(coefficients, 2, function(x)all(is.na(x))))]
  }


pvalues[upper.tri(pvalues)]           <- NA
coefficients[upper.tri(coefficients)] <- NA
coefficients <- data.frame(coefficients)

coefficients2json <- coefficients
names(coefficients2json) <- NULL

traits <- colnames(coefficients)

correlationList <- list(
                     labels = traits,
                     values  = coefficients
                   )

correlationJson <- jsonlite::toJSON(correlationList)

write.table(coefficients,
       file = correCoefficientsFile,
       sep  = "\t",
       row.names = TRUE,
       quote = FALSE
       )

write(correlationJson,
       file = correCoefficientsJsonFile)

## if (file.info(formattedPhenoFile)$size == 0 && !is.null(formattedPhenoData) ) {
##   fwrite(formattedPhenoData,
##          file      = formattedPhenoFile,
##          sep       = "\t",
##          row.names = TRUE,
##          quote     = FALSE,
##          )
## }


q(save = "no", runLast = FALSE)
