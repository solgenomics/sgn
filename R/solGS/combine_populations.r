#formats and combines phenotype (of a single trait)
#and genotype datasets of multiple
#populations

options(echo = FALSE)

library(stringr)
library(randomForest)
library(lme4)
library(data.table)
library(phenoAnalysis)
library(dplyr)
library(tibble)

allArgs <- commandArgs()

inFile <- grep("input_files",
               allArgs,
               ignore.case = TRUE,
               perl = TRUE,
               value = TRUE
               )

outFile <- grep("output_files",
                allArgs,
                ignore.case = TRUE,
                perl = TRUE,
                value = TRUE
                )

outFiles <- scan(outFile,
                 what = "character"
                 )

combinedGenoFile <- grep("genotype_data",
                         outFiles,
                         ignore.case = TRUE,
                         fixed = FALSE,
                         value = TRUE
                         )

combinedPhenoFile <- grep("phenotype_data",
                          outFiles,
                          ignore.case = TRUE,
                          fixed = FALSE,
                          value = TRUE
                          )

inFiles <- scan(inFile,
                what = "character"
                )
print(inFiles)

traitFile <- grep("trait_",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )

trait <- scan(traitFile,
              what = "character",
              )

traitInfo <- strsplit(trait, "\t");
traitId   <- traitInfo[[1]]
traitName <- traitInfo[[2]]

#extract trait phenotype data from all populations
#and combine them into one dataset

allPhenoFiles <- grep("phenotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )
message("phenotype files: ", allPhenoFiles)

allGenoFiles <- grep("genotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )

popIds            <- c()
combinedPhenoPops <- c()
cnt               <- 0

for (popPhenoFile in allPhenoFiles) {

     cnt <- cnt + 1
 
     phenoData <- fread(popPhenoFile,
                        na.strings = c("NA", " ", "--", "-", "."))
    
     phenoData <- data.frame(phenoData)
    
     phenoTrait <- getAdjMeans(phenoData, traitName)

     popIdFile <- basename(popPhenoFile)
     popId     <- str_extract(popIdFile, "\\d+")
     popIds    <- c(popIds, popId)
    
     newTraitName <- paste(traitName, popId, sep = "_")
     colnames(phenoTrait)[2] <- newTraitName

     if (cnt == 1 ) {
         print('no need to combine, yet')       
         combinedPhenoPops <- phenoTrait
     } else {
         print('combining...phenotypes')
            
         combinedPhenoPops           <- full_join(combinedPhenoPops, phenoTrait, by='genotypes')
         rownames(combinedPhenoPops) <- combinedPhenoPops[, 1]
         combinedPhenoPops[, 1]      <- NULL            
     }
    
}

# #fill in missing data in combined phenotype dataset
# #using row means
naIndices <- which(is.na(combinedPhenoPops), arr.ind=TRUE)
combinedPhenoPops <- as.matrix(combinedPhenoPops)
combinedPhenoPops[naIndices] <- rowMeans(combinedPhenoPops, na.rm=TRUE)[naIndices[,1]]
combinedPhenoPops <- as.data.frame(combinedPhenoPops)

message("combined total number of stocks in phenotype dataset (before averaging): ", length(rownames(combinedPhenoPops)))

combinedPhenoPops$Average<-round(apply(combinedPhenoPops,
                                        1,
                                        function(x)
                                        { mean(x) }
                                        ),
                                  digits = 2
                                  )

markersList      <- c()
combinedGenoPops <- c()
cnt              <- 0

for (popGenoFile in allGenoFiles) {

    uniqGenoNames <- c()
    cnt <- cnt + 1

    genoData <- fread(popGenoFile,
                      na.strings = c("NA", " ", "--", "-"),
                      )

    genoData <- data.frame(genoData)
    message('cnt of genotypes in dataset: ', length(rownames(genoData)))
    genoData <- genoData[!duplicated(genoData[,'V1']), ]
    message('cnt of unique genotypes in dataset: ', length(rownames(genoData)))		
    rownames(genoData) <- genoData[, 1]
    genoData[, 1] <- NULL
    
    popGenoFile <- basename(popGenoFile)     
    popId       <- str_extract(popGenoFile, "\\d+")
    popIds      <- c(popIds, popId)

    #popMarkers <- colnames(genoData)
    #message("No of markers from population ", popId, ": ", length(popMarkers))
    
   # message("sum of geno missing values: ", sum(is.na(genoData)))
   # genoData <- genoData[, colSums(is.na(genoData)) < nrow(genoData) * 0.5]
   # genoData <- data.frame(genoData)
   # message("sum of geno missing values: ", sum(is.na(genoData)))
    ## if (sum(is.na(genoData)) > 0) {
    ##     message("sum of geno missing values: ", sum(is.na(genoData)))
    ##     genoData <- na.roughfix(genoData)
    ##     message("total number of stocks for pop ", popId,": ", length(rownames(genoData)))
    ## }

    if (cnt == 1 ) {
        print('no need to combine, yet')
        message('cnt of genotypes first dataset: ', length(rownames(genoData)))
        combinedGenoPops <- genoData
        
    } else {
        print('combining genotype datasets...')
        
        uniqGenoNames <- unique(rownames(combinedGenoPops))
      
        message('cnt of genotypes in new dataset ', popId, ': ',  length(rownames(genoData)) )
       
        genoData <- genoData[!(rownames(genoData) %in% uniqGenoNames),]

        message('cnt of unique genotypes from new dataset ', popId, ': ', length(rownames(genoData)))

        if (!is.null(genoData)) {        
            combinedGenoPops <- rbind(combinedGenoPops, genoData)
        } else {
            message('dataset ', popId, ' has no unique genotypes.')
        }
    }   
    
}

combinedGenoPops <- combinedGenoPops[order(rownames(combinedGenoPops)), ]
message("combined number of genotypes in combined dataset: ", length(rownames(combinedGenoPops)))

message("writing data to files...")
#if(length(combinedPhenoFile) != 0 )
#  {
      fwrite(combinedPhenoPops,
                  file = combinedPhenoFile,
                  sep = "\t",
                  quote = FALSE,
                  row.names = TRUE,
                  )
#  }

#if(length(combinedGenoFile) != 0 )
#  {
      fwrite(combinedGenoPops,
                  file = combinedGenoFile,
                  sep = "\t",
                  quote = FALSE,
                   row.names = TRUE,
                  )
#  }

q(save = "no", runLast = FALSE)
