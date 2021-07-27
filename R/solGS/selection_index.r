# calculates selection index
# and ranks genotypes accordingly
# Isaak Y Tecle iyt2cornell.edu


options(echo = FALSE)

library(data.table)
library(stats)
library(stringi)
library(dplyr)

allArgs <- commandArgs()

inputFiles <- scan(grep("input_files", allArgs, value = TRUE),
                   what = "character")

relWeightsFile <- grep("rel_weights", inputFiles, value = TRUE)

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

traitsFiles <- grep("gebv_files_of_traits", inputFiles, value = TRUE)

gebvsSelectionIndexFile <- grep("gebvs_selection_index",
                                outputFiles,
                                value = TRUE)

selectionIndexFile <- grep("selection_index_only",
                           outputFiles,
                           value=TRUE)

inTraitFiles   <- scan(traitsFiles, what = "character")

traitFilesList <- strsplit(inTraitFiles, "\t");
traitsTotal    <- length(traitFilesList)

if (traitsTotal == 0)
  stop("There are no traits with GEBV data.")
if (length(relWeightsFile) == 0)
  stop("There is no file with relative weights of traits.")


relWeights           <- data.frame(fread(relWeightsFile, header = TRUE))
rownames(relWeights) <- relWeights[, 1]
relWeights[, 1]      <- NULL 

if (is.null(relWeights)) {
    stop('There were no relative weights for all the traits.')
}

combinedRelGebvs <- c()

for (i in 1:traitsTotal) {
  traitFile           <- traitFilesList[[i]]
  traitGEBV           <- data.frame(fread(traitFile, header = TRUE))
  rownames(traitGEBV) <- traitGEBV[, 1]
  traitGEBV[, 1]      <- NULL
  traitGEBV           <- traitGEBV[order(rownames(traitGEBV)),,drop=FALSE] 
  trait               <- colnames(traitGEBV)
   
  relWeight <- relWeights[trait, ]
     
  if (is.na(relWeight) == FALSE && relWeight != 0 ) {
      
      weightedTraitGEBV <- apply(traitGEBV, 1,
                                 function(x) x*relWeight)

      weightedTraitGEBV <- data.frame(weightedTraitGEBV)
      colnames(weightedTraitGEBV) <- paste0(trait, '_weighted')

      combinedRelGebvs  <- merge(combinedRelGebvs, weightedTraitGEBV,
                                 by = 0,
                                 all = TRUE)


      rownames(combinedRelGebvs) <- combinedRelGebvs[, 1]
      combinedRelGebvs[, 1]      <- NULL
    }
}

sumRelWeights <- apply(relWeights, 2, sum)
sumRelWeights <- sumRelWeights[[1]]

combinedRelGebvs$Index <- apply(combinedRelGebvs, 1, function (x) sum(x))

combinedRelGebvs <- combinedRelGebvs[ with(combinedRelGebvs,
                                           order(-combinedRelGebvs$Index)
                                           ),
                                     ]

combinedRelGebvs <- round(combinedRelGebvs, 2)

selectionIndex <-c()

if (!is.null(combinedRelGebvs)) {
  selectionIndex <- subset(combinedRelGebvs,
                           select = 'Index'
                           )
}

if (gebvsSelectionIndexFile != 0) {
  if (!is.null(combinedRelGebvs)) {
    fwrite(combinedRelGebvs,
           file      = gebvsSelectionIndexFile,
           sep       = "\t",
           row.names = TRUE,
           quote     = FALSE,
           )
      }
}

if (!is.null(selectionIndexFile)) {
  if (!is.null(selectionIndex)) {
    fwrite(selectionIndex,
           file      = selectionIndexFile,
           row.names = TRUE,
           quote     = FALSE,
           sep       = "\t",
           )
  }
}

q(save = "no", runLast = FALSE)
