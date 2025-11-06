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
library(stringr)
library(phenoAnalysis)
library(ggplot2)

allArgs <- commandArgs()

outputFile  <- grep("output_files", allArgs, value = TRUE)
outputFiles <- scan(outputFile, what = "character")

inputFile  <- grep("input_files", allArgs, value = TRUE)
inputFiles <- scan(inputFile, what = "character")

scoresFile       <- grep("pca_scores", outputFiles, value = TRUE)
screeDataFile    <- grep("pca_scree_data", outputFiles, value = TRUE)
screeFile        <- grep("pca_scree_plot", outputFiles, value = TRUE)
loadingsFile     <- grep("pca_loadings", outputFiles, value = TRUE)
varianceFile     <- grep("pca_variance", outputFiles, value = TRUE)
combinedDataFile <- grep("combined_pca_data_file", outputFiles, value = TRUE)
reportFile       <- grep("report", outputFiles, value = TRUE)

if (is.null(inputFiles)) {
  stop("Input files are missing.")
  q("no", 1, FALSE)
}

if (is.null(scoresFile)) {
  stop("Scores output file is missing.")
  q("no", 1, FALSE)
}

if (is.null(loadingsFile)) {
  stop("Laodings file is missing.")
  q("no", 1, FALSE)
}

genoData         <- c()
genoMetaData     <- c()
filteredGenoFile <- c()
phenoData        <- c()
phenoDataNotes   <- c()

set.seed(235)

pcaDataFile <- grepl("genotype", ignore.case=TRUE, inputFiles)
dataType <- ifelse(isTRUE(pcaDataFile[1]), 'genotype', 'phenotype')

if (dataType == 'genotype') {
    if (length(inputFiles) > 1) {
        genoData <- genoDataFilter::combineGenoData(inputFiles)
        genoMetaData   <- genoData$trial
        genoData$trial <- NULL

    } else {
        genoDataFile <- grep("genotype_data", inputFiles,  value = TRUE)
        genoData     <- fread(genoDataFile,
                              header = TRUE,
                              na.strings = c("NA", " ", "--", "-", "."))

        if (is.null(genoData)) {
            filteredGenoFile <- grep("filtered_genotype_data_",
                                 genoDataFile,
                                 value = TRUE)

            if (filteredGenoFile) {
                genoData <- fread(filteredGenoFile,  header = TRUE)
            }
        }

        genoData <- unique(genoData, by='V1')
        genoData <- data.frame(genoData)
        genoData <- column_to_rownames(genoData, 'V1')

    }
} else if (dataType == 'phenotype') {

    metaDataFile <- grep("meta", inputFiles,  value = TRUE)
    phenoFiles <- grep("phenotype_data", inputFiles,  value = TRUE)

    if (length(phenoFiles) > 1 ) {

        phenoData <- phenoAnalysis::combinePhenoData(phenoFiles, metaDataFile = metaDataFile)
        phenoData <- phenoAnalysis::summarizeTraits(phenoData, groupBy=c('studyDbId', 'germplasmName'))

        if (all(is.na(phenoData$locationName))) {
            phenoData$locationName <- 'location'
        }

        phenoData <- na.omit(phenoData)
        genoMetaData <- phenoData$studyDbId

        phenoData <- phenoData %>% mutate(germplasmName = paste0(germplasmName, '_trial_', studyDbId))
        dropCols = c('replicate', 'blockNumber', 'locationName', 'studyDbId', 'studyYear')
        phenoData <- phenoData %>% select(-dropCols)
        rownames(phenoData) <- NULL
        phenoData <- column_to_rownames(phenoData, var="germplasmName")
    } else {
        phenoDataFile <- grep("phenotype_data", inputFiles,  value = TRUE)

        phenoData <- phenoAnalysis::cleanAveragePhenotypes(inputFiles, metaDataFile)
        phenoData <- na.omit(phenoData)
    }

    traits <- colnames(phenoData)
    phenoDataNotes <- paste0("\nThis PCA is done on phenotype data. \n")
    phenoDataNotes <- append(phenoDataNotes, 
    paste0("\n\nTraits before removing zero variance traits: ", 
    paste(traits, collapse = ", ")))
    
    phenoData <- phenoData[, apply(phenoData, 2, var) != 0 ]
    traits <- colnames(phenoData)
    phenoDataNotes <- append(phenoDataNotes, 
    paste0("\n\nTraits After removing zero variance traits: ", 
    paste(traits, collapse = ", ")))
    phenoDataNotes <- append(phenoDataNotes, 
    paste0("\nTrait data is centered and scaled before PCA.\n"))
    phenoData <- scale(phenoData, center=TRUE, scale=TRUE)
    phenoData <- round(phenoData, 3)
}


if (is.null(genoData) && is.null(phenoData)) {
  stop("There is no data to run PCA.")
  q("no", 1, FALSE)
}

notesHeader <- paste0("PCA Analysis Report")
notesHeader <- append(notesHeader, paste0("\nDate: ",
           format(Sys.time(), "%d %b %Y %H:%M"),
           "\n\n\n"))


# notesHeader<- format(notesHeader, width = 80, justify = "c")

genoProcessingNotes <- c()
genoDataMissing <- c()
if (dataType == 'genotype') {
    genoData <- genoDataFilter::convertToNumeric(genoData)
    filterGenoDataResult <- genoDataFilter::filterGenoData(genoData, maf=0.01, logReturn = TRUE)
    genoProcessingNotes <- paste0("\nPreprocessing genotype data before PCA\n")
    genoProcessingNotes <- append(genoProcessingNotes, filterGenoDataResult$log)
    genoData <- filterGenoDataResult$data
    genoData <- genoDataFilter::roundAlleleDosage(genoData)

    if (sum(is.na(genoData)) > 0) {
        genoDataMissing <- c('yes')
        # genoData <- na.roughfix(genoData)
    }
}

pcaData <- c()
if (!is.null(genoData)) {
    pcaData <- genoData
    genoData <- NULL
} else if(!is.null(phenoData)) {
    pcaData <- phenoData
    phenoData <- NULL
}

message("No. of missing values, ", sum(is.na(pcaData)) )
if (sum(is.na(pcaData)) > 0) {
    pcaData <- na.roughfix(pcaData)
}

pcsCnt <- ifelse(ncol(pcaData) < 10, ncol(pcaData), 10)
pcaNotes <- paste0("\n\nPCA is done using the prcomp function in R.\n")
pca    <- prcomp(pcaData, retx=TRUE)
pca    <- summary(pca)

scores   <- data.frame(pca$x)
scores   <- scores[, 1:pcsCnt]
scores   <- round(scores, 3)

if (!is.null(genoMetaData)) {
    scores$trial <- genoMetaData
    scores <- scores %>% data.frame
    scores <- scores %>% select(trial, everything()) %>% data.frame
} else {
  scores$trial <- 1000
  scores <- scores %>% select(trial, everything()) %>% data.frame
}

scores   <- scores[order(row.names(scores)), ]

varianceAllPCs <- data.frame(pca$importance)
varianceSelectPCs <- varianceAllPCs[2, 1:pcsCnt]
varianceSelectPCs <- round(varianceSelectPCs, 4) * 100
varianceSelectPCs <- data.frame(t(varianceSelectPCs))

colnames(varianceSelectPCs) <- 'Variances'

loadings <- data.frame(pca$rotation)
loadings <- loadings[, 1:pcsCnt]
loadings <- round(loadings, 3)

varianceAllPCs <- varianceAllPCs[2, ] %>%
    t() %>%
    round(3) * 100

colnames(varianceAllPCs) <- 'Variances'
varianceAllPCs <- data.frame(varianceAllPCs)

varianceAllPCs <- rownames_to_column(varianceAllPCs, 'PCs')
varianceAllPCs <- data.frame(varianceAllPCs)

screePlot <- ggplot(varianceAllPCs, aes(x = reorder(PCs, -Variances), y = Variances, group = 1)) +
    geom_line(color="red") +
    geom_point() +
    xlab('PCs') +
    ylab('Explained variance (%)') +
    theme(axis.text.x = element_text(angle = 90))

png(screeFile)
screePlot
dev.off()


fwriteOutput <- function (data, dataFile) {
    fwrite(data,
    file      = dataFile,
    sep       = "\t",
    row.names = TRUE,
    quote     = FALSE,
    )

}

fwriteOutput(scores, scoresFile)
fwriteOutput(varianceAllPCs, screeDataFile)
fwriteOutput(loadings, loadingsFile)
fwriteOutput(varianceSelectPCs, varianceFile)

if (!is.null(genoData)) {
    if (length(inputFiles) > 1) {
        fwriteOutput(genoData, combinedDataFile)
    }
}

cat(notesHeader, 
    genoProcessingNotes, 
    phenoDataNotes,
    pcaNotes,
    fill=TRUE, 
    file = reportFile,
    append = FALSE
)

q(save = "no", runLast = FALSE)
