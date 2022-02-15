#SNOPSIS
#calculates genomic estimated breeding values (GEBVs) using rrBLUP,
#GBLUP method

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
library(phenoAnalysis)
library(caret)
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

traitsFile <- grep("traits", inputFiles,  value = TRUE)
modelInfoFile  <- grep("model_info", inputFiles, value = TRUE)
message('model_info_file ', modelInfoFile)

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

datasetInfoFile <- grep("dataset_info", inputFiles, value = TRUE)
datasetInfo     <- c()

if (length(datasetInfoFile) != 0 ) {
    datasetInfo <- scan(datasetInfoFile, what = "character")
    datasetInfo <- paste(datasetInfo, collapse = " ")
  } else {
    datasetInfo <- c('single population')
  }

#validationTrait <- paste("validation", trait, sep = "_")
validationFile  <- grep('validation', outputFiles, value = TRUE)

if (is.null(validationFile)) {
  stop("Validation output file is missing.")
}

#kinshipTrait <- paste("rrblup_training_gebvs", trait, sep = "_")
blupFile     <- grep('rrblup_training_gebvs', outputFiles, value = TRUE)

if (is.null(blupFile)) {
  stop("GEBVs file is missing.")
}

#markerTrait <- paste("marker_effects", trait, sep = "_")
markerFile  <- grep('marker_effects', outputFiles, value = TRUE)

#traitPhenoFile <- paste("trait_phenotype_data", traitId, sep = "_")
modelPhenoFile <- grep('model_phenodata', outputFiles, value = TRUE)
message('model input trait pheno file ', modelPhenoFile)
traitRawPhenoFile <- grep('trait_raw_phenodata', outputFiles, value = TRUE)
varianceComponentsFile <- grep("variance_components", outputFiles, value = TRUE)
filteredGenoFile       <- grep("filtered_genotype_data", outputFiles, value = TRUE)
formattedPhenoFile     <- grep("formatted_phenotype_data", inputFiles, value = TRUE)

genoFile <- grep("genotype_data_", inputFiles, value = TRUE)

if (is.null(genoFile)) {
  stop("genotype data file is missing.")
}

if (file.info(genoFile)$size == 0) {
  stop("genotype data file is empty.")
}

readFilteredGenoData <- c()
filteredGenoData <- c()
formattedPhenoData <- c()
phenoData          <- c()
genoData           <- c()

if (length(filteredGenoFile) != 0 && file.info(filteredGenoFile)$size != 0) {
    filteredGenoData     <- fread(filteredGenoFile,
                                  na.strings = c("NA", "", "--", "-"),
                                  header = TRUE)

    genoData <-  data.frame(filteredGenoData)
    genoData <- column_to_rownames(genoData, 'V1')
    readFilteredGenoData <- 1
}


if (is.null(filteredGenoData)) {
    genoData <- fread(genoFile,
                      na.strings = c("NA", "", "--", "-"),
                      header = TRUE)

    genoData <- unique(genoData, by='V1')
    genoData <- data.frame(genoData)
    genoData <- column_to_rownames(genoData, 'V1')

  #genoDataFilter::filterGenoData
    genoData <- convertToNumeric(genoData)
    genoData <- filterGenoData(genoData, maf=0.01)
    genoData <- roundAlleleDosage(genoData)

    filteredGenoData   <- genoData

}

genoData <- genoData[order(row.names(genoData)), ]

if (length(formattedPhenoFile) != 0 && file.info(formattedPhenoFile)$size != 0) {
    formattedPhenoData <- data.frame(fread(formattedPhenoFile,
                                           header = TRUE,
                                           na.strings = c("NA", "", "--", "-", ".")
                                            ))

} else {

    if (datasetInfo == 'combined populations') {

         phenoFile <- grep("model_phenodata", inputFiles, value = TRUE)
    } else {

        phenoFile <- grep("\\/phenotype_data", inputFiles, value = TRUE)
    }

    if (is.null(phenoFile)) {
        stop("phenotype data file is missing.")
    }

    if (file.info(phenoFile)$size == 0) {
        stop("phenotype data file is empty.")
    }

    phenoData <- data.frame(fread(phenoFile,
                                  sep = "\t",
                                  na.strings = c("NA", "", "--", "-", "."),
                                  header = TRUE))


}

phenoTrait <- c()
traitRawPhenoData <- c()

if (datasetInfo == 'combined populations') {

   if (!is.null(formattedPhenoData)) {
      phenoTrait <- subset(formattedPhenoData, select = traitAbbr)
      phenoTrait <- na.omit(phenoTrait)

  } else {

      if (any(grepl('Average', names(phenoData)))) {
          phenoTrait <- phenoData %>% select(V1, Average) %>% data.frame
      } else {
          phenoTrait <- phenoData
      }

      colnames(phenoTrait)  <- c('genotypes', traitAbbr)
  }
 } else {

     if (!is.null(formattedPhenoData)) {
         phenoTrait <- subset(formattedPhenoData, select = c('V1', traitAbbr))
         phenoTrait <- as.data.frame(phenoTrait)
         phenoTrait <- na.omit(phenoTrait)
         print(head(phenoTrait))
         colnames(phenoTrait)[1] <- 'genotypes'

     } else if (length(grep('list', phenoFile)) != 0) {
 message('phenoTrait traitAbbr ', traitAbbr)
         phenoTrait <- averageTrait(phenoData, traitAbbr)

     } else {
         print(head(phenoTrait))
          print(head(phenoData))
         message('phenoTrait trait_abbr ', traitAbbr)
         print(class(traitAbbr))
         print(traitAbbr)
         phenoTrait <- getAdjMeans(phenoData,
                                   traitName = traitAbbr,
                                   calcAverages = TRUE)
     }

     keepMetaCols <- c('observationUnitName', 'germplasmName', 'studyDbId', 'locationName',
                    'studyYear', 'replicate', 'blockNumber')

      traitRawPhenoData <- phenoData %>%
                                          select(c(keepMetaCols, traitAbbr))


}

print('phenoTrait')
print(head(phenoTrait))
meanType <- names(phenoTrait)[2]
names(phenoTrait)  <- c('genotypes', traitAbbr)

selectionTempFile <- grep("selection_population", inputFiles, value = TRUE)

selectionFile       <- c()
filteredPredGenoFile <- c()
selectionAllFiles   <- c()

if (length(selectionTempFile) !=0 ) {
  selectionAllFiles <- scan(selectionTempFile, what = "character")

  selectionFile <- grep("\\/genotype_data", selectionAllFiles, value = TRUE)

  #filteredPredGenoFile   <- grep("filtered_genotype_data_",  selectionAllFiles, value = TRUE)
}

selectionPopGEBVsFile <- grep("rrblup_selection_gebvs", outputFiles, value = TRUE)

selectionData            <- c()
readFilteredPredGenoData <- c()
filteredPredGenoData     <- c()

## if (length(filteredPredGenoFile) != 0 && file.info(filteredPredGenoFile)$size != 0) {
##   selectionData <- fread(filteredPredGenoFile, na.strings = c("NA", " ", "--", "-"),)
##   readFilteredPredGenoData <- 1

##   selectionData           <- data.frame(selectionData)
##   rownames(selectionData) <- selectionData[, 1]
##   selectionData[, 1]      <- NULL

## } else
if (length(selectionFile) != 0) {

    selectionData <- fread(selectionFile,
                           header = TRUE,
                           na.strings = c("NA", "", "--", "-"))

    selectionData <- unique(selectionData, by='V1')
    selectionData <- data.frame(selectionData)
    selectionData <- column_to_rownames(selectionData, 'V1')

    selectionData <- convertToNumeric(selectionData)
    selectionData <- filterGenoData(selectionData, maf=0.01)
    selectionData <- roundAlleleDosage(selectionData)

    filteredPredGenoData <- selectionData
}


#impute genotype values for obs with missing values,
genoDataMissing <- c()

if (sum(is.na(genoData)) > 0) {
  genoDataMissing<- c('yes')

  genoData <- na.roughfix(genoData)
  genoData <- data.frame(genoData)
}

#create phenotype and genotype datasets with
#common stocks only

#extract observation lines with both
#phenotype and genotype data only.
commonObs           <- intersect(phenoTrait$genotypes, row.names(genoData))
commonObs           <- data.frame(commonObs)
rownames(commonObs) <- commonObs[, 1]

#include in the genotype dataset only phenotyped lines
genoDataFilteredObs <- genoData[(rownames(genoData) %in% rownames(commonObs)), ]

#drop phenotyped lines without genotype data
phenoTrait <- phenoTrait[(phenoTrait$genotypes %in% rownames(commonObs)), ]

phenoTraitMarker           <- data.frame(phenoTrait)
rownames(phenoTraitMarker) <- phenoTraitMarker[, 1]
phenoTraitMarker[, 1]      <- NULL

#impute missing data in prediction data
selectionDataMissing <- c()
if (length(selectionData) != 0) {
  #purge markers unique to both populations
  commonMarkers       <- intersect(names(data.frame(genoDataFilteredObs)), names(selectionData))
  selectionData      <- subset(selectionData, select = commonMarkers)
  genoDataFilteredObs <- subset(genoDataFilteredObs, select= commonMarkers)

  if (sum(is.na(selectionData)) > 0) {
    selectionDataMissing <- c('yes')
    selectionData <- na.roughfix(selectionData)
    selectionData <- data.frame(selectionData)
  }
}

#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genoTrCode <- grep("2", genoDataFilteredObs[1, ], value = TRUE)
if(length(genoTrCode) != 0) {
  genoData            <- genoData - 1
  genoDataFilteredObs <- genoDataFilteredObs - 1
}

if (length(selectionData) != 0 ) {
  genoSlCode <- grep("2", selectionData[1, ], value = TRUE)
  if (length(genoSlCode) != 0 ) {
    selectionData <- selectionData - 1
  }
}

ordered.markerEffects <- c()
trGEBV                <- c()
validationAll         <- c()
combinedGebvsFile     <- c()
allGebvs              <- c()
modelPhenoData        <- c()
relationshipMatrix    <- c()

#additive relationship model
#calculate the inner products for
#genotypes (realized relationship matrix)
relationshipMatrixFile <- grep("relationship_matrix_table", outputFiles, value = TRUE)
relationshipMatrixJsonFile <- grep("relationship_matrix_json", outputFiles, value = TRUE)

traitRelationshipMatrixFile <- grep("relationship_matrix_adjusted_table", outputFiles, value = TRUE)
traitRelationshipMatrixJsonFile <- grep("relationship_matrix_adjusted_json", outputFiles, value = TRUE)

inbreedingFile <- grep('inbreeding_coefficients', outputFiles, value=TRUE)
aveKinshipFile <- grep('average_kinship', outputFiles, value=TRUE)

inbreeding <- c()
aveKinship <- c()

if (length(relationshipMatrixFile) != 0) {
  if (file.info(relationshipMatrixFile)$size > 0 ) {
      relationshipMatrix <- data.frame(fread(relationshipMatrixFile,
      			 header = TRUE))

      rownames(relationshipMatrix) <- relationshipMatrix[, 1]
      relationshipMatrix[, 1]      <- NULL
      colnames(relationshipMatrix) <- rownames(relationshipMatrix)
      relationshipMatrix           <- data.matrix(relationshipMatrix)

  } else {
    relationshipMatrix           <- A.mat(genoData)
    diag(relationshipMatrix)     <- diag(relationshipMatrix) + 1e-6

    inbreeding <- diag(relationshipMatrix)
    inbreeding <- inbreeding - 1

    inbreeding <- inbreeding %>% replace(., . < 0, 0)
    inbreeding <- data.frame(inbreeding)

    inbreeding <- inbreeding %>%
        rownames_to_column('genotypes') %>%
        rename(Inbreeding = inbreeding) %>%
        arrange(Inbreeding) %>%
        mutate_at('Inbreeding', round, 3) %>%
        column_to_rownames('genotypes')
  }
}

relationshipMatrix <- data.frame(relationshipMatrix)
colnames(relationshipMatrix) <- rownames(relationshipMatrix)

relationshipMatrix <- rownames_to_column(relationshipMatrix, var="genotypes")
relationshipMatrix <- relationshipMatrix %>% mutate_if(is.numeric, round, 3)
relationshipMatrix <- column_to_rownames(relationshipMatrix, var="genotypes")

traitRelationshipMatrix <- relationshipMatrix[(rownames(relationshipMatrix) %in% rownames(commonObs)), ]
traitRelationshipMatrix <- traitRelationshipMatrix[, (colnames(traitRelationshipMatrix) %in% rownames(commonObs))]

traitRelationshipMatrix <- data.matrix(traitRelationshipMatrix)

#relationshipMatrixFiltered <- relationshipMatrixFiltered + 1e-3

nCores <- detectCores()

if (nCores > 1) {
  nCores <- (nCores %/% 2)
} else {
  nCores <- 1
}


if (length(selectionData) == 0) {

  trModel  <- kin.blup(data   = phenoTrait,
                      geno   = 'genotypes',
                      pheno  = traitAbbr,
                      K      = traitRelationshipMatrix,
                      n.core = nCores,
                      PEV    = TRUE
                     )

  trGEBV    <- trModel$g
  trGEBVPEV <- trModel$PEV
  trGEBVSE  <- sqrt(trGEBVPEV)
  trGEBVSE  <- data.frame(round(trGEBVSE, 2))

  trGEBV <- data.frame(round(trGEBV, 2))

  colnames(trGEBVSE) <- c('SE')
  colnames(trGEBV) <- traitAbbr

  trGEBVSE <- rownames_to_column(trGEBVSE, var="genotypes")
  trGEBV   <- rownames_to_column(trGEBV, var="genotypes")

  trGEBVSE <- full_join(trGEBV, trGEBVSE)

  trGEBVSE <-  trGEBVSE %>% arrange_(.dots= paste0('desc(', traitAbbr, ')'))

  trGEBVSE <- column_to_rownames(trGEBVSE, var="genotypes")

  trGEBV <- trGEBV %>% arrange_(.dots = paste0('desc(', traitAbbr, ')'))
  trGEBV <- column_to_rownames(trGEBV, var="genotypes")

  phenoTraitMarker    <- data.matrix(phenoTraitMarker)
  genoDataFilteredObs <- data.matrix(genoDataFilteredObs)

  markerEffects <- mixed.solve(y = phenoTraitMarker,
                               Z = genoDataFilteredObs
                               )

  ordered.markerEffects <- data.matrix(markerEffects$u)
  ordered.markerEffects <- data.matrix(ordered.markerEffects [order (-ordered.markerEffects[, 1]), ])
  ordered.markerEffects <- round(ordered.markerEffects, 5)

  colnames(ordered.markerEffects) <- c("Marker Effects")
  ordered.markerEffects <- data.frame(ordered.markerEffects)


  modelPhenoData   <- data.frame(round(phenoTraitMarker, 2))

  heritability  <- round((trModel$Vg/(trModel$Ve + trModel$Vg)), 2)
  additiveVar <- round(trModel$Vg, 2)
  errorVar <- round(trModel$Ve, 2)

  cat("\n", file = varianceComponentsFile,  append = FALSE)
  cat('Additive genetic variance', additiveVar , file = varianceComponentsFile, sep = '\t', append = TRUE)
  cat("\n", file = varianceComponentsFile,  append = TRUE)
  cat('Error variance', errorVar, file = varianceComponentsFile, sep = "\t", append = TRUE)
  cat("\n", file = varianceComponentsFile,  append = TRUE)
  cat('SNP heritability (h)', heritability, file = varianceComponentsFile, sep = '\t', append = TRUE)

  combinedGebvsFile <- grep('selected_traits_gebv', outputFiles, ignore.case = TRUE,value = TRUE)

  if (length(combinedGebvsFile) != 0) {
      fileSize <- file.info(combinedGebvsFile)$size
      if (fileSize != 0 ) {
          combinedGebvs <- data.frame(fread(combinedGebvsFile,
                                            header = TRUE))

        rownames(combinedGebvs) <- combinedGebvs[,1]
          combinedGebvs[,1]       <- NULL

          allGebvs <- merge(combinedGebvs, trGEBV,
                            by = 0,
                            all = TRUE
                            )

          rownames(allGebvs) <- allGebvs[,1]
          allGebvs[,1] <- NULL
      }
  }

#cross-validation

  if (is.null(selectionFile)) {
      genoNum <- nrow(phenoTrait)

      if (genoNum < 20 ) {
          warning(genoNum, " is too small number of genotypes.")
      }

      set.seed(4567)

      k <- 10
      times <- 2
      cvFolds <- createMultiFolds(phenoTrait[, 2], k=k, times=times)

      for ( r in 1:times) {
          re <- paste0('Rep', r)

          for (i in 1:k) {
              fo <- ifelse(i < 10, 'Fold0', 'Fold')

              trFoRe <- paste0(fo, i, '.', re)
              trG <- cvFolds[[trFoRe]]
              slG <- as.numeric(rownames(phenoTrait[-trG,]))

              kblup <- paste("rKblup", i, sep = ".")

              result <- kin.blup(data  = phenoTrait[trG,],
                                 geno  = 'genotypes',
                                 pheno = traitAbbr,
                                 K     = traitRelationshipMatrix,
                                 n.core = nCores,
                                 PEV    = TRUE
                                 )

              assign(kblup, result)

                                        #calculate cross-validation accuracy
              valBlups   <- result$g

              valBlups   <- data.frame(valBlups)

              slG <- slG[which(slG <= nrow(phenoTrait))]

              slGDf <- phenoTrait[(rownames(phenoTrait) %in% slG),]
              rownames(slGDf) <- slGDf[, 1]
              slGDf[, 1] <- NULL

              valBlups <-  rownames_to_column(valBlups, var="genotypes")
              slGDf    <-  rownames_to_column(slGDf, var="genotypes")

              valCorData <- inner_join(slGDf, valBlups, by="genotypes")
              valCorData$genotypes <- NULL

              accuracy   <- try(cor(valCorData))
              validation <- paste("validation", trFoRe, sep = ".")
              cvTest <- paste("CV", trFoRe, sep = " ")

              if ( class(accuracy) != "try-error")
              {
                  accuracy <- round(accuracy[1,2], digits = 3)
                  accuracy <- data.matrix(accuracy)

                  colnames(accuracy) <- c("correlation")
                  rownames(accuracy) <- cvTest

                  assign(validation, accuracy)

                  if (!is.na(accuracy[1,1])) {
                      validationAll <- rbind(validationAll, accuracy)
                  }
              }
          }
      }

      validationAll <- data.frame(validationAll[order(-validationAll[, 1]), ])
      colnames(validationAll) <- c('Correlation')
  }
}

selectionPopResult <- c()
selectionPopGEBVs  <- c()
selectionPopGEBVSE <- c()

if (length(selectionData) != 0) {

    genoDataTrSl <- rbind(genoDataFilteredObs, selectionData)
    rTrSl <- A.mat(genoDataTrSl)

    selectionPopResult <- kin.blup(data   = phenoTrait,
                                    geno   = 'genotypes',
                                    pheno  = traitAbbr,
                                    K      = rTrSl,
                                    n.core = nCores,
                                    PEV    = TRUE
                                    )

    selectionPopGEBVs <- round(data.frame(selectionPopResult$g), 2)
    colnames(selectionPopGEBVs) <- traitAbbr
    selectionPopGEBVs <- rownames_to_column(selectionPopGEBVs, var="genotypes")

    selectionPopPEV <- selectionPopResult$PEV
    selectionPopSE  <- sqrt(selectionPopPEV)
    selectionPopSE  <- data.frame(round(selectionPopSE, 2))
    colnames(selectionPopSE) <- 'SE'
    genotypesSl     <- rownames(selectionData)

    selectionPopSE <- rownames_to_column(selectionPopSE, var="genotypes")
    selectionPopSE <-  selectionPopSE %>% filter(genotypes %in% genotypesSl)

    selectionPopGEBVs <-  selectionPopGEBVs %>% filter(genotypes %in% genotypesSl)

    selectionPopGEBVSE <- inner_join(selectionPopGEBVs, selectionPopSE, by="genotypes")

    sortVar <- parse_quosure(traitAbbr)
    selectionPopGEBVs <- selectionPopGEBVs %>% arrange(desc((!!sortVar)))
    selectionPopGEBVs <- column_to_rownames(selectionPopGEBVs, var="genotypes")

    selectionPopGEBVSE <-  selectionPopGEBVSE %>% arrange(desc((!!sortVar)))
    selectionPopGEBVSE <- column_to_rownames(selectionPopGEBVSE, var="genotypes")
}

if (!is.null(selectionPopGEBVs) & length(selectionPopGEBVsFile) != 0)  {
    fwrite(selectionPopGEBVs,
           file  = selectionPopGEBVsFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}

if(!is.null(validationAll)) {
    fwrite(validationAll,
           file  = validationFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}


if (!is.null(ordered.markerEffects)) {
    fwrite(ordered.markerEffects,
           file  = markerFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}


if (!is.null(trGEBV)) {
    fwrite(trGEBV,
           file  = blupFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}

if (length(combinedGebvsFile) != 0 ) {
    if(file.info(combinedGebvsFile)$size == 0) {
        fwrite(trGEBV,
               file  = combinedGebvsFile,
               row.names = TRUE,
               sep   = "\t",
               quote = FALSE,
               )
      } else {
      fwrite(allGebvs,
             file  = combinedGebvsFile,
             row.names = TRUE,
             sep   = "\t",
             quote = FALSE,
             )
    }
}


if (!is.null(modelPhenoData) & length(modelPhenoFile) != 0) {

    if (!is.null(meanType)) {
        colnames(modelPhenoData) <- meanType
    }

    fwrite(modelPhenoData,
           file  = modelPhenoFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}

if (!is.null(traitRawPhenoData) & length(traitRawPhenoFile) != 0) {

    fwrite(traitRawPhenoData,
           file  = traitRawPhenoFile,
           row.names = FALSE,
           sep   = "\t",
           na = 'NA',
           quote = FALSE,
           )
}



if (!is.null(filteredGenoData) && is.null(readFilteredGenoData)) {
  fwrite(filteredGenoData,
         file  = filteredGenoFile,
         row.names = TRUE,
         sep   = "\t",
         quote = FALSE,
         )

}

## if (length(filteredPredGenoFile) != 0 && is.null(readFilteredPredGenoData)) {
##   fwrite(filteredPredGenoData,
##          file  = filteredPredGenoFile,
##          row.names = TRUE,
##          sep   = "\t",
##          quote = FALSE,
##          )
## }

## if (!is.null(genoDataMissing)) {
##   write.table(genoData,
##               file = genoFile,
##               sep = "\t",
##               col.names = NA,
##               quote = FALSE,
##             )

## }

## if (!is.null(predictionDataMissing)) {
##   write.table(predictionData,
##               file = predictionFile,
##               sep = "\t",
##               col.names = NA,
##               quote = FALSE,
##               )
## }


if (file.info(relationshipMatrixFile)$size == 0) {

  fwrite(relationshipMatrix,
         file  = relationshipMatrixFile,
         row.names = TRUE,
         sep   = "\t",
         quote = FALSE,
         )
}

if (file.info(relationshipMatrixJsonFile)$size == 0) {

    relationshipMatrixJson <- relationshipMatrix
    relationshipMatrixJson[upper.tri(relationshipMatrixJson)] <- NA


    relationshipMatrixJson <- data.frame(relationshipMatrixJson)

    relationshipMatrixList <- list(labels = names(relationshipMatrixJson),
                                       values = relationshipMatrixJson)

    relationshipMatrixJson <- jsonlite::toJSON(relationshipMatrixList)


    write(relationshipMatrixJson,
                    file  = relationshipMatrixJsonFile,
                    )
}


if (file.info(traitRelationshipMatrixFile)$size == 0) {

    inbre <- diag(traitRelationshipMatrix)
    inbre <- inbre - 1

    diag(traitRelationshipMatrix) <- inbre

    traitRelationshipMatrix <- data.frame(traitRelationshipMatrix) %>% replace(., . < 0, 0)

    fwrite(traitRelationshipMatrix,
           file  = traitRelationshipMatrixFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )

    if (file.info(traitRelationshipMatrixJsonFile)$size == 0) {

        traitRelationshipMatrixJson <- traitRelationshipMatrix
        traitRelationshipMatrixJson[upper.tri(traitRelationshipMatrixJson)] <- NA

        traitRelationshipMatrixJson <- data.frame(traitRelationshipMatrixJson)

        traitRelationshipMatrixList <- list(labels = names(traitRelationshipMatrixJson),
                                            values = traitRelationshipMatrixJson)

        traitRelationshipMatrixJson <- jsonlite::toJSON(traitRelationshipMatrixList)

        write(traitRelationshipMatrixJson,
              file  = traitRelationshipMatrixJsonFile,
              )
    }
}


if (file.info(inbreedingFile)$size == 0) {

  fwrite(inbreeding,
         file  = inbreedingFile,
         row.names = TRUE,
         sep   = "\t",
         quote = FALSE,
         )
}


if (file.info(aveKinshipFile)$size == 0) {

    aveKinship <- data.frame(apply(traitRelationshipMatrix, 1, mean))

    aveKinship<- aveKinship %>%
        rownames_to_column('genotypes') %>%
        rename(Mean_kinship = contains('traitRe')) %>%
        arrange(Mean_kinship) %>%
        mutate_at('Mean_kinship', round, 3) %>%
        column_to_rownames('genotypes')

    fwrite(aveKinship,
           file  = aveKinshipFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}


if (file.info(formattedPhenoFile)$size == 0 && !is.null(formattedPhenoData) ) {
  fwrite(formattedPhenoData,
         file = formattedPhenoFile,
         row.names = TRUE,
         sep = "\t",
         quote = FALSE,
         )
}

message("Done.")

q(save = "no", runLast = FALSE)
