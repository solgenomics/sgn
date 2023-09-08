#SNOPSIS
#calculates genomic estimated breeding values (GEBVs) using rrBLUP,
#GBLUP method

#AUTHOR
# Isaak Y Tecle (iyt2@cornell.edu)

options(echo = FALSE)
# options(warn = -1)
suppressWarnings(suppressPackageStartupMessages({
library(methods)
library(rrBLUP)
library(plyr)
library(stringr)
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
  }))
library(genoDataFilter)
library(Matrix)

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
protocolPage <- modelInfo["protocol_url", 1]

message('trait_id ', traitId)
message('trait_abbr ', traitAbbr)
message('protocol_id ', protocolId)
message('protocol detail page ', protocolPage)

message('model_id ', modelId)

datasetInfoFile <- grep("dataset_info", inputFiles, value = TRUE)
datasetInfo     <- c()

if (length(datasetInfoFile) != 0 ) {
    datasetInfo <- scan(datasetInfoFile, what = "character")
    datasetInfo <- paste(datasetInfo, collapse = " ")
  } else {
    datasetInfo <- c('single_population')
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
modelGenoFile <- grep('model_genodata', outputFiles, value = TRUE)
message('model input trait geno file ', modelGenoFile)
traitRawPhenoFile <- grep('trait_raw_phenodata', outputFiles, value = TRUE)
varianceComponentsFile <- grep("variance_components", outputFiles, value = TRUE)
analysisReportFile <- grep("_report_", outputFiles, value = TRUE)
genoFilteringLogFile <- grep("genotype_filtering_log", outputFiles, value = TRUE)

filteredTrainingGenoFile       <- grep("filtered_training_genotype_data", outputFiles, value = TRUE)
filteredSelGenoFile       <- grep("filtered_selection_genotype_data", outputFiles, value = TRUE)
formattedPhenoFile     <- grep("formatted_phenotype_data", inputFiles, value = TRUE)

genoFile <- grep("genotype_data_", inputFiles, value = TRUE)

if (is.null(genoFile)) {
  stop("genotype data file is missing.")
}

if (file.info(genoFile)$size == 0) {
  stop(paste0("genotype data file ", genoFile, " is empty."))
}

readfilteredTrainingGenoData <- c()
filteredTrainingGenoData <- c()
genoFilterLog <- c()
formattedPhenoData <- c()
phenoData          <- c()
genoData           <- c()
maf <- 0.01
markerFilter <- 0.6
cloneFilter <- 0.8

logHeading <- paste0("Genomic Prediction Analysis Log for ", traitAbbr,  ".\n")
logHeading <- append(logHeading,  paste0("Date: ", format(Sys.time(), "%d %b %Y %H:%M"), "\n\n\n"))
logHeading <- format(logHeading, width=80, justify="c")
trainingLog <- paste0("\n\n#Preprocessing training population genotype data.\n\n")
trainingLog <- append(trainingLog, "The following data filtering will be applied to the genotype dataset:\n\n")
trainingLog <- append(trainingLog, paste0("Markers with less or equal to ", maf * 100, "% minor allele frequency (maf)  will be removed.\n"))
trainingLog <- append(trainingLog, paste0("\nMarkers with greater or equal to ", markerFilter * 100, "% missing values will be removed.\n"))
trainingLog <- append(trainingLog, paste0("Clones  with greater or equal to ", cloneFilter * 100, "% missing values  will be removed.\n") )

if (length(filteredTrainingGenoFile) != 0 && file.info(filteredTrainingGenoFile)$size != 0) {
    filteredTrainingGenoData     <- fread(filteredTrainingGenoFile,
                                  na.strings = c("NA", "", "--", "-"),
                                  header = TRUE)

    genoData <-  data.frame(filteredTrainingGenoData)
    genoData <- column_to_rownames(genoData, 'V1')
    readfilteredTrainingGenoData <- 1
}

if (is.null(filteredTrainingGenoData)) {
    genoData <- fread(genoFile,
                      na.strings = c("NA", "", "--", "-"),
                      header = TRUE)
    genoData <- unique(genoData, by='V1')
    genoData <- data.frame(genoData)
    genoData <- column_to_rownames(genoData, 'V1')
  #genoDataFilter::filterGenoData
    genoData <- convertToNumeric(genoData)

    trainingLog <- append(trainingLog, "#Running training population genotype data cleaning.\n\n")
    genoFilterOut <- filterGenoData(genoData, maf=maf, markerFilter=markerFilter, indFilter=cloneFilter, logReturn=TRUE)
    
    genoData <- genoFilterOut$data
    genoFilteringLog <- genoFilterOut$log
    genoData <- roundAlleleDosage(genoData)
    filteredTrainingGenoData   <- genoData

} else {
  genoFilteringLog <- scan(genoFilteringLogFile, what = "character", sep="\n")
  genoFilteringLog <- paste0(genoFilteringLog, collapse="\n")
}

message("genofilteringlogfile: ", genoFilteringLogFile)
message(genoFilteringLog)
trainingLog <- append(trainingLog, genoFilteringLog)

genoData <- genoData[order(row.names(genoData)), ]

if (length(formattedPhenoFile) != 0 && file.info(formattedPhenoFile)$size != 0) {
    formattedPhenoData <- data.frame(fread(formattedPhenoFile,
                                           header = TRUE,
                                           na.strings = c("NA", "", "--", "-", ".")
                                            ))

} else {

    if (datasetInfo == 'combined_populations') {

         phenoFile <- grep("model_phenodata", inputFiles, value = TRUE)
    } else {

        phenoFile <- grep("\\/phenotype_data", inputFiles, value = TRUE)
    }

    if (is.null(phenoFile)) {
        stop("phenotype data file is missing.")
    }

    if (file.info(phenoFile)$size == 0) {
       stop(paste0("phenotype data file ", phenoFile, " is empty."))

    }

    phenoData <- data.frame(fread(phenoFile,
                                  sep = "\t",
                                  na.strings = c("NA", "", "--", "-", "."),
                                  header = TRUE))


}

phenoTrait <- c()
traitRawPhenoData <- c()
anovaLog <- paste0("#Preprocessing training population phenotype data.\n\n")

if (datasetInfo == 'combined_populations') {
   anovaLog <- scan(analysisReportFile, what = "character", sep="\n")
  anovaLog <- paste0(anovaLog, collapse="\n")

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
         colnames(phenoTrait)[1] <- 'genotypes'

     } else if (length(grep('list', phenoFile)) != 0) {
         phenoTrait <- averageTrait(phenoData, traitAbbr)

     } else {
         meansResult <- getAdjMeans(phenoData,
                                   traitName = traitAbbr,
                                   calcAverages = TRUE,
                                   logReturn = TRUE)

         

          anovaLog <- paste0(anovaLog, meansResult$log)
          phenoTrait <- meansResult$adjMeans
     }

     keepMetaCols <- c('observationUnitName', 'germplasmName', 'studyDbId', 'locationName',
                    'studyYear', 'replicate', 'blockNumber', traitAbbr)

      traitRawPhenoData <- phenoData %>%
                                          select(all_of(keepMetaCols))


}

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
selectionLog <- c()
if (length(selectionFile) != 0) {
selectionLog <- append(selectionLog, paste0("#Data preprocessing of selection population genotype data.\n\n"))

    selectionData <- fread(selectionFile,
                           header = TRUE,
                           na.strings = c("NA", "", "--", "-"))

  selectionData <- data.frame(selectionData)
  selectionData <- unique(selectionData, by='V1') 
  selectionData <- column_to_rownames(selectionData, 'V1')
  selectionData <- convertToNumeric(selectionData)

  selectionLog <- append(selectionLog, paste0("Running selection population genotype data cleaning."))

  selectionFilterOut <- filterGenoData(selectionData, maf=maf, markerFilter=markerFilter, indFilter=cloneFilter, logReturn=TRUE)
  selectionData <- selectionFilterOut$data
  selectionLog <- append(selectionLog, selectionFilterOut$log)
  selectionData <- roundAlleleDosage(selectionData)
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
trainingLog <- append(trainingLog, paste0("\n\n#Filtering for training population genotypes with both phenotype and marker data.\n\n"))
trainingLog <- append(trainingLog, paste0("After calculating trait averages, the training population phenotype dataset has ", length(rownames(phenoTrait)), " individuals.\n") )
trainingLog <- append(trainingLog, paste0("After cleaning up for missing values, the training population genotype dataset has ", length(rownames(genoData)), " individuals.\n") )

commonObs           <- intersect(phenoTrait$genotypes, row.names(genoData))

trainingLog <- append(trainingLog, paste0(length(commonObs), " individuals are shared in both phenotype and genotype datasets.\n"))

#remove genotyped lines without phenotype data
genoDataFilteredObs <- genoData[(rownames(genoData) %in% commonObs), ]

trainingLog <- append(trainingLog, paste0("After removing individuals without phenotype data, this genotype dataset has ", length(rownames(genoDataFilteredObs)), " individuals.\n"))

#remove phenotyped lines without genotype data
phenoTrait <- phenoTrait[(phenoTrait$genotypes %in% commonObs), ]

trainingLog <- append(trainingLog, paste0("After removing individuals without genotype data, this phenotype dataset has ", length(rownames(phenoTrait)), " individuals.\n" ))

phenoTraitMarker           <- data.frame(phenoTrait)
rownames(phenoTraitMarker) <- phenoTraitMarker[, 1]
phenoTraitMarker[, 1]      <- NULL

#impute missing data in prediction data

selectionDataMissing <- c()
if (length(selectionData) != 0) {
  #purge markers unique to both populations
  trainingMarkers <- names(genoDataFilteredObs)
  selectionMarkers <-  names(selectionData)

selectionLog <- append(selectionLog, paste0("#Comparing markers in the training and selection populations genotype datasets.\n\n" ))
  
selectionLog <- append(selectionLog, paste0("The training population genotype dataset has ", length(trainingMarkers), " markers.\n" ))
selectionLog <- append(selectionLog, paste0("The selection population genotype dataset has ", length(selectionMarkers), " markers.\n" ))

commonMarkers  <- intersect(trainingMarkers, selectionMarkers)
selectionLog <- append(selectionLog, paste0("The training and selection populations genotype dataset have ", length(trainingMarkers), " markers in common.\n" ))

genoDataFilteredObs <- subset(genoDataFilteredObs, select= commonMarkers)
selectionLog <- append(selectionLog, paste0("After filtering for shared markers, the training population genotype dataset has ", length(names(selectionData)), " markers.\n" ))

selectionData      <- subset(selectionData, select = commonMarkers)
selectionLog <- append(selectionLog, paste0("After filtering for shared markers, the selection population genotype dataset has ", length(names(selectionData)), " markers.\n" ))

  if (sum(is.na(selectionData)) > 0) {
    selectionDataMissing <- c('yes')
    selectionData <- na.roughfix(selectionData)
    selectionData <- data.frame(selectionData)
  }
}
#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genoTrCode <- grep("2", genoDataFilteredObs[1, ], value = TRUE)
if(length(genoTrCode)) {
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
  diag(relationshipMatrix)     <- diag(relationshipMatrix) %>% replace(., . < 1, 1)
relationshipMatrix <- relationshipMatrix %>% replace(., . <= 0, 0.00001)

    inbreeding <- diag(relationshipMatrix)
    inbreeding <- inbreeding - 1
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
relationshipMatrix <- relationshipMatrix %>% mutate_if(is.numeric, round, 5)
relationshipMatrix <- column_to_rownames(relationshipMatrix, var="genotypes")

traitRelationshipMatrix <- relationshipMatrix[(rownames(relationshipMatrix) %in% commonObs), ]
traitRelationshipMatrix <- traitRelationshipMatrix[, (colnames(traitRelationshipMatrix) %in% commonObs)]

kinshipLog <- c()
if (any(eigen(traitRelationshipMatrix)$values < 0) ) {
kinshipLog <- paste0("\n\nNote: The kinship matrix of this dataset causes 'Not positive semi-definite error' while running the Cholesky decomposition. To fix this and run the modeling, a corrected positive semi-definite matrix was computed using the 'Matrix::nearPD' function. The negative eigen values from this decomposition nudged to positive values.\n\n")

traitRelationshipMatrix <- Matrix::nearPD(as.matrix(traitRelationshipMatrix))$mat
}

traitRelationshipMatrix <- data.matrix(traitRelationshipMatrix)

nCores <- detectCores()

if (nCores > 1) {
  nCores <- (nCores %/% 2)
} else {
  nCores <- 1
}
varCompData <- c()
modelingLog <- paste0("\n\n#Training a model for ", traitAbbr, ".\n\n")
modelingLog <- append(modelingLog, paste0("The genomic prediction modeling follows a two-step approach. First trait average values, as described above, are computed for each genotype. This is followed by the model fitting on the basis of single phenotype value for each genotype entry and kinship  matrix computed from their marker data.\n"))

if (length(kinshipLog)) {
modelingLog <- append(modelingLog, paste0(kinshipLog))
}

if (length(selectionData) == 0) {

  trModel  <- kin.blup(data   = phenoTrait,
                      geno   = 'genotypes',
                      pheno  = traitAbbr,
                      K      = traitRelationshipMatrix,
                      n.core = nCores,
                      PEV    = TRUE
                     )

modelingLog <- paste0(modelingLog, "The model training is based on rrBLUP R package, version ", packageVersion('rrBLUP'), ". GEBVs are predicted using the kin.blup function and GBLUP method.\n\n")

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

 varCompData <- c("\nAdditive genetic variance\t", additiveVar, "\n")
 varCompData <- append(varCompData, c("Error variance\t", errorVar, "\n"))
 varCompData <- append(varCompData, c("SNP heritability (h)\t", heritability, "\n"))

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
      reps <- 2
      cvFolds <- createMultiFolds(phenoTrait[, 2], k=k, times=reps)

  modelingLog <- paste0(modelingLog, "Model prediction accuracy is evaluated using cross-validation method. ",  k,  " folds, replicated ", reps, " times are used to predict the model accuracy.\n\n")

      for ( r in 1:reps) {
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

              if (inherits(accuracy, 'try-error') == FALSE)
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

#selection pop geno data after  cleaning up and removing unique markers to selection pop
filteredSelGenoData <- selectionData
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

    sortVar <- parse_expr(traitAbbr)
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

if (!is.null(modelPhenoData) && length(modelPhenoFile) != 0) {

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

if (!is.null(genoDataFilteredObs) && length(modelGenoFile) != 0) {

    fwrite(genoDataFilteredObs,
           file  = modelGenoFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}

if (!is.null(traitRawPhenoData) && length(traitRawPhenoFile) != 0) {

    fwrite(traitRawPhenoData,
           file  = traitRawPhenoFile,
           row.names = FALSE,
           sep   = "\t",
           na = 'NA',
           quote = FALSE,
           )
}

if (!is.null(filteredTrainingGenoData) && file.info(filteredTrainingGenoFile)$size == 0) {
  fwrite(filteredTrainingGenoData,
         file  = filteredTrainingGenoFile,
         row.names = TRUE,
         sep   = "\t",
         quote = FALSE,
         )

  cat(genoFilteringLog, fill = TRUE,  file = genoFilteringLogFile, append=FALSE)
}

if (length(filteredSelGenoFile) != 0 && file.info(filteredSelGenoFile)$size == 0) {
  fwrite(filteredSelGenoData,
         file  = filteredSelGenoFile,
         row.names = TRUE,
         sep   = "\t",
         quote = FALSE,
         )
}

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
if (!is.null(varCompData)) {
  cat(varCompData, file = varianceComponentsFile)
}

if (!is.null(selectionLog)) {
  cat(logHeading, selectionLog, fill = TRUE,  file = analysisReportFile, append=FALSE)
} else {
  cat(logHeading, anovaLog, trainingLog, modelingLog, fill = TRUE,  file = analysisReportFile, append=FALSE)
}

message("Done.")

q(save = "no", runLast = FALSE)
