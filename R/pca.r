 #SNOPSIS

 #runs principal component analysis using prcomp

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(imputation)

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
}

if (is.null(scoresFile))
{
  stop("Scores output file is missing.")
}

if (is.null(loadingsFile))
{
  stop("Laodings file is missing.")
}

genoData <- read.table(genoDataFile,
                        header = TRUE,
                        row.names = 1,
                        sep = "\t",
                        na.strings = c("NA", " ", "--", "-", "."),
                        dec = "."
                        )


if (sum(is.na(genoData)) > 0) {
    message("sum of geno missing values, ", sum(is.na(genoData)) )
    genoData <-kNNImpute(genoData, 10)
    genoData <-as.data.frame(genoData)

    #extract columns with imputed values
    genoData <- subset(genoData,
                       select = grep("^x", names(genoData))
                       )

    #remove prefix 'x.' from imputed columns
    names(genoData) <- sub("x.", "", names(genoData))

    genoData <- round(genoData, digits = 0)
    genoData <- data.matrix(genoData)
  }

pca <- prcomp(genoData, retx=TRUE)

scores <- round(pca$x[, 1:10], digits=2)

loadings <- round(pca$rotation[, 1:10], digits=5)

totalVar <- sum((pca$sdev)^2)

variances <- unlist(lapply(pca$sdev, function(x) round((x^2 / totalVar)*100, digits=2)))

variances <- as.data.frame(variances)
colnames(variances)[1] <- "variances"

write.table(scores,
            file = scoresFile,
            sep = "\t",
            col.names = NA,
            quote = FALSE,
            append = FALSE
            )

write.table(loadings,
            file = loadingsFile,
            sep = "\t",
            col.names = NA,
            quote = FALSE,
            append = FALSE
            )


write.table(variances,
            file = varianceFile,
            sep = "\t",
            col.names = NA,
            quote = FALSE,
            append = FALSE
            )

q(save = "no", runLast = FALSE)
