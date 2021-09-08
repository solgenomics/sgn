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
library(genoDataFilter)

allArgs <- commandArgs()

inFile <- grep("input_files",
               allArgs,
               ignore.case = TRUE,
               perl = TRUE,
               value = TRUE
               )

inFiles <- scan(inFile,
                what = "character"
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

combinedPhenoFile <- grep("model_phenodata",
                          outFiles,
                          ignore.case = TRUE,
                          fixed = FALSE,
                          value = TRUE
                          )



## traitFile <- grep("model_phenodata",
##                   inFiles,
##                   ignore.case = TRUE,
##                   fixed = FALSE,
##                   value = TRUE
##                   )

## trait <- scan(traitFile,
##               what = "character",
##               )

## traitInfo <- strsplit(trait, "\t");
## traitId   <- traitInfo[[1]]
## traitName <- traitInfo[[2]]

modelInfoFile  <- grep("model_info", inFiles, value = TRUE)
message('model_info_file ', modelInfoFile)

traitRawPhenoFile <- grep('trait_raw_phenodata', outFiles, value = TRUE)

modelInfo  <- read.table(modelInfoFile,
                         header=TRUE, sep ="\t",
                         as.is = c('Value'))

modelInfo  <- column_to_rownames(modelInfo, var="Name")
traitId    <- modelInfo["trait_id", 1]
traitAbbr  <- modelInfo["trait_abbr", 1]
modelId    <- modelInfo["model_id", 1]
protocolId <- modelInfo["protocol_id", 1]

message('class ', class(traitAbbr))
message('trait_id ', traitId)
message('trait_abbr ', traitAbbr)
message('protocol_id ', protocolId)
message('model_id ', modelId)

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
traitRawPhenoData <- c()

for (popPhenoFile in allPhenoFiles) {

     cnt <- cnt + 1

    phenoData <- fread(popPhenoFile,
                       header = TRUE,
                       sep="\t",
                       na.strings = c("NA", "", "--", "-", "."))

     phenoData <- data.frame(phenoData)

     phenoTrait <- getAdjMeans(phenoData,
                               traitName = traitAbbr,
                               calcAverages = TRUE)

    keepMetaCols <- c('observationUnitName', 'germplasmName', 'studyDbId', 'locationName',
                  'studyYear', 'replicate', 'blockNumber')

    trialTraitRawPhenoData <- phenoData %>%
                                        select(c(keepMetaCols, traitAbbr))

     popIdFile <- basename(popPhenoFile)
     popId     <- str_extract(popIdFile, "\\d+")
     popIds    <- c(popIds, popId)

     newTraitName <- paste(traitAbbr, popId, sep = "_")
     colnames(phenoTrait)[2] <- newTraitName

     if (cnt == 1 ) {
         combinedPhenoPops <- phenoTrait
         traitRawPhenoData <- trialTraitRawPhenoData
     } else {
           combinedPhenoPops <- full_join(combinedPhenoPops, phenoTrait, by='germplasmName')
           traitRawPhenoData <- bind_rows(traitRawPhenoData, trialTraitRawPhenoData)
     }
 }

combinedPhenoPops <- column_to_rownames(combinedPhenoPops, var='germplasmName')

# #fill in missing data in combined phenotype dataset
# #using row means
naIndices <- which(is.na(combinedPhenoPops), arr.ind=TRUE)
combinedPhenoPops <- as.matrix(combinedPhenoPops)
combinedPhenoPops[naIndices] <- rowMeans(combinedPhenoPops, na.rm=TRUE)[naIndices[,1]]
combinedPhenoPops <- as.data.frame(combinedPhenoPops)

message("combined total number of stocks in phenotype dataset (before averaging): ", length(rownames(combinedPhenoPops)))

combinedPhenoPops$Average<-round(apply(combinedPhenoPops, 1, function(x) { mean(x) }), digits = 2)

combinedGenoPops <- c()

if (file.size(combinedGenoFile) < 100 ) {
    combinedGenoPops       <- combineGenoData(allGenoFiles)
    combinedGenoPops$trial <- NULL
    combinedGenoPops       <- combinedGenoPops[order(rownames(combinedGenoPops)), ]
}

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
if (!is.null(traitRawPhenoData) & length(traitRawPhenoFile) != 0) {

    fwrite(traitRawPhenoData,
           file  = traitRawPhenoFile,
           row.names = FALSE,
           sep   = "\t",
           na = 'NA',
           quote = FALSE,
           )
}
if(!is.null(combinedGenoPops)) {
    fwrite(combinedGenoPops,
           file = combinedGenoFile,
           sep = "\t",
           quote = FALSE,
           row.names = TRUE,
           )
 }

q(save = "no", runLast = FALSE)
