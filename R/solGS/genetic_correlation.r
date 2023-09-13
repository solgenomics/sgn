 #SNOPSIS

 #runs genetic correlation analyis.
 #correlation coeffiecients are stored in tabular and json formats 

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(ltm)
library(jsonlite)
library(methods)
library(dplyr)
library(tibble)

allArgs <- commandArgs()

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                    what = "character")

correTableFile <- grep("genetic_corr_table", outputFiles, value=TRUE)
correJsonFile  <- grep("genetic_corr_json", outputFiles, value=TRUE)

geneticDataFile <- grep("combined_gebvs", inputFiles, value=TRUE)

selectionIndexFile <- grep("selection_index", inputFiles, value=TRUE)

geneticData <- read.table(geneticDataFile,
                          header = TRUE,
                          row.names = 1,
                          sep = "\t",
                          na.strings = c("NA"),
                          dec = "."
                          )

indexData <- c()

if (length(selectionIndexFile) != 0
    && file.info(selectionIndexFile)$size != 0) {
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
    geneticData <- rownames_to_column(geneticData, var="genotypes")    
    indexData   <- rownames_to_column(indexData, var="genotypes")
   
    geneticData <- geneticData %>% arrange(genotypes)
    indexData   <- indexData %>% arrange(genotypes)
    
    corrData <- full_join(geneticData, indexData)      
    corrData <- column_to_rownames(corrData, var="genotypes")
  
} else {
    corrData <- geneticData
}


coefpvalues <- rcor.test(corrData,
                         method="pearson",
                         use="pairwise"
                         )

coefficients <- coefpvalues$cor.mat
allcordata   <- coefpvalues$cor.mat

allcordata[lower.tri(allcordata)] <- coefpvalues$p.values[, 3]
diag(allcordata) <- 1.00

pvalues <- as.matrix(allcordata)
pvalues <- round(pvalues,
                 digits=2
                 )

coefficients <- round(coefficients,
                      digits=3
                      )

allcordata <- round(allcordata,
                    digits=3
                    )

#remove rows and columns that are all "NA"
coefficients <- data.frame(coefficients)
 if (any(is.na(coefficients))) {
  coefficients <- coefficients[ , colSums(is.na(coefficients)) < nrow(coefficients)] 
}

pvalues[upper.tri(pvalues)]           <- NA
coefficients[upper.tri(coefficients)] <- NA
coefficients <- data.frame(coefficients)

coefficients2json <- coefficients
names(coefficients2json) <- NULL

traits <- colnames(coefficients)

correlationList <- list(
    labels = traits,
    values  = coefficients
)

correlationJson <- jsonlite::toJSON(correlationList)

write.table(coefficients,
      file=correTableFile,
      col.names=TRUE,
      row.names=TRUE,
      quote=FALSE,
      dec="."
      )

write(correlationJson,
       file = correJsonFile)


q(save = "no", runLast = FALSE)
