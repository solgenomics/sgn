 #SNOPSIS

 #runs population structure analysis using singular values decomposition (SVD)

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(randomForest)
library(irlba)
library(data.table)


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
  #remove markers with > 60% missing marker data
  message('no of markers before filtering out: ', ncol(genoData))
  genoData[, which(colSums(is.na(genoData)) >= nrow(genoData) * 0.6) := NULL]
  message('no of markers after filtering out 60% missing: ', ncol(genoData))

  #remove indls with > 80% missing marker data
  genoData[, noMissing := apply(.SD, 1, function(x) sum(is.na(x)))]
  genoData <- genoData[noMissing <= ncol(genoData) * 0.8]
  genoData[, noMissing := NULL]

  message('no of indls after filtering out ones with 80% missing: ', nrow(genoData))
  #remove monomorphic markers
  message('marker no before monomorphic markers cleaning ', ncol(genoData))
  genoData[, which(apply(genoData, 2,  function(x) length(unique(x))) < 2) := NULL ]
  message('marker no after monomorphic markers cleaning ', ncol(genoData))

  ### MAF calculation ###
  calculateMAF <- function(x) {
    a0 <-  length(x[x==0])
    a1 <-  length(x[x==1])
    a2 <-  length(x[x==2])
    aT <- a0 + a1 + a2

    p   <- ((2*a0)+a1)/(2*aT)
    q   <- 1- p
    maf <- min(p, q)
  
    return (maf)

  }

  #remove markers with MAF < 5%
  genoData[, which(apply(genoData, 2,  calculateMAF) < 0.05) := NULL ]
  message('marker no after MAF cleaning ', ncol(genoData))
}

genoData           <- as.data.frame(genoData)
rownames(genoData) <- genoData[, 1]
genoData[, 1]      <- NULL


#genoData <- as.data.frame(round(genoData, digits=0))
#str(genoData)
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
