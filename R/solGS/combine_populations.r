#formats and combines phenotype (of a single trait)
#and genotype datasets of multiple
#populations

options(echo = FALSE)

library(stats)
library(stringr)
library(randomForest)
library(plyr)
library(lme4)
library(data.table)
library(phenoAnalysis)

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

traitInfo<-strsplit(trait, "\t");
traitId<-traitInfo[[1]]
traitName<-traitInfo[[2]]

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

popsPhenoSize     <- length(allPhenoFiles)
popsGenoSize      <- length(allGenoFiles)
popIds            <- c()
combinedPhenoPops <- c()

for (popPhenoNum in 1:popsPhenoSize) {
  popId <- str_extract_all(allPhenoFiles[[popPhenoNum]], "\\d+")
 
  popId <- popId[[1]][2]
  popIds <- c(popIds, popId)

  phenoData <- fread(allPhenoFiles[[popPhenoNum]],
                            na.strings = c("NA", " ", "--", "-", "."),
                           )
  phenoData <- data.frame(phenoData)
  
  phenoTrait <- getAdjMeans(phenoData, traitName)
 
  newTraitName <- paste(traitName, popId, sep = "_")
  colnames(phenoTrait)[2] <- newTraitName

  if (popPhenoNum == 1 )
    {
      print('no need to combine, yet')       
      combinedPhenoPops <- phenoTrait

    } else {
      print('combining...')
      
      combinedPhenoPops <- merge(combinedPhenoPops, phenoTrait, all=TRUE)
      rownames(combinedPhenoPops) <- combinedPhenoPops[, 1]
      combinedPhenoPops[, 1] <- NULL
      
    }   
}

#fill in missing data in combined phenotype dataset
#using row means
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

for (popGenoNum in 1:popsGenoSize)
  {
    popId <- str_extract(allGenoFiles[[popGenoNum]], "\\d+")
    popIds <- append(popIds, popId)

    genoData <- fread(allGenoFiles[[popGenoNum]],
                            na.strings = c("NA", " ", "--", "-"),
                           )

    genoData           <- as.data.frame(genoData)
    rownames(genoData) <- genoData[, 1]
    genoData[, 1]      <- NULL
    
    popMarkers <- colnames(genoData)
    message("No of markers from population ", popId, ": ", length(popMarkers))
    
    message("sum of geno missing values: ", sum(is.na(genoData)))
    genoData <- genoData[, colSums(is.na(genoData)) < nrow(genoData) * 0.5]
    message("sum of geno missing values: ", sum(is.na(genoData)))

    if (sum(is.na(genoData)) > 0)
      {
        message("sum of geno missing values: ", sum(is.na(genoData)))
        genoData <- na.roughfix(genoData)
        message("total number of stocks for pop ", popId,": ", length(rownames(genoData)))
      }

    if (popGenoNum == 1 )
      {
        print('no need to combine, yet')       
        combinedGenoPops <- genoData
        
      } else {
        print('combining genotype datasets...') 
        combinedGenoPops <-rbind(combinedGenoPops, genoData)
      }   
    
 
  }

message("combined total number of stocks in genotype dataset: ", length(rownames(combinedGenoPops)))
#discard duplicate clones
combinedGenoPops <- unique(combinedGenoPops)
message("combined unique number of stocks in genotype dataset: ", length(rownames(combinedGenoPops)))

message("writing data into files...")
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
