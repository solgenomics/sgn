 #SNOPSIS

 #runs phenotypic correlation analysis.
 #Correlation coeffiecients are stored in tabular and json formats 

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(ltm)
library(rjson)
library(data.table)
#library(phenoAnalysis)
library(dplyr)
#library(rbenchmark)
library(methods)

allArgs <- commandArgs()


outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                    what = "character")


refererQtl <- grep("qtl", inputFiles, value=TRUE)

phenoDataFile      <- grep("\\/phenotype_data", inputFiles, value=TRUE)
formattedPhenoFile <- grep("formatted_phenotype_data", inputFiles, fixed = FALSE, value = TRUE)

correCoefficientsFile     <- grep("corre_coefficients_table", outputFiles, value=TRUE)
correCoefficientsJsonFile <- grep("corre_coefficients_json", outputFiles, value=TRUE)

formattedPhenoData <- c()
phenoData          <- c()

if ( length(refererQtl) != 0 ) {
   phenoDataFile      <- grep("\\/phenodata", inputFiles, value=TRUE)    

   phenoData <- read.table(phenoDataFile,
				header=TRUE,
                                   sep=",",
                                   na.strings=c("NA", "-", " ", ".", "..")
                                   )
} else {

  phenoData <- as.data.frame(fread(phenoDataFile,
                                   na.strings = c("NA", " ", "--", "-", ".", "..")
                                   ))
} 

allTraitNames <- c()
nonTraitNames <- c()
naTraitNames  <- c()

if (length(refererQtl) != 0) {

  allNames      <- names(phenoData)
  nonTraitNames <- c("ID")
  allTraitNames <- allNames[! allNames %in% nonTraitNames]

} else {
  allNames <- names(phenoData)

  nonTraitNames <- c('studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName')
  nonTraitNames <- c(nonTraitNames, 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel')
  nonTraitNames <- c(nonTraitNames, 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber')
  
  allTraitNames <- allNames[! allNames %in% nonTraitNames]
}

if (!is.null(phenoData) && length(refererQtl) == 0) {
  
    for (i in allTraitNames) {
      if (class(phenoData[, i]) != 'numeric') {
          phenoData[, i] <- as.numeric(as.character(phenoData[, i]))
      }

      if (all(is.nan(phenoData[, i]))) {
          phenoData[, i] <- sapply(phenoData[, i], function(x) ifelse(is.numeric(x), x, NA))        
      }

      if (sum(is.na(phenoData[,i])) > (0.5 * nrow(phenoData))) { 
          phenoData$i <- NULL
          naTraitNames <- c(naTraitNames, i)
          message('dropped trait ', i, ' no of missing values: ', sum(is.na(phenoData[,i])))
      }
  }
}

filteredTraits <- allTraitNames[!allTraitNames %in% naTraitNames]

###############################
if (length(refererQtl) == 0  ) {
 
  formattedPhenoData <- phenoData %>%
                        select(germplasmName, allTraitNames) %>%
                        group_by(germplasmName) %>%
                        summarise_at(allTraitNames, mean, na.rm=TRUE) %>%
                        select(-germplasmName) %>%
                        round(., 2) %>%
                        data.frame

} else {
  message("qtl stuff")
  formattedPhenoData <- phenoData %>%
                        group_by(ID) %>%
                        summarise_if(is.numeric, mean, na.rm=TRUE) %>%
                        select(-ID) %>%
                        round(., 2) %>%
                        data.frame
                             
}
 
coefpvalues <- rcor.test(formattedPhenoData,
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

coefficients2json <- function(mat) {
  mat <- as.list(as.data.frame(t(mat)))
  names(mat) <- NULL
  toJSON(mat)
}

traits <- colnames(coefficients)

correlationList <- list(
                     "traits" = toJSON(traits),
                     "coefficients " =coefficients2json(coefficients)
                   )

correlationJson <- paste("{",paste("\"", names(correlationList), "\":", correlationList, collapse=","), "}")

correlationJson <- list(correlationJson)

fwrite(coefficients,
       file      = correCoefficientsFile,
       row.names = TRUE,
       sep       = "\t",
       quote     = FALSE,
       )

fwrite(correlationJson,
       file      = correCoefficientsJsonFile,
       col.names = FALSE,
       row.names = FALSE,
       qmethod   = "escape"
       )

## if (file.info(formattedPhenoFile)$size == 0 && !is.null(formattedPhenoData) ) {
##   fwrite(formattedPhenoData,
##          file      = formattedPhenoFile,
##          sep       = "\t",
##          row.names = TRUE,
##          quote     = FALSE,
##          )
## }


q(save = "no", runLast = FALSE)
