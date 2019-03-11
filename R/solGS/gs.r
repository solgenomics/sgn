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
library(data.table)
library(parallel)
library(genoDataFilter)
library(phenoAnalysis)
library(caret)
library(dplyr)


allArgs <- commandArgs()

inputFiles  <- scan(grep("input_files", allArgs, ignore.case = TRUE, perl = TRUE, value = TRUE),
                   what = "character")

outputFiles <- scan(grep("output_files", allArgs, ignore.case = TRUE,perl = TRUE, value = TRUE),
                    what = "character")

traitsFile <- grep("traits", inputFiles, ignore.case = TRUE, value = TRUE)
traitFile  <- grep("trait_info", inputFiles, ignore.case = TRUE, value = TRUE)
traitInfo  <- scan(traitFile, what = "character",)
traitInfo  <- strsplit(traitInfo, "\t");
traitId    <- traitInfo[[1]]
trait      <- traitInfo[[2]]

datasetInfoFile <- grep("dataset_info", inputFiles, ignore.case = TRUE, value = TRUE)
datasetInfo     <- c()

if (length(datasetInfoFile) != 0 ) { 
    datasetInfo <- scan(datasetInfoFile, what = "character")    
    datasetInfo <- paste(datasetInfo, collapse = " ")   
  } else {   
    datasetInfo <- c('single population')  
  }

validationTrait <- paste("validation", trait, sep = "_")
validationFile  <- grep(validationTrait, outputFiles, ignore.case = TRUE, value = TRUE)

if (is.null(validationFile)) {
  stop("Validation output file is missing.")
}

kinshipTrait <- paste("rrblup_training_gebvs", trait, sep = "_")
blupFile     <- grep(kinshipTrait, outputFiles, ignore.case = TRUE, value = TRUE)

if (is.null(blupFile)) {
  stop("GEBVs file is missing.")
}
markerTrait <- paste("marker_effects", trait, sep = "_")
markerFile  <- grep(markerTrait, outputFiles, ignore.case = TRUE, value = TRUE)

traitPhenoFile <- paste("phenotype_data", trait, sep = "_")
traitPhenoFile <- grep(traitPhenoFile, outputFiles,ignore.case = TRUE, value = TRUE)

varianceComponentsFile <- grep("variance_components", outputFiles, ignore.case = TRUE, value = TRUE)
filteredGenoFile       <- grep("filtered_genotype_data", outputFiles, ignore.case = TRUE, value = TRUE)
formattedPhenoFile     <- grep("formatted_phenotype_data", inputFiles, ignore.case = TRUE, value = TRUE)

formattedPhenoData <- c()
phenoData          <- c()

genoFile <- grep("genotype_data_", inputFiles, ignore.case = TRUE, perl=TRUE, value = TRUE)
message('geno file ', genoFile)

if (is.null(genoFile)) {
  stop("genotype data file is missing.")
}

if (file.info(genoFile)$size == 0) {
  stop("genotype data file is empty.")
}

readFilteredGenoData <- c()
filteredGenoData <- c()
if (length(filteredGenoFile) != 0 && file.info(filteredGenoFile)$size != 0) {
  filteredGenoData     <- fread(filteredGenoFile, na.strings = c("NA", " ", "--", "-"),  header = TRUE)
  readFilteredGenoData <- 1
  message('read in filtered geno data')
}

genoData <- c()
if (is.null(filteredGenoData)) {
  genoData <- fread(genoFile, na.strings = c("NA", " ", "--", "-"),  header = TRUE)
  genoData <- unique(genoData, by='V1')
  message('read in unfiltered geno data')
}

if (length(formattedPhenoFile) != 0 && file.info(formattedPhenoFile)$size != 0) {
  formattedPhenoData <- as.data.frame(fread(formattedPhenoFile,
                                            na.strings = c("NA", " ", "--", "-", ".")
                                            ))

} else {
  phenoFile <- grep("\\/phenotype_data", inputFiles, ignore.case = TRUE, value = TRUE, perl = TRUE)

  if (is.null(phenoFile)) {
    stop("phenotype data file is missing.")
  }

  if (file.info(phenoFile)$size == 0) {
    stop("phenotype data file is empty.")
  }

  phenoData <- fread(phenoFile, sep="\t", na.strings = c("NA", " ", "--", "-", "."), header = TRUE) 
}

phenoData  <- as.data.frame(phenoData)
phenoTrait <- c()

if (datasetInfo == 'combined populations') {
  
   if (!is.null(formattedPhenoData)) {
      phenoTrait <- subset(formattedPhenoData, select = trait)
      phenoTrait <- na.omit(phenoTrait)
   
    } else {
      dropColumns <- grep(trait, names(phenoData), ignore.case = TRUE, value = TRUE)
      phenoTrait  <- phenoData[, !(names(phenoData) %in% dropColumns)]
   
      phenoTrait            <- as.data.frame(phenoTrait)   
      colnames(phenoTrait)  <- c('genotypes', trait)
    }   
 } else {

  if (!is.null(formattedPhenoData)) {
    phenoTrait <- subset(formattedPhenoData, select = c('V1', trait))
    phenoTrait <- as.data.frame(phenoTrait)
    phenoTrait <- na.omit(phenoTrait)
    
    colnames(phenoTrait)[1] <- 'genotypes'
   
} else if (length(grep('list', phenoFile)) != 0) {

    phenoTrait <- averageTrait(phenoData, trait)
    
} else {

    phenoTrait <- getAdjMeans(phenoData, trait)

  }
}

if (is.null(filteredGenoData)) {
 
  #genoDataFilter::filterGenoData
  genoData <- filterGenoData(genoData, maf=0.01)
  genoData <- roundAlleleDosage(genoData)

  genoData <- as.data.frame(genoData)
  rownames(genoData) <- genoData[, 1]
  genoData[, 1]      <- NULL
  filteredGenoData   <- genoData
  
} else {
  genoData           <- as.data.frame(filteredGenoData)
  rownames(genoData) <- genoData[, 1]
  genoData[, 1]      <- NULL
}

genoData <- genoData[order(row.names(genoData)), ]

predictionTempFile <- grep("selection_population", inputFiles, ignore.case = TRUE, value = TRUE)

predictionFile       <- c()
filteredPredGenoFile <- c()
predictionAllFiles   <- c()

message('prediction temp genotype file: ', predictionTempFile)

if (length(predictionTempFile) !=0 ) {
  predictionAllFiles <- scan(predictionTempFile, what = "character")

  predictionFile <- grep("\\/genotype_data", predictionAllFiles, ignore.case = TRUE, perl=TRUE, value = TRUE)
  message('prediction unfiltered genotype file: ', predictionFile)

  filteredPredGenoFile   <- grep("filtered_genotype_data_",  predictionAllFiles, ignore.case = TRUE, perl=TRUE, value = TRUE)
  message('prediction filtered genotype file: ', predictionFile)
}

predictionPopGEBVsFile <- grep("rrblup_selection_gebvs", outputFiles, ignore.case = TRUE, value = TRUE)

message("filtered pred geno file: ", filteredPredGenoFile)
message("prediction gebv file: ",  predictionPopGEBVsFile)

predictionData           <- c()
readFilteredPredGenoData <- c()
filteredPredGenoData     <- c()

if (length(filteredPredGenoFile) != 0 && file.info(filteredPredGenoFile)$size != 0) {
  predictionData <- fread(filteredPredGenoFile, na.strings = c("NA", " ", "--", "-"),)
  readFilteredPredGenoData <- 1

  predictionData           <- as.data.frame(predictionData)
  rownames(predictionData) <- predictionData[, 1]
  predictionData[, 1]      <- NULL
    
  message('read in filtered prediction genotype data')
} else if (length(predictionFile) != 0) {
    
  predictionData <- fread(predictionFile, na.strings = c("NA", " ", "--", "-"),)
  predictionData <- unique(predictionData, by='V1')
  
  predictionData <- filterGenoData(predictionData, maf=0.01)
  predictionData <- roundAlleleDosage(predictionData)
  
  predictionData  <- as.data.frame(predictionData)
  rownames(predictionData) <- predictionData[, 1]
  predictionData[, 1]      <- NULL
  filteredPredGenoData <- predictionData
}


#impute genotype values for obs with missing values,
genoDataMissing <- c()

if (sum(is.na(genoData)) > 0) {
  genoDataMissing<- c('yes')

  message("sum of geno missing values, ", sum(is.na(genoData)) )  
  genoData <- na.roughfix(genoData)
  genoData <- data.matrix(genoData)
}

#create phenotype and genotype datasets with
#common stocks only
message('phenotyped lines: ', length(row.names(phenoTrait)))
message('genotyped lines: ', length(row.names(genoData)))

#extract observation lines with both
#phenotype and genotype data only.
commonObs           <- intersect(phenoTrait$genotypes, row.names(genoData))
commonObs           <- data.frame(commonObs)
rownames(commonObs) <- commonObs[, 1]

message('lines with both genotype and phenotype data: ', length(row.names(commonObs)))

#include in the genotype dataset only phenotyped lines
message("genotype lines before filtering for phenotyped only: ", length(row.names(genoData)))        
genoDataFilteredObs <- genoData[(rownames(genoData) %in% rownames(commonObs)), ]
message("genotype lines after filtering for phenotyped only: ", length(row.names(genoDataFilteredObs)))

#drop phenotyped lines without genotype data
message("phenotype lines before filtering for genotyped only: ", length(row.names(phenoTrait)))        
phenoTrait <- phenoTrait[(phenoTrait$genotypes %in% rownames(commonObs)), ]
message("phenotype lines after filtering for genotyped only: ", length(row.names(phenoTrait)))

phenoTraitMarker           <- as.data.frame(phenoTrait)
rownames(phenoTraitMarker) <- phenoTraitMarker[, 1]
phenoTraitMarker[, 1]      <- NULL

#impute missing data in prediction data
predictionDataMissing <- c()
if (length(predictionData) != 0) {
  #purge markers unique to both populations
  commonMarkers       <- intersect(names(data.frame(genoDataFilteredObs)), names(predictionData))
  predictionData      <- subset(predictionData, select = commonMarkers)
  genoDataFilteredObs <- subset(genoDataFilteredObs, select= commonMarkers)
  
  if (sum(is.na(predictionData)) > 0) {
    predictionDataMissing <- c('yes')
    message("sum of geno missing values, ", sum(is.na(predictionData)) )  
    predictionData <- data.matrix(na.roughfix(predictionData))    
  }
}

#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genoTrCode <- grep("2", genoDataFilteredObs[1, ], value = TRUE)
if(length(genoTrCode) != 0) {
  genoData            <- genoData - 1
  genoDataFilteredObs <- genoDataFilteredObs - 1
}

if (length(predictionData) != 0 ) {
  genoSlCode <- grep("2", predictionData[1, ], value = TRUE)
  if (length(genoSlCode) != 0 ) {
    predictionData <- predictionData - 1
  }
}

ordered.markerEffects <- c()
ordered.trGEBV        <- c()
validationAll         <- c()
combinedGebvsFile     <- c()
allGebvs              <- c()
traitPhenoData        <- c()
relationshipMatrix    <- c()

#additive relationship model
#calculate the inner products for
#genotypes (realized relationship matrix)
relationshipMatrixFile <- grep("relationship_matrix", outputFiles, ignore.case = TRUE, value = TRUE)

message("relationship matrix file: ", relationshipMatrixFile)

if (length(relationshipMatrixFile) != 0) {
  if (file.info(relationshipMatrixFile)$size > 0 ) {
    relationshipMatrix <- as.data.frame(fread(relationshipMatrixFile))

    rownames(relationshipMatrix) <- relationshipMatrix[, 1]
    relationshipMatrix[, 1]      <- NULL
    colnames(relationshipMatrix) <- rownames(relationshipMatrix)
    relationshipMatrix           <- data.matrix(relationshipMatrix)
  } else {
    relationshipMatrix           <- A.mat(genoData)
    diag(relationshipMatrix)     <- diag(relationshipMatrix) + 1e-6
    colnames(relationshipMatrix) <- rownames(relationshipMatrix)
  }
}

relationshipMatrixFiltered <- relationshipMatrix[(rownames(relationshipMatrix) %in% rownames(commonObs)), ]
relationshipMatrixFiltered <- relationshipMatrixFiltered[, (colnames(relationshipMatrixFiltered) %in% rownames(commonObs))]
relationshipMatrix         <- data.frame(relationshipMatrix)

nCores <- detectCores()
message('no cores: ', nCores)
if (nCores > 1) {
  nCores <- (nCores %/% 2)
} else {
  nCores <- 1
}

message('assgined no cores: ', nCores)

if (length(predictionData) == 0) {

  trGEBV  <- kin.blup(data   = phenoTrait,
                      geno   = 'genotypes',
                      pheno  = trait,
                      K      = relationshipMatrixFiltered,
                      n.core = nCores,
                     )

  trGEBVu <- trGEBV$g

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


  traitPhenoData   <- data.frame(round(phenoTraitMarker, 2))   

  heritability  <- round((trGEBV$Vg/(trGEBV$Ve + trGEBV$Vg)), 2)

  cat("\n", file = varianceComponentsFile,  append = FALSE)
  cat('Error variance', trGEBV$Ve, file = varianceComponentsFile, sep = "\t", append = TRUE)
  cat("\n", file = varianceComponentsFile,  append = TRUE)
  cat('Additive genetic variance',  trGEBV$Vg, file = varianceComponentsFile, sep = '\t', append = TRUE)
  cat("\n", file = varianceComponentsFile,  append = TRUE)
  cat('Heritability (h)', heritability, file = varianceComponentsFile, sep = '\t', append = TRUE)


  trGEBV         <- data.matrix(trGEBVu)
  ordered.trGEBV <- as.data.frame(trGEBV[order(-trGEBV[, 1]), ])
  ordered.trGEBV <- round(ordered.trGEBV, 3)

  combinedGebvsFile <- grep('selected_traits_gebv', outputFiles, ignore.case = TRUE,value = TRUE)

  if (length(combinedGebvsFile) != 0) {
    fileSize <- file.info(combinedGebvsFile)$size
    if (fileSize != 0 ) {
        combinedGebvs <- as.data.frame(fread(combinedGebvsFile))

        rownames(combinedGebvs) <- combinedGebvs[,1]
        combinedGebvs[,1]       <- NULL

        colnames(ordered.trGEBV) <- c(trait)
      
        traitGEBV <- as.data.frame(ordered.trGEBV)
        allGebvs <- merge(combinedGebvs, traitGEBV,
                          by = 0,
                          all = TRUE                     
                          )

        rownames(allGebvs) <- allGebvs[,1]
        allGebvs[,1] <- NULL
     }
  }

  colnames(ordered.trGEBV) <- c(trait)
                  
#cross-validation

  if (is.null(predictionFile)) {
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
                           pheno = trait,
                           K     = relationshipMatrixFiltered,
                           n.core = nCores,
                           )
        
        assign(kblup, result)
 
        #calculate cross-validation accuracy
        valBlups   <- result$g
        valBlups   <- data.frame(valBlups)

        slG <- slG[which(slG <= nrow(phenoTrait))]   
 
        slGDf <- phenoTrait[(rownames(phenoTrait) %in% slG),]
        rownames(slGDf) <- slGDf[, 1]     
        slGDf[, 1] <- NULL
      
        valBlups   <- valBlups[(rownames(valBlups) %in% rownames(slGDf)), ]  
        valCorData <- merge(slGDf, valBlups, by=0) 
        rownames(valCorData) <- valCorData[, 1]
        valCorData[, 1]      <- NULL
     
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
    
    validationAll <- data.matrix(validationAll[order(-validationAll[, 1]), ])
     
    if (!is.null(validationAll)) {
      validationMean <- data.matrix(round(colMeans(validationAll), digits = 2))
   
      rownames(validationMean) <- c("Average")
     
      validationAll <- rbind(validationAll, validationMean)
      colnames(validationAll) <- c("Correlation")
    }
 
    validationAll <- data.frame(validationAll)
    
  }
}

predictionPopResult <- c()
predictionPopGEBVs  <- c()

if (length(predictionData) != 0) {
    message("running prediction for selection candidates...marker data", ncol(predictionData), " vs. ", ncol(genoDataFilteredObs))

    genoDataTrSl <- rbind(genoDataFilteredObs, predictionData)
    rTrSl <- A.mat(genoDataTrSl)
    
    predictionPopResult <- kin.blup(data   = phenoTrait,
                                    geno   = 'genotypes',
                                    pheno  = trait,
                                    K      = rTrSl,
                                    n.core = nCores,
                                    )
    
     message("running prediction for selection candidates...DONE!!")
    predictionPopGEBVs <- round(data.frame(predictionPopResult$g), 3)
    genotypesSl        <- rownames(predictionData)
    predictionPopGEBVs <- predictionPopGEBVs[(rownames(predictionPopGEBVs) %in% genotypesSl), ]
    predictionPopGEBVs <- data.frame(predictionPopGEBVs)
    predictionPopGEBVs <- data.frame(predictionPopGEBVs[order(-predictionPopGEBVs[, 1]), ])
   
    colnames(predictionPopGEBVs) <- c(trait)
}

if (!is.null(predictionPopGEBVs) & length(predictionPopGEBVsFile) != 0)  {
    fwrite(predictionPopGEBVs,
           file  = predictionPopGEBVsFile,
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


if (!is.null(ordered.trGEBV)) {
    fwrite(ordered.trGEBV,
           file  = blupFile,
           row.names = TRUE,
           sep   = "\t",
           quote = FALSE,
           )
}


if (length(combinedGebvsFile) != 0 ) {
    if(file.info(combinedGebvsFile)$size == 0) {
        fwrite(ordered.trGEBV,
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


if (!is.null(traitPhenoData) & length(traitPhenoFile) != 0) {
    fwrite(traitPhenoData,
           file  = traitPhenoFile,
           row.names = TRUE,
           sep   = "\t",
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

if (length(filteredPredGenoFile) != 0 && is.null(readFilteredPredGenoData)) {
  fwrite(filteredPredGenoData,
         file  = filteredPredGenoFile,
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
