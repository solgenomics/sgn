 #SNOPSIS

 #runs population structure analysis using singular values decomposition (SVD)

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(randomForest)
library(irlba)
library(data.table)
library(genoDataFilter)

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
  genoData <- filterGenoData(genodata)
} else {
  genoData           <- as.data.frame(genoData)
  rownames(genoData) <- genoData[, 1]
  genoData[, 1]      <- NULL
}

#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
#genoTrCode <- grep("2", genoData[1, ], fixed=TRUE, value=TRUE)
#if(length(genoTrCode) != 0) {
# genoData <- genoData - 1
#}

message("No. of geno missing values, ", sum(is.na(genoData)) )
genoDataMissing <- c()
if (sum(is.na(genoData)) > 0) {
  genoDataMissing <- c('yes')
  genoData <- na.roughfix(genoData)
}


######
genotypes <- rownames(genoData)
svdOut    <- irlba(scale(genoData, TRUE, FALSE), nu=10, nv=10)
scores    <- round(svdOut$u %*% diag(svdOut$d), digits=2)
loadings  <- round(svdOut$v, digits=5)
totalVar  <- sum(svdOut$d)
variances <- unlist(
               lapply(svdOut$d,
                      function(x)
                      round((x / totalVar)*100, digits=2)
                      )
               )

variances <- data.frame(variances)
scores    <- data.frame(scores)
loadings  <- data.frame(loadings)

rownames(scores) <- genotypes

headers <- c()

for (i in 1:10) {
  headers[i] <- paste("PC", i, sep='')
}

colnames(scores) <- c(headers)

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


if (!is.null(genoDataMissing)) {
fwrite(genoData,
       file      = genoDataFile,
       sep       = "\t",
       row.names = TRUE,
       quote     = FALSE,
       )

}

q(save = "no", runLast = FALSE)
