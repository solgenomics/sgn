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
library(ggplot2)
library(ape)
library(ggtree)
library(treeio)
library(R2D3) #install_github("jamesthomson/R2D3")

allArgs <- commandArgs()

outputFiles  <- grep("output_files", allArgs, value = TRUE)
outputFiles <- scan(outputFiles, what = "character")

inputFiles  <- grep("input_files", allArgs, value = TRUE)
inputFiles <- scan(inputFiles, what = "character")

clusterFile <- grep("cluster", outputFiles, value = TRUE)
newickFile <- grep("newick", outputFiles, value = TRUE)
jsonFile <- grep("json", outputFiles, value = TRUE)
reportFile  <- grep("report", outputFiles, value = TRUE)
errorFile   <- grep("error", outputFiles, value = TRUE)

combinedDataFile <- grep("combined_cluster_data_file", outputFiles, value = TRUE)

plotFile <- grep("hierarchical_plot", outputFiles, value = TRUE)
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

if (is.null(newickFile) && is.null(jsonFile)) {
  stop("Hierarchical output file is missing.")
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

        genoData <- unique(genoData, by = "V1")
        genoData <- data.frame(genoData)
        genoData <- column_to_rownames(genoData, "V1")
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
            genoDataMissing <- c("yes")
            genoData <- na.roughfix(genoData)
        }

        genoData <- data.frame(genoData)
    }
}

set.seed(235)

clusterDataNotScaled <- c()

if (grepl("genotype", dataType, ignore.case = TRUE)) {
    clusterData <- extractGenotype(inputFiles)

    pca    <- prcomp(clusterData, retx = TRUE)
    pca    <- summary(pca)

    variances <- data.frame(pca$importance)

    varProp        <- variances[3, ]
    varProp        <- data.frame(t(varProp))
    names(varProp) <- c("cumVar")

    selectPcs <- varProp %>% filter(cumVar <= 0.9)
    pcsCnt    <- nrow(selectPcs)

    reportNotes <- paste0("Before clustering this dataset, principal component analysis (PCA) was done on it. ", "\n")
    reportNotes <- paste0(reportNotes, "Based on the PCA, ", pcsCnt, " PCs are used to cluster this dataset. ", "\n")
    reportNotes <- paste0(reportNotes, "They explain 90% of the variance in the original dataset.", "\n")

    scores   <- data.frame(pca$x)
    scores   <- scores[, 1:pcsCnt]
    scores   <- round(scores, 3)

    variances <- variances[2, 1:pcsCnt]
    variances <- round(variances, 4) * 100
    variances <- data.frame(t(variances))

    clusterData <- scores
} else {

    if (grepl("gebv", dataType, ignore.case = TRUE)) {
        gebvsFile <- grep("combined_gebvs", inputFiles,  value = TRUE)
        gebvsData <- data.frame(fread(gebvsFile, header = TRUE))

        clusterNa   <- gebvsData %>% filter_all(any_vars(is.na(.)))
        clusterData <- column_to_rownames(gebvsData, 'V1')
    } else if (grepl("phenotype", dataType, ignore.case = TRUE)) {

        metaFile <- grep("meta", inputFiles,  value = TRUE)

        clusterData <- cleanAveragePhenotypes(inputFiles, metaDataFile = metaFile)

        if (!is.na(predictedTraits) && length(predictedTraits) > 1) {
            clusterData <- rownames_to_column(clusterData, var = "germplasmName")
            clusterData <- clusterData %>% select(c(germplasmName, predictedTraits))
            clusterData <- column_to_rownames(clusterData, var = "germplasmName")
        }
    }

    clusterDataNotScaled <- na.omit(clusterData)

    clusterData <- scale(clusterDataNotScaled, center=TRUE, scale=TRUE)
    reportNotes <- paste0(reportNotes, "Note: Data was standardized before clustering.", "\n")
}

sIndexFile <- grep("selection_index", inputFiles, value = TRUE)
selectedIndexGenotypes <- c()

if (length(sIndexFile) != 0) {
    sIndexData <- data.frame(fread(sIndexFile, header = TRUE))
    selectionProp <- selectionProp * 0.01
    selectedIndexGenotypes <- sIndexData %>% top_frac(selectionProp)

    selectedIndexGenotypes <- column_to_rownames(selectedIndexGenotypes, var = "V1")

    if (!is.null(selectedIndexGenotypes)) {
        clusterData <- rownames_to_column(clusterData, var = "germplasmName")
        clusterData <- clusterData %>%
            filter(germplasmName %in% rownames(selectedIndexGenotypes))

        clusterData <- column_to_rownames(clusterData, var = "germplasmName")
    }
}

distMat <- clusterData %>%
            dist(., method="euclidean")

distMat <- round(distMat, 3)
hClust <- distMat  %>%
            hclust(., method="complete")

distTable <- data.frame(as.matrix(distMat))

clustTree <- ggtree::ggtree(hClust,  layout = "circular", color = "#96CA2D")
xMax <- ggplot_build(clustTree)$layout$panel_scales_x[[1]]$range$range[2]
xMax <- xMax + 0.02

 # ggplot2::xlim(0, xMax)
clustTree <- clustTree +
    geom_tiplab(size = 3, color = "blue")

# geom_text(aes(x = branch, label = round(branch.length, 2)))
png(filename=plotFile, height = 950, width = 950)
print(clustTree)
dev.off()

cat(reportNotes, file = reportFile, sep = "\n", append = TRUE)

if (length(genoFiles) > 1) {
    fwrite(genoData,
       file      = combinedDataFile,
       sep       = "\t",
       quote     = FALSE,
       )
}

# if (length(resultFile) != 0 ) {
#     fwrite(clustTreeData,
#        file      = resultFile,
#        sep       = "\t",
#        row.names = TRUE,
#        quote     = FALSE,
#        )
# }

newickFormat <- ape::as.phylo(hClust)
write.tree(phy = newickFormat,
file = newickFile
)

jsonHclust <- R2D3::jsonHC(hClust)
write(jsonHclust$json, file = jsonFile)

message("Done hierachical clustering.")
####
q(save = "no", runLast = FALSE)
####
