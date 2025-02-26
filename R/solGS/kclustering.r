# SNOPSIS

# runs k-means cluster analysis

# AUTHOR Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(randomForest)
library(data.table)
library(genoDataFilter)
library(tibble)
library(dplyr)
library(fpc)
library(cluster)
library(ggfortify)
library(tibble)
library(stringi)
library(phenoAnalysis)
library(factoextra)

allArgs <- commandArgs()

outputFiles <- grep("output_files", allArgs, value = TRUE)
outputFiles <- scan(outputFiles, what = "character")

inputFiles <- grep("input_files", allArgs, value = TRUE)
inputFiles <- scan(inputFiles, what = "character")

optionsFile <- grep("options", inputFiles, value = TRUE)
clusterOptions <- read.table(optionsFile, header = TRUE, sep = "\t", stringsAsFactors = FALSE,
    na.strings = "")
print(clusterOptions)

kmeansPlotFile <- grep("k-means_plot", outputFiles, value = TRUE)
kResultFile <- grep("result", outputFiles, value = TRUE)
elbowPlotFile <- grep("elbow_plot", outputFiles, value = TRUE)
clusterMeansFile <- grep("k-means_means", outputFiles, value = TRUE)
clusterPcScoresFile <- grep("k-means_pc_scores", outputFiles, value = TRUE)
variancesFile <- grep("k-means_variances", outputFiles, value = TRUE)
reportFile <- grep("report", outputFiles, value = TRUE)
errorFile <- grep("error", outputFiles, value = TRUE)

combinedDataFile <- grep("combined_cluster_data_file", outputFiles, value = TRUE)

clusterOptions <- column_to_rownames(clusterOptions, var = "Params")
userKNumbers <- as.numeric(clusterOptions["k_numbers", 1])
dataType <- clusterOptions["data_type", 1]
selectionProp <- as.numeric(clusterOptions["selection_proportion", 1])
predictedTraits <- clusterOptions["predicted_traits", 1]
predictedTraits <- unlist(strsplit(predictedTraits, ","))

if (is.null(kResultFile)) {
    stop("Clustering output file is missing.")
    q("no", 1, FALSE)
}

clusterData <- c()
genoData <- c()
genoFiles <- c()
reportNotes <- c()
genoDataMissing <- c()

extractGenotype <- function(inputFiles) {

    genoFiles <- grep("genotype_data", inputFiles, value = TRUE)

    genoMetaData <- c()
    filteredGenoFile <- c()

    if (length(genoFiles) > 1) {
        genoData <- combineGenoData(genoFiles)

        genoMetaData <- genoData$trial
        genoData$trial <- NULL

    } else {
        genoFile <- genoFiles
        genoData <- fread(genoFile, header = TRUE, na.strings = c("NA", "", "--",
            "-", "."))

        if (is.null(genoData)) {
            filteredGenoFile <- grep("filtered_genotype_data_", genoFile, value = TRUE)
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

        ## genoDataFilter::filterGenoData
        genoData <- convertToNumeric(genoData)
        genoData <- filterGenoData(genoData, maf = 0.01)
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
} else {
    if (grepl("gebv", dataType, ignore.case = TRUE)) {
        gebvsFile <- grep("combined_gebvs", inputFiles, value = TRUE)
        gebvsData <- data.frame(fread(gebvsFile, header = TRUE))

        clusterNa <- gebvsData %>%
            filter_all(any_vars(is.na(.)))
        clusterData <- column_to_rownames(gebvsData, "V1")
    } else if (grepl("phenotype", dataType, ignore.case = TRUE)) {

        metaFile <- grep("meta", inputFiles, value = TRUE)

        clusterData <- cleanAveragePhenotypes(inputFiles, metaDataFile = metaFile)

        if (length(predictedTraits) > 1) {
            clusterData <- rownames_to_column(clusterData, var = "germplasmName")
            clusterData <- clusterData %>%
                select(c(germplasmName, predictedTraits))
            clusterData <- column_to_rownames(clusterData, var = "germplasmName")
        }
    }

    clusterData <- clusterData[, apply(clusterData, 2, function(x) var(x, na.rm=TRUE)) != 0]
    clusterDataNotScaled <- na.omit(clusterData)
    clusterData <- scale(clusterDataNotScaled, center = TRUE, scale = TRUE)
    clusterData <- round(clusterData, 3)
    reportNotes <- paste0(reportNotes, "Note: Data was standardized before clustering.",
        "\n")
}
sIndexFile <- grep("selection_index", inputFiles, value = TRUE)
selectedIndexGenotypes <- c()

if (length(sIndexFile) != 0) {
    sIndexData <- data.frame(fread(sIndexFile, header = TRUE))
    selectionProp <- selectionProp * 0.01
    selectedIndexGenotypes <- sIndexData %>%
        top_frac(selectionProp)

    selectedIndexGenotypes <- column_to_rownames(selectedIndexGenotypes, var = "V1")

    if (!is.null(selectedIndexGenotypes)) {
        clusterData <- rownames_to_column(clusterData, var = "germplasmName")
        clusterData <- clusterData %>%
            filter(germplasmName %in% rownames(selectedIndexGenotypes))

        clusterData <- column_to_rownames(clusterData, var = "germplasmName")
    }
}

kMeansOut <- kmeansruns(clusterData, runs = 10)
kCenters <- kMeansOut$bestk

if (!is.na(userKNumbers)) {
    if (userKNumbers != 0) {
        kCenters <- as.integer(userKNumbers)
        reportNotes <- paste0(reportNotes, "\n\nThe data was partitioned into ", userKNumbers,
            " clusters.\n")
    }
}

reportNotes <- paste0(reportNotes, "\n\nAccording the kmeansruns algorithm from the fpc R package, the recommended number of clusters (k) for this data set is: ",
    kCenters, "\n\nYou can also check the Elbow plot to evaluate how many clusters may be better suited for your purpose.")

kMeansOut <- kmeans(clusterData, centers = kCenters, nstart = 10)
kClusters <- data.frame(kMeansOut$cluster)
kClusters <- rownames_to_column(kClusters)
names(kClusters) <- c("germplasmName", "Cluster")

if (!is.null(clusterDataNotScaled)) {
    clusterDataNotScaled <- rownames_to_column(clusterDataNotScaled, var = "germplasmName")

    clusteredData <- inner_join(kClusters, clusterDataNotScaled, by = "germplasmName")
} else if (!is.null(selectedIndexGenotypes)) {
    selectedIndexGenotypes <- rownames_to_column(selectedIndexGenotypes, var = "germplasmName")
    clusteredData <- inner_join(kClusters, selectedIndexGenotypes, by = "germplasmName")
} else {
    clusteredData <- kClusters
}

clusteredData <- clusteredData %>%
    mutate_if(is.double, round, 2) %>%
    arrange(Cluster)

# print(paste('size: ', '\n', '\n', round(kMeansOut$size, 2)))
# print(paste('centers: ','\n', round(kMeansOut$centers, 2)))

if (length(elbowPlotFile) && !file.info(elbowPlotFile)$size) {
    message("running elbow method...")
    png(elbowPlotFile)
    print(fviz_nbclust(clusterData, k.max = 20, FUNcluster = kmeans, method = "wss"))
    dev.off()
}

png(kmeansPlotFile)
ggplot2::autoplot(kMeansOut, data = clusterData, frame = TRUE, x = 1, y = 2)
# fviz_cluster(kMeansOut, geom = "point", main = "", data = clusterData)
dev.off()

clusterMeans <- c()
if (!grepl('genotype', kResultFile)) {
    message("adding cluster means to clusters...")
    clusterMeans <- aggregate(clusterDataNotScaled, by = list(cluster = kMeansOut$cluster),
    mean)

    clusterMeans <- clusterMeans %>%
        select(-germplasmName) %>%
        mutate_if(is.double, round, 2)

}

pca <- c()
if (grepl("genotype", dataType, ignore.case = TRUE)) {
    pca    <- prcomp(clusterData, retx=TRUE)
} else if (is.null(selectedIndexGenotypes)) {
    pca    <- prcomp(clusterData, scale=TRUE, retx=TRUE)
} else {
    pca    <- prcomp(clusterData, retx=TRUE)
}

pca    <- summary(pca)
scores   <- data.frame(pca$x)
scores   <- scores[, 1:2]
scores   <- round(scores, 3)

clusterPcScoresGroups <- c()
if (length(clusterPcScoresFile)) {
    message("adding cluster groups to pc scores...")
    scores <- rownames_to_column(scores)
    names(scores)[1] <- c("germplasmName")

    clusterPcScoresGroups <- inner_join(kClusters, scores, by = "germplasmName")
    clusterPcScoresGroups <- clusterPcScoresGroups %>% 
        arrange(Cluster)
}

cat(reportNotes, file = reportFile, sep = "\n", append = TRUE)

variances <- paste0("Variances output: ")
variances <- append(variances, (paste0("\nBetween clusters sum of squares (betweenss): ",
    "\t", round(kMeansOut$betweenss, 2))))
withinss <- round(kMeansOut$withinss, 2)
withinss <- c(paste0("\nWithin clusters sum of squares (withinss): "), "\t", paste("\n\t",
    withinss))
variances <- append(variances, withinss)
variances <- append(variances, (paste0("\nTotal within cluster sum of squares (tot.withinss): ",
    "\t", round(kMeansOut$tot.withinss, 2))))

variances <- append(variances, (paste0("\nTotal sum of squares (totss): ", "\t",
    round(kMeansOut$totss, 2))))

cat(variances, file = variancesFile, sep = "", append = TRUE)

if (length(genoFiles) > 1) {
    fwrite(genoData, file = combinedDataFile, sep = "\t", row.names = TRUE, quote = FALSE,
        )
}

if (length(kResultFile)) {
    fwrite(clusteredData, file = kResultFile, sep = "\t", row.names = FALSE, quote = FALSE,
        )
}

if (length(clusterMeansFile) && !is.null(clusterMeans)) {
    fwrite(clusterMeans, file = clusterMeansFile, sep = "\t", row.names = FALSE,
        quote = FALSE, )
}

if (length(clusterPcScoresFile) && !is.null(clusterPcScoresGroups)) {
    fwrite(clusterPcScoresGroups, file = clusterPcScoresFile, sep = "\t", row.names = FALSE,
        quote = FALSE, )
}

message("Done clustering.")


####
q(save = "no", runLast = FALSE)
####
