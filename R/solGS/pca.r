 #SNOPSIS

 #runs population structure analysis using PCA from SNPRelate, a bioconductor R package

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(randomForest)
library(data.table)
library(genoDataFilter)
library(tibble)
library(dplyr)

allArgs <- commandArgs()

outputFile  <- grep("output_files", allArgs, value = TRUE)
outputFiles <- scan(outputFile, what = "character")

inputFile  <- grep("input_files", allArgs, value = TRUE)
inputFiles <- scan(inputFile, what = "character")

scoresFile       <- grep("pca_scores", outputFiles, value = TRUE)
loadingsFile     <- grep("pca_loadings", outputFiles, value = TRUE)
varianceFile     <- grep("pca_variance", outputFiles, value = TRUE)
combinedDataFile <- grep("combined_pca_data_file", outputFiles, value = TRUE)

message("pca scores file: ", scoresFile)
message("pca loadings file: ", loadingsFile)
message("pca variance file: ", varianceFile)
message("combined data file: ", combinedDataFile)


if (is.null(scoresFile))
{
  stop("Scores output file is missing.")
  q("no", 1, FALSE) 
}

if (is.null(loadingsFile))
{
  stop("Laodings file is missing.")
  q("no", 1, FALSE)
}

genoData <- c()
genoMetaData <- c()

filteredGenoFile <- c()

if (length(inputFiles) > 1 ) {   
    allGenoFiles <- inputFiles
    genoData <- combineGenoData(allGenoFiles)
    
    genoMetaData   <- genoData$trial
    genoData$trial <- NULL
 
} else {
    genoDataFile <- grep("genotype_data", inputFiles,  value = TRUE)
    genoData     <- fread(genoDataFile, na.strings = c("NA", " ", "--", "-", "."))
    genoData     <- unique(genoData, by='V1')
 
   filteredGenoFile <- grep("filtered_genotype_data_",  genoDataFile, value = TRUE)

    if (!is.null(genoData)) { 

        genoData <- data.frame(genoData)
        genoData <- column_to_rownames(genoData, 'V1')
    
    } else {
        genoData <- fread(filteredGenoFile)
    }
}

if (is.null(genoData)) {
  stop("There is no genotype dataset.")
  q("no", 1, FALSE)
}


genoDataMissing <- c()
if (is.null(filteredGenoFile) == TRUE) {
    ##genoDataFilter::filterGenoData
    
    genoData <- filterGenoData(genoData, maf=0.01)
    genoData <- column_to_rownames(genoData, 'rn')

    message("No. of geno missing values, ", sum(is.na(genoData)) )
    if (sum(is.na(genoData)) > 0) {
        genoDataMissing <- c('yes')
        genoData <- na.roughfix(genoData)
    }
}

genoData <- data.frame(genoData)
## nCores <- detectCores()
## message('no cores: ', nCores)
## if (nCores > 1) {
##   nCores <- (nCores %/% 2)
## } else {
##   nCores <- 1
## }

pcsCnt <- 10
pca    <- prcomp(genoData, retx=TRUE)
pca    <- summary(pca)

scores   <- data.frame(pca$x)
scores   <- scores[, 1:pcsCnt]
scores   <- round(scores, 3)

if (!is.null(genoMetaData)) {
   scores$trial <- genoMetaData
   scores       <- scores %>% select(trial, everything()) %>% data.frame
} else {
  scores$trial <- 1000
  scores <- scores %>% select(trial, everything()) %>% data.frame
}

scores   <- scores[order(row.names(scores)), ]

variances <- data.frame(pca$importance)
variances <- variances[2, 1:pcsCnt]
variances <- round(variances, 4) * 100
variances <- data.frame(t(variances))

colnames(variances) <- 'variances'

loadings <- data.frame(pca$rotation)
loadings <- loadings[, 1:pcsCnt]
loadings <- round(loadings, 3)

fwrite(scores,
       file      = scoresFile,
       sep       = "\t",
       row.names = TRUE,
       quote     = FALSE,
       )

fwrite(loadings,
       file      = loadingsFile,
       sep       = "\t",
       row.names = TRUE,
       quote     = FALSE,
       )

fwrite(variances,
       file      = varianceFile,
       sep       = "\t",
       row.names = TRUE,
       quote     = FALSE,
       )


if (length(inputFiles) > 1) {
    fwrite(genoData,
       file      = combinedDataFile,
       sep       = "\t",
       row.names = TRUE,
       quote     = FALSE,
       )

}

## if (!is.null(genoDataMissing)) {
## fwrite(genoData,
##        file      = genoDataFile,
##        sep       = "\t",
##        row.names = TRUE,
##        quote     = FALSE,
##        )

## }


q(save = "no", runLast = FALSE)
