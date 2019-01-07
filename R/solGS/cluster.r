 #SNOPSIS

 #runs k-means or k-medoids cluster analysis

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


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
#library(factoextra)



allArgs <- commandArgs()

outputFile  <- grep("output_files", allArgs, value = TRUE)
outputFiles <- scan(outputFile, what = "character")

inputFile  <- grep("input_files", allArgs, value = TRUE)
inputFiles <- scan(inputFile, what = "character")

kResultFile <- grep("result", outputFiles, value = TRUE)
reportFile  <- grep("report", outputFiles, value = TRUE)
errorFile   <- grep("error", outputFiles, value = TRUE)

combinedDataFile <- grep("combined_cluster_data_file", outputFiles, value = TRUE)

plotPamFile      <- grep("plot_pam", outputFiles, value = TRUE)
plotKmeansFile   <- grep("plot_kmeans", outputFiles, value = TRUE)

message("k means result file: ", kResultFile)
message("k means plot file: ", plotKmeansFile)
optionsFile <- grep("options", inputFiles,  value = TRUE)
message("cluster options file: ", optionsFile)

clusterOptions <- read.table(optionsFile,
                             header=TRUE,
                             sep="\t",
                             stringsAsFactors=FALSE,
                             na.strings = "")

clusterOptions <- column_to_rownames(clusterOptions, var="Params")
print(clusterOptions)

userKNumbers <- clusterOptions["k numbers", 1]
dataType     <- clusterOptions["data type", 1]
message('userKNumbers ', userKNumbers)
message('data type ', dataType)


if (is.null(kResultFile))
{
  stop("Scores output file is missing.")
  q("no", 1, FALSE) 
}


clusterData <- c()
genoData    <- c()
genoFiles   <- c()

extractGenotype <- function(inputFiles) {

    genoFiles <- grep("genotype_data", inputFiles,  value = TRUE)
    genoMetaData <- c()
    filteredGenoFile <- c()

    if (length(genoFiles) > 1 ) {   
        message('allGenoFiles: ', genoFiles)
        genoData <- combineGenoData(genoFiles)
        
        genoMetaData   <- genoData$trial
        genoData$trial <- NULL
    } else {
        genoFile <- genoFiles
        message('geno file: ', genoFile)
        genoData <- fread(genoFile, na.strings = c("NA", " ", "--", "-", "."))
        genoData <- unique(genoData, by='V1')
        
        filteredGenoFile <- grep("filtered_genotype_data_",  genoFile, value = TRUE)

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
    
} 

if (length(grep('genotype', dataType, ignore.case=TRUE)) > 0) {
    clusterData <- extractGenotype(inputFiles)   
}

if (length(grep('gebv', dataType, ignore.case=TRUE)) > 0) {
     gebvsFile <- grep("combined_gebvs", inputFiles,  value = TRUE)
     message('gebvs file: ', gebvsFile)
     gebvsData <- data.frame(fread(gebvsFile))
     print(head(gebvsData))
     clusterNa  <- gebvsData %>% filter_all(any_vars(is.na(.)))
     print(clusterNa)
     clusterData <- column_to_rownames(gebvsData, 'V1')    
 }

clusterNa <- c()

set.seed(235)

if (length(grep('genotype', dataType, ignore.case=TRUE)) > 0) {
    pca    <- prcomp(clusterData, retx=TRUE)
    pca    <- summary(pca)

    variances <- data.frame(pca$importance)

    varProp        <- variances[3, ]
    varProp        <- data.frame(t(varProp))
    names(varProp) <- c('cumVar')

    selectPcs <- varProp %>% filter(cumVar <= 0.9) 
    pcsCnt    <- nrow(selectPcs)

    pcsNote <- paste0('Before clustering this dataset, principal component analysis (PCA) was done on it. ')
    pcsNote <- paste0(pcsNote, 'Based on the PCA, ', pcsCnt, ' PCs are used to cluster this dataset. ')
    pcsNote <- paste0(pcsNote, 'They explain 90% of the variance in the original dataset.')
    cat(pcsNote, file=reportFile, sep="\n", append=TRUE)

    scores   <- data.frame(pca$x)
    scores   <- scores[, 1:pcsCnt]
    scores   <- round(scores, 3)

    variances <- variances[2, 1:pcsCnt]
    variances <- round(variances, 4) * 100
    variances <- data.frame(t(variances))

    clusterData <- scores
}

clusterData <- na.omit(clusterData)
kMeansOut   <- kmeansruns(clusterData, runs=10)

kCenters <- kMeansOut$bestk
recK <- paste0('Recommended number of clusters (k) for this data set is: ', kCenters)
cat(recK, file=reportFile, sep="\n", append=TRUE)


if (!is.na(userKNumbers)) {

    if (userKNumbers != 0) {
        kCenters <- as.integer(userKNumbers)
        userK <- paste0('However, Clustering was based on ', userKNumbers)
        message('userK: ', userK)
        cat(userK, file=reportFile, sep="\n", append=TRUE)
    }
}

kMeansOut        <- kmeans(clusterData, centers=kCenters, nstart=10)
kClusters        <- data.frame(kMeansOut$cluster)
kClusters        <- rownames_to_column(kClusters)
names(kClusters) <- c('Genotypes', 'Cluster')
kClusters        <- kClusters %>% arrange(Cluster)

print(kClusters)
png(plotKmeansFile)
autoplot(kMeansOut, data=clusterData, frame = TRUE,  x=1, y=2)
dev.off()

#png(plotPamFile)
#autoplot(pam(genoData, 3), frame = TRUE, frame.type = 'norm', x=1, y=2)
#dev.off()


if (length(genoFiles) > 1) {
    fwrite(genoData,
       file      = combinedDataFile,
       sep       = "\t",
       row.names = TRUE,
       quote     = FALSE,
       )

}

if (length(kResultFile) != 0 ) {
    fwrite(kClusters,
       file      = kResultFile,
       sep       = "\t",
       row.names = FALSE,
       quote     = FALSE,
       )

}

####
q(save = "no", runLast = FALSE)
####
