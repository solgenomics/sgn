# a script for calculating selection index
# and ranking genotypes accordingly
# Isaak Y Tecle iyt2cornell.edu


options(echo = FALSE)

library(data.table)
library(stats)
library(stringi)

allArgs <- commandArgs()

inFile <- grep("input_selection_index",
               allArgs,
               ignore.case = TRUE,
               perl = TRUE,
               value = TRUE
               )

inputFiles <- scan(inFile, what = "character")

relWeightsFile <- grep("rel_weights",
                       inputFiles,
                       ignore.case = TRUE,
                       perl = TRUE,
                       value = TRUE
                       )

message('rel weights file: ', relWeightsFile)

outFile <- grep("output_selection_index",
                allArgs,
                ignore.case = TRUE,
                perl = TRUE,
                value = TRUE
                )

outputFiles <- scan(outFile, what = "character")

traitsFiles <- grep("gebv_files_of_traits",
                    inputFiles,
                    value = TRUE
                    )

gebvsSelectionIndexFile <- grep("gebvs_selection_index",
                            outputFiles,
                            value = TRUE
                            )

selectionIndexFile <- grep("selection_index_only",
                           outputFiles,
                           value=TRUE)

message('gebvs index file: ', gebvsSelectionIndexFile)
message('selection index file: ', selectionIndexFile)

inTraitFiles   <- scan(traitsFiles, what = "character")
traitFilesList <- strsplit(inTraitFiles, "\t");
traitsTotal    <- length(traitFilesList)

if (traitsTotal == 0)
  stop("There are no traits with GEBV data.")
if (length(relWeightsFile) == 0)
  stop("There is no file with relative weights of traits.")


relWeights           <- data.frame(fread(relWeightsFile))
rownames(relWeights) <- relWeights[, 1]
relWeights[, 1]      <- NULL 

combinedRelGebvs <- c()

for (i in 1:traitsTotal) {
  traitFile           <- traitFilesList[[i]]
  traitGEBV           <- data.frame(fread(traitFile))
  rownames(traitGEBV) <- traitGEBV[, 1]
  traitGEBV[, 1]      <- NULL
  traitGEBV           <- traitGEBV[order(rownames(traitGEBV)),,drop=FALSE] 
  trait               <- colnames(traitGEBV)

  message('trait ', trait)
   
  relWeight <- relWeights[trait, ]
   message('trait ', trait, ' rel wt ', relWeight)
   
  if (is.na(relWeight) == FALSE && relWeight != 0 ) {
      weightedTraitGEBV <- apply(traitGEBV, 1,
                                 function(x) x*relWeight
                                 )

      weightedTraitGEBV <- data.frame(weightedTraitGEBV)
      colnames(weightedTraitGEBV) <- paste0(trait, '_weighted')
      combinedRelGebvs  <- merge(combinedRelGebvs, weightedTraitGEBV,
                                 by = 0,
                                 all = TRUE                     
                                 )

      rownames(combinedRelGebvs) <- combinedRelGebvs[, 1]
     print(head(combinedRelGebvs))
      combinedRelGebvs[, 1]      <- NULL
     print( head(combinedRelGebvs))
    }
}

sumRelWeights <- apply(relWeights, 2, sum)
sumRelWeights <- sumRelWeights[[1]]

combinedRelGebvs$Index <- apply(combinedRelGebvs, 1, function (x) sum(x)/sumRelWeights)

combinedRelGebvs <- combinedRelGebvs[ with(combinedRelGebvs,
                                           order(-combinedRelGebvs$Index)
                                           ),
                                     ]

combinedRelGebvs <- round(combinedRelGebvs,
                          digits = 2
                          )

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
