 #SNOPSIS

 #runs k-means cluster analysis

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(randomForest)
library(data.table)
library(genoDataFilter)
library(tibble)
library(dplyr)
library(ggfortify)
library(tibble)
library(stringi)
library(phenoAnalysis)
library(ape)
library(ggtree)

allArgs <- commandArgs()

outputFiles  <- grep("output_files", allArgs, value = TRUE)
outputFiles <- scan(outputFiles, what = "character")

inputFiles  <- grep("input_files", allArgs, value = TRUE)
inputFiles <- scan(inputFiles, what = "character")

resultFile <- grep("result", outputFiles, value = TRUE)
reportFile  <- grep("report", outputFiles, value = TRUE)
errorFile   <- grep("error", outputFiles, value = TRUE)

combinedDataFile <- grep("combined_cluster_data_file", outputFiles, value = TRUE)

plotFile <- grep("plot", outputFiles, value = TRUE)
optionsFile    <- grep("options", inputFiles,  value = TRUE)

clusterOptions <- read.table(optionsFile,
                             header = TRUE,
                             sep = "\t",
                             stringsAsFactors = FALSE,
                             na.strings = "")
print(clusterOptions)
clusterOptions <- column_to_rownames(clusterOptions, var = "Params")
# userKNumbers   <- as.numeric(clusterOptions["k_numbers", 1])
dataType       <- clusterOptions["data_type", 1]
selectionProp  <- as.numeric(clusterOptions["selection_proportion", 1])
predictedTraits <- clusterOptions["predicted_traits", 1]
predictedTraits <- unlist(strsplit(predictedTraits, ','))

if (is.null(resultFile)) {
  stop("Clustering output file is missing.")
  q("no", 1, FALSE)
}

clusterData <- c()
genoData    <- c()
genoFiles   <- c()
reportNotes <- c()
genoDataMissing <- c()

extractGenotype <- function(inputFiles) {

    genoFiles <- grep("genotype_data", inputFiles,  value = TRUE)

    genoMetaData <- c()
    filteredGenoFile <- c()

    if (length(genoFiles) > 1) {
        genoData <- combineGenoData(genoFiles)

        genoMetaData   <- genoData$trial
        genoData$trial <- NULL

    } else {
        genoFile <- genoFiles
        genoData <- fread(genoFile,
                          header = TRUE,
                          na.strings = c("NA", " ", "--", "-", "."))

        if (is.null(genoData)) {
            filteredGenoFile <- grep("filtered_genotype_data_",  genoFile, value = TRUE)
            genoData <- fread(filteredGenoFile, header = TRUE)
        }

        genoData <- unique(genoData, by = 'V1')
        genoData <- data.frame(genoData)
        genoData <- column_to_rownames(genoData, 'V1')
    }

    if (is.null(genoData)) {
        stop("There is no genotype dataset.")
        q("no", 1, FALSE)
    } else {

        ##genoDataFilter::filterGenoData
        genoData <- convertToNumeric(genoData)
        genoData <- filterGenoData(genoData, maf=0.01)
        genoData <- roundAlleleDosage(genoData)

        message("No. of geno missing values, ", sum(is.na(genoData)))
        if (sum(is.na(genoData)) > 0) {
            genoDataMissing <- c('yes')
            genoData <- na.roughfix(genoData)
        }

        genoData <- data.frame(genoData)
    }
}

set.seed(235)

clusterDataNotScaled <- c()

if (grepl('genotype', dataType, ignore.case = TRUE)) {
    clusterData <- extractGenotype(inputFiles)

    pca    <- prcomp(clusterData, retx = TRUE)
    pca    <- summary(pca)

    variances <- data.frame(pca$importance)

    varProp        <- variances[3, ]
    varProp        <- data.frame(t(varProp))
    names(varProp) <- c('cumVar')

    selectPcs <- varProp %>% filter(cumVar <= 0.9)
    pcsCnt    <- nrow(selectPcs)

    reportNotes <- paste0('Before clustering this dataset, principal component analysis (PCA) was done on it. ', "\n")
    reportNotes <- paste0(reportNotes, 'Based on the PCA, ', pcsCnt, ' PCs are used to cluster this dataset. ', "\n")
    reportNotes <- paste0(reportNotes, 'They explain 90% of the variance in the original dataset.', "\n")

    scores   <- data.frame(pca$x)
    scores   <- scores[, 1:pcsCnt]
    scores   <- round(scores, 3)

    variances <- variances[2, 1:pcsCnt]
    variances <- round(variances, 4) * 100
    variances <- data.frame(t(variances))

    clusterData <- scores
} else {

    if (grepl('gebv', dataType, ignore.case = TRUE)) {
        gebvsFile <- grep("combined_gebvs", inputFiles,  value = TRUE)
        gebvsData <- data.frame(fread(gebvsFile, header = TRUE))

        clusterNa   <- gebvsData %>% filter_all(any_vars(is.na(.)))
        clusterData <- column_to_rownames(gebvsData, 'V1')
    } else if (grepl('phenotype', dataType, ignore.case = TRUE)) {

        metaFile <- grep("meta", inputFiles,  value = TRUE)

        clusterData <- cleanAveragePhenotypes(inputFiles, metaDataFile = metaFile)

        if (!is.na(predictedTraits) & length(predictedTraits) > 1) {
            clusterData <- rownames_to_column(clusterData, var = 'germplasmName')
            clusterData <- clusterData %>% select(c(germplasmName, predictedTraits))
            clusterData <- column_to_rownames(clusterData, var = 'germplasmName')
        }
    }

    clusterDataNotScaled <- na.omit(clusterData)

    clusterData <- scale(clusterDataNotScaled, center=TRUE, scale=TRUE)
    reportNotes <- paste0(reportNotes, 'Note: Data was standardized before clustering.', "\n")
}

sIndexFile <- grep("selection_index", inputFiles, value = TRUE)
selectedIndexGenotypes <- c()

if (length(sIndexFile) != 0) {
    sIndexData <- data.frame(fread(sIndexFile, header = TRUE))
    selectionProp <- selectionProp * 0.01
    selectedIndexGenotypes <- sIndexData %>% top_frac(selectionProp)

    selectedIndexGenotypes <- column_to_rownames(selectedIndexGenotypes, var = 'V1')

    if (!is.null(selectedIndexGenotypes)) {
        clusterData <- rownames_to_column(clusterData, var = "germplasmName")
        clusterData <- clusterData %>%
            filter(germplasmName %in% rownames(selectedIndexGenotypes))

        clusterData <- column_to_rownames(clusterData, var = 'germplasmName')
    }
}

distMat <- clusterData %>%
                dist(., method="euclidean")

distMat <- round(distMat, 3)

 hClust <- distMat  %>%
                hclust(., method="complete")

# clusteredData <- clusteredData %>%
#     mutate_if(is.numeric, funs(round(., 2))) %>%
#     arrange(Cluster)
distTable <- data.frame(as.matrix(distMat))
print(head(distTable))

png(plotFile, height=600, width=600)
    ggtree(hClust, layout = "circular") +
    geom_tiplab(size  =3)
dev.off()

cat(reportNotes, file = reportFile, sep = "\n", append = TRUE)

if (length(genoFiles) > 1) {
    fwrite(genoData,
       file      = combinedDataFile,
       sep       = "\t",
       quote     = FALSE,
       )
}

if (length(resultFile) != 0 ) {
    fwrite(distTable,
       file      = resultFile,
       sep       = "\t",
       row.names = TRUE,
       quote     = FALSE,
       )
}

####
q(save = "no", runLast = FALSE)
####
