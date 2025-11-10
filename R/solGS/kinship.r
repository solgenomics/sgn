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

genoData           <- c()

createGenoData <- function(inputFiles) {

    genoFiles <- grep("genotype_data", inputFiles,  value = TRUE)

    genoMetaData <- c()
    filteredGenoFile <- c()

    if (length(genoFiles) > 1) {   
        genoData <- genoDataFilter::combineGenoData(genoFiles)
   
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
       genoData <- genoDataFilter::convertToNumeric(genoData)
       genoData <- genoDataFilter::filterGenoData(genoData, maf=0.01)
       genoData <- genoDataFilter::roundAlleleDosage(genoData)

        message("No. of geno missing values, ", sum(is.na(genoData)))
        if (sum(is.na(genoData)) > 0) {
            genoData <- na.roughfix(genoData)
        }
   
        genoData <- data.frame(genoData)
    } 
}

genoData <- createGenoData(inputFiles)  
genoData <- genoData[order(row.names(genoData)), ]

#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genoTrCode <- grep("2", genoData[1, ], value = TRUE)
if(length(genoTrCode) != 0) {
  genoData            <- genoData - 1
}

relationshipMatrixFile <- grep("relationship_matrix_adjusted_table", outputFiles, value = TRUE)
relationshipMatrixJsonFile <- grep("relationship_matrix_adjusted_json", outputFiles, value = TRUE)

message('matrix file ', relationshipMatrixFile)
message('json file ', relationshipMatrixJsonFile)

inbreedingFile <- grep('inbreeding_coefficients', outputFiles, value=TRUE)
aveKinshipFile <- grep('average_kinship', outputFiles, value=TRUE)

message('inbreeding file ', inbreedingFile)
message('ave file ', aveKinshipFile)

relationshipMatrix    <- c()
inbreeding <- c()
aveKinship <- c()
relationshipMatrixJson <- c()


relationshipMatrix           <- rrBLUP::A.mat(genoData)
diag(relationshipMatrix)     <- diag(relationshipMatrix) + 1e-6
genos <- rownames(relationshipMatrix)

relationshipMatrix <- data.frame(relationshipMatrix)

colnames(relationshipMatrix) <- genos
rownames(relationshipMatrix) <- genos

relationshipMatrix <- relationshipMatrix %>%
    rownames_to_column('genotypes') %>%
	        mutate_if(is.numeric, round, 3) %>%
		    column_to_rownames('genotypes')
		    


inbreeding <- diag(data.matrix(relationshipMatrix))
inbreeding <- inbreeding - 1
diag(relationshipMatrix) <- inbreeding

relationshipMatrix <- relationshipMatrix %>% replace(., . < 0, 0)
relationshipMatrix <- relationshipMatrix %>% replace(., . >  1, 0.99)

inbreeding <- inbreeding %>% replace(., . < 0, 0)
inbreeding <- inbreeding %>% replace(., . > 1,  . - 1)
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
