#SNOPSIS

#runs correlation analysis.
#Correlation coeffiecients are stored in tabular and json formats

#AUTHOR
# Isaak Y Tecle (iyt2@cornell.edu)

options(echo = FALSE)

library(ltm)
library(jsonlite)
library(data.table)
library(phenoAnalysis)
library(dplyr)
library(tibble)
library(methods)

allArgs <- commandArgs()

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
    what = "character")
inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
    what = "character")

message('inputFiles: ', inputFiles)

correInputData <- c()
correCoefsTableFile <- c()
correCoefsJsonFile <- c()
corrInputDataJson <- c()

convertDataFrameToJson <- function(df) {
    dfList <- lapply(
        split(df, rownames(df)),
        as.list
    )

    return(jsonlite::toJSON(dfList, auto_unbox = TRUE, pretty = TRUE))
}

if (any(grepl("phenotype_data", inputFiles))) {
    refererQtl <- grep("qtl", inputFiles, value = TRUE)

    phenoDataFile      <- grep("\\/phenotype_data", inputFiles, value = TRUE)
    formattedPhenoFile <- grep("formatted_phenotype_data", inputFiles, fixed = FALSE, value = TRUE)
    metaFile           <- grep("metadata", inputFiles, value = TRUE)
    correCoefsTableFile <- grep("pheno_corr_table", outputFiles, value = TRUE)
    correCoefsJsonFile  <- grep("pheno_corr_json", outputFiles, value = TRUE)

    corrInputDataJsonFile <- grep("corr_input_data_json", outputFiles, value = TRUE)

    formattedPhenoData <- c()
    phenoData          <- c()

    if (length(refererQtl) != 0) {
        phenoDataFile <- grep("\\/phenodata", inputFiles, value = TRUE)
        phenoData <- data.frame(fread(phenoDataFile,
            header = TRUE,
            sep = ",",
            na.strings = c("NA", "-", " ", ".", "..")))
    }

    metaData <- scan(metaFile, what = "character")

    allTraitNames <- c()
    nonTraitNames <- c()
    naTraitNames  <- c()

    if (length(refererQtl) != 0) {
        allNames      <- names(phenoData)
        nonTraitNames <- c("ID")
        allTraitNames <- allNames[! allNames %in% nonTraitNames]
    }

    correPhenoData <- c()

    if (length(refererQtl) == 0) {
        correInputData <- cleanAveragePhenotypes(inputFiles, metaDataFile = metaFile)
        allNames <- names(correInputData)
        nonTraitNames <- metaData
        allTraitNames <- allNames[! allNames %in% nonTraitNames]

    } else {
        message("qtl stuff")
        correInputData <- phenoData %>%
            group_by(ID) %>%
            summarise_if(is.numeric, mean, na.rm = TRUE) %>%
            select(-ID) %>%
            round(., 2) %>%
            data.frame
    }

} else if (any(grepl("combined_gebvs", inputFiles)) ||
           any(grepl("selection_index", inputFiles))) {

    correCoefsTableFile <- grep("genetic_corr_table", outputFiles, value = TRUE)
    correCoefsJsonFile  <- grep("genetic_corr_json", outputFiles, value = TRUE)
    geneticDataFile     <- grep("combined_gebvs", inputFiles, value = TRUE)
    selectionIndexFile  <- grep("selection_index", inputFiles, value = TRUE)

    geneticData <- read.table(geneticDataFile,
        header = TRUE,
        row.names = 1,
        sep = "\t",
        na.strings = c("NA"),
        dec = "."
    )

    indexData <- c()
    if (length(selectionIndexFile) != 0 &&
        file.info(selectionIndexFile)$size != 0) {
        indexData <- read.table(selectionIndexFile,
            header = TRUE,
            row.names = 1,
            sep = "\t",
            na.strings = c("NA"),
            dec = "."
        )
    }

    corrData <- c()

    if (!is.null(indexData)) {
        geneticData <- rownames_to_column(geneticData, var = "genotypes")
        indexData   <- rownames_to_column(indexData, var = "genotypes")

        geneticData <- geneticData %>% arrange(genotypes)
        indexData   <- indexData %>% arrange(genotypes)

        corrData <- full_join(geneticData, indexData)
        print(head(corrData))
        corrData <- column_to_rownames(corrData, var = "genotypes")
        print(head(corrData))
    } else {
        corrData <- geneticData
    }

    correInputData <- corrData
}

if (is.null(correInputData)) {
    stop("Can't run correlation analysis. There is no input data.")
}

corrInputDataJson <- convertDataFrameToJson(correInputData)
rownames(correInputData) <- NULL

correInputData <- correInputData %>%
    select(where(~ n_distinct(.) > 2))


coefpvalues <- rcor.test(correInputData,
    method = "pearson",
    use = "pairwise"
)

coefs <- coefpvalues$cor.mat
#remove rows and columns that are all "NA"
coefs <- data.frame(coefs)
if (any(is.na(coefs))) {
    coefs <- coefs[, colSums(is.na(coefs)) < nrow(coefs)]
}

coefs[upper.tri(coefs)] <- NA
pvalues <- coefpvalues$cor.mat
pvalues[lower.tri(pvalues)] <- coefpvalues$p.values[, 3]
pvalues <- round(pvalues, 3)
pvalues[upper.tri(pvalues)] <- NA
pvalues <- data.frame(pvalues)

allcordata <- coefpvalues$cor.mat
allcordata[upper.tri(allcordata)] <- coefpvalues$p.values[, 3]
diag(allcordata) <- 1
allcordata <- round(allcordata, 3)

traits <- colnames(coefs)

correlationList <- list(
    labels = traits,
    values  = coefs,
    pvalues = pvalues
)
print(correlationList)
correlationJson <- jsonlite::toJSON(correlationList)
print(correlationJson)

write.table(allcordata,
    file = correCoefsTableFile,
    sep  = "\t",
    row.names = TRUE,
    quote = FALSE
)

write(correlationJson,
    file = correCoefsJsonFile)

write(corrInputDataJson,
    file = corrInputDataJsonFile)

message("Done running correlation.")
q(save = "no", runLast = FALSE)
