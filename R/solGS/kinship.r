#SNOPSIS
#calculates kinship, indbreeding coefficients 

#AUTHOR
# Isaak Y Tecle (iyt2@cornell.edu)

options(echo = FALSE)

library(methods)
library(rrBLUP)
library(plyr)
library(stringr)
#library(lme4)
library(randomForest)
library(parallel)
library(genoDataFilter)
library(dplyr)
library(tibble)
library(rlang)
library(jsonlite)
library(data.table)



allArgs <- commandArgs()


inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                   what = "character")

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")



genoFile <- grep("genotype_data_", inputFiles, value = TRUE)

if (is.null(genoFile)) {
  stop("genotype data file is missing.")
}

if (file.info(genoFile)$size == 0) {
  stop("genotype data file is empty.")
}


genoData           <- c()

genoData <- fread(genoFile,
                  na.strings = c("NA", "", "--", "-"),
                  header = TRUE)

genoData <- unique(genoData, by='V1')
genoData <- data.frame(genoData)
genoData <- column_to_rownames(genoData, 'V1')    
genoData <- convertToNumeric(genoData)
genoData <- filterGenoData(genoData, maf=0.01)
genoData <- roundAlleleDosage(genoData)


genoData <- genoData[order(row.names(genoData)), ]

#impute genotype values for obs with missing values,
genoDataMissing <- c()

if (sum(is.na(genoData)) > 0) {
  genoDataMissing<- c('yes')

  genoData <- na.roughfix(genoData)
  genoData <- data.frame(genoData)
}

commonObs <- c()

#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genoTrCode <- grep("2", genoData[1, ], value = TRUE)
if(length(genoTrCode) != 0) {
  genoData            <- genoData - 1
}

relationshipMatrixFile <- grep("relationship_matrix_table", outputFiles, value = TRUE)
relationshipMatrixJsonFile <- grep("relationship_matrix_json", outputFiles, value = TRUE)

inbreedingFile <- grep('inbreeding_coefficients', outputFiles, value=TRUE)
aveKinshipFile <- grep('average_kinship', outputFiles, value=TRUE)

relationshipMatrix    <- c()
inbreeding <- c()
aveKinship <- c()
relationshipMatrixJson <- c()


relationshipMatrix           <- A.mat(genoData)
diag(relationshipMatrix)     <- diag(relationshipMatrix) + 1e-6
colnames(relationshipMatrix) <- rownames(relationshipMatrix)
relationshipMatrix           <- round(data.frame(relationshipMatrix), 3)

inbreeding <- diag(data.matrix(relationshipMatrix))
inbreeding <- inbreeding - 1
diag(relationshipMatrix) <- inbreeding

relationshipMatrix <- data.frame(relationshipMatrix) %>% replace(., . < 0, 0)

inbreeding <- inbreeding %>% replace(., . < 0, 0)
inbreeding <- data.frame(inbreeding)

inbreeding <- inbreeding %>%
    rownames_to_column('genotypes') %>%
    rename(Inbreeding = inbreeding) %>%
    arrange(Inbreeding) %>%
    mutate_at('Inbreeding', round, 3) %>%
    column_to_rownames('genotypes')


aveKinship <- data.frame(apply(relationshipMatrix, 1, mean))

aveKinship <- aveKinship %>%
    rownames_to_column('genotypes') %>%     
    rename(Mean_kinship = contains('apply')) %>%
    arrange(Mean_kinship) %>%
    mutate_at('Mean_kinship', round, 3) %>%
    column_to_rownames('genotypes')

relationshipMatrixJson <- relationshipMatrix
relationshipMatrixJson[upper.tri(relationshipMatrixJson)] <- NA


relationshipMatrixJson <- data.frame(relationshipMatrixJson)  
relationshipMatrixList <- list(labels = names(relationshipMatrixJson),
                               values = relationshipMatrixJson)
relationshipMatrixJson <- jsonlite::toJSON(relationshipMatrixList)


#if (file.info(relationshipMatrixFile)$size == 0) {
  
  fwrite(relationshipMatrix,
         file  = relationshipMatrixFile,
         row.names = TRUE,
         sep   = "\t",
         quote = FALSE,
         )   
#}

#if (file.info(relationshipMatrixJsonFile)$size == 0) {
 
    write(relationshipMatrixJson,
          file  = relationshipMatrixJsonFile,
          )
#}


message('inbreedingfile ', inbreedingFile)
message('ave file', aveKinshipFile)
message('kinshipfile ', relationshipMatrixFile)
#if (file.info(inbreedingFile)$size == 0) {
  
  fwrite(inbreeding,
         file  = inbreedingFile,
         row.names = TRUE,
         sep   = "\t",
         quote = FALSE,
         )
#}


#if (file.info(aveKinshipFile)$size == 0) {
     
    fwrite(aveKinship,
           file  = aveKinshipFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
#}


message("Done.")

q(save = "no", runLast = FALSE)
