 #SNOPSIS

 #runs population structure analysis using PCA from SNPRelate, a bioconductor R package

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(randomForest)
library(data.table)
library(genoDataFilter)
library(SNPRelate)
library(parallel)
#library(tidyr)

allArgs <- commandArgs()

outFile <- grep("output_files",
                allArgs,
                ignore.case = TRUE,
                perl = TRUE,
                value = TRUE
                )

outFiles <- scan(outFile,
                 what = "character"
                 )

genoDataFile <- grep("genotype_data",
                   allArgs,
                   ignore.case = TRUE,
                   fixed = FALSE,
                   value = TRUE
                   )

#genoDataFile2 <- c('/export/prod/tmp/localhost/GBSApeKIgenotypingv4/solgs/cache/genotype_data_443.txt')

scoresFile <- grep("pca_scores",
                        outFiles,
                        ignore.case = TRUE,
                        fixed = FALSE,
                        value = TRUE
                        )

loadingsFile <- grep("pca_loadings",
                        outFiles,
                        ignore.case = TRUE,
                        fixed = FALSE,
                        value = TRUE
                        )

varianceFile <- grep("pca_variance",
                        outFiles,
                        ignore.case = TRUE,
                        fixed = FALSE,
                        value = TRUE
                        )

message("genotype file: ", genoDataFile)
message("pca scores file: ", scoresFile)
message("pca loadings file: ", loadingsFile)
message("pca variance file: ", varianceFile)

if (is.null(genoDataFile))
{
  stop("genotype dataset missing.")
  q("no", 1, FALSE)
}

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

genoData <- fread(genoDataFile, na.strings = c("NA", " ", "--", "-", "."))
filteredGenoFile <- grep("filtered_genotype_data_",  genoDataFile, ignore.case = TRUE, perl=TRUE, value = TRUE)

message("filtered genotype file: ", filteredGenoFile)

if (is.null(filteredGenoFile) == TRUE) {
  ##genoDataFilter::filterGenoData
  genoData <- filterGenoData(genoData, maf=0)
} else {
  genoData           <- as.data.frame(genoData)
  rownames(genoData) <- genoData[, 1]
  genoData[, 1]      <- NULL
}

message("No. of geno missing values, ", sum(is.na(genoData)) )
genoDataMissing <- c()
if (sum(is.na(genoData)) > 0) {
  genoDataMissing <- c('yes')
  genoData <- na.roughfix(genoData)
}

nCores <- detectCores()
message('no cores: ', nCores)
if (nCores > 1) {
  nCores <- (nCores %/% 2)
} else {
  nCores <- 1
}

gdsFile <- basename(genoDataFile)
gdsFile <- gsub('.txt', '.gds', gdsFile)

snpgdsCreateGeno(gdsFile, data.matrix(genoData), snpfirstdim=FALSE)

genoDataGdsFile <- snpgdsOpen(gdsFile)

pcaOut <- snpgdsPCA(genoDataGdsFile, remove.monosnp=FALSE, eigen.cnt=10, num.thread=nCores)

variances <- round(pcaOut$varprop*100, 2)
variances <- as.numeric(grep(pattern="\\d+", variances, value=TRUE))

loadingsOut <- snpgdsPCASNPLoading(pcaOut, genoDataGdsFile, num.thread=nCores)

loadings <- round(loadingsOut$snploading, 5)
scores   <- data.frame(round(pcaOut$eigenvec, 5))
                     
snpgdsClose(genoDataGdsFile)

variances <- data.frame(variances)
scores    <- data.frame(scores)
loadings  <- data.frame(loadings)

pcs <- c()

for (i in 1:10) {
  pcs[i] <- paste("PC", i, sep='')
}


genotypes          <- rownames(genoData)
markers            <- names(genoData)
rownames(loadings) <- pcs
colnames(loadings) <- markers
colnames(scores)   <- pcs
rownames(scores)   <- genotypes

scores   <- scores[order(row.names(scores)), ]

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


## if (!is.null(genoDataMissing)) {
## fwrite(genoData,
##        file      = genoDataFile,
##        sep       = "\t",
##        row.names = TRUE,
##        quote     = FALSE,
##        )

## }


q(save = "no", runLast = FALSE)
