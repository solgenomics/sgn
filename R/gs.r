#SNOPSIS
#calculates genomic estimated breeding values (GEBVs) using rrBLUP,
#GBLUP method

#AUTHOR
# Isaak Y Tecle (iyt2@cornell.edu)

options(echo = FALSE)

library(rrBLUP)
library(plyr)
library(stringr)
library(lme4)
library(randomForest)
library(data.table)
#library(genetics)

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

kinshipTrait <- paste("kinship", trait, sep = "_")
blupFile     <- grep(kinshipTrait, outputFiles, ignore.case = TRUE, value = TRUE)

if (is.null(blupFile)) {
  stop("GEBVs file is missing.")
}
markerTrait <- paste("marker", trait, sep = "_")
markerFile  <- grep(markerTrait, outputFiles, ignore.case = TRUE, value = TRUE)

traitPhenoFile <- paste("phenotype_trait", trait, sep = "_")
traitPhenoFile <- grep(traitPhenoFile, outputFiles,ignore.case = TRUE, value = TRUE)

varianceComponentsFile <- grep("variance_components", outputFiles, ignore.case = TRUE, value = TRUE)
filteredGenoFile       <- grep("filtered_genotype_data", outputFiles, ignore.case = TRUE, value = TRUE)
formattedPhenoFile     <- grep("formatted_phenotype_data", inputFiles, ignore.case = TRUE, value = TRUE)

formattedPhenoData <- c()
phenoData          <- c()

genoFile <- grep("genotype_data", inputFiles, ignore.case = TRUE, value = TRUE)

if (is.null(genoFile)) {
  stop("genotype data file is missing.")
}

if (file.info(genoFile)$size == 0) {
  stop("genotype data file is empty.")
}

usedFilteredGenoData <- c()
filteredGenoData <- c()
if (length(filteredGenoFile) != 0 && file.info(filteredGenoFile)$size != 0) {
  filteredGenoData <- fread(filteredGenoFile, na.strings = c("NA", " ", "--", "-"),  header = TRUE)
  usedFilteredGenoData <- 1
  message('read in filtered geno data')
}

genoData <- c()
if (is.null(filteredGenoData)) {
  genoData <- fread(genoFile, na.strings = c("NA", " ", "--", "-"),  header = TRUE)
  message('read in unfiltered geno data')
}

if (length(formattedPhenoFile) != 0 && file.info(formattedPhenoFile)$size != 0) {
  formattedPhenoData <- as.data.frame(fread(formattedPhenoFile,
                                            na.strings = c("NA", " ", "--", "-", ".")
                                            ))
      
  row.names(formattedPhenoData) <- formattedPhenoData[, 1]
  formattedPhenoData[, 1]       <- NULL    
} else {
  phenoFile <- grep("\\/phenotype_data", inputFiles, ignore.case = TRUE, value = TRUE, perl = TRUE)

  if (is.null(phenoFile)) {
    stop("phenotype data file is missing.")
  }

  if (file.info(phenoFile)$size == 0) {
    stop("phenotype data file is empty.")
  }
  
  phenoData <- fread(phenoFile, na.strings = c("NA", " ", "--", "-", "."), header = TRUE) 
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
      row.names(phenoTrait) <- phenoTrait[, 1]
      phenoTrait[, 1]       <- NULL
      colnames(phenoTrait)  <- trait
    }
   
} else {

  if (!is.null(formattedPhenoData)) {
    phenoTrait <- subset(formattedPhenoData, select = trait)
    phenoTrait <- na.omit(phenoTrait)
   
  } else {
    dropColumns <- c("uniquename", "stock_name")
    phenoData   <- phenoData[, !(names(phenoData) %in% dropColumns)]
    
    phenoTrait <- subset(phenoData, select = c("object_name", "object_id", "design", "block", "replicate", trait))
   
    experimentalDesign <- phenoTrait[2, 'design']
  
    if (class(phenoTrait[, trait]) != 'numeric') {
      phenoTrait[, trait] <- as.numeric(as.character(phenoTrait[, trait]))
    }
      
    if (is.na(experimentalDesign) == TRUE) {experimentalDesign <- c('No Design')}
    
    if ((experimentalDesign == 'Augmented' || experimentalDesign == 'RCBD')  &&  unique(phenoTrait$block) > 1) {

      message("GS experimental design: ", experimentalDesign)

      augData <- subset(phenoTrait, select = c("object_name", "object_id",  "block",  trait))

      colnames(augData)[1] <- "genotypes"
      colnames(augData)[4] <- "trait"

      model <- try(lmer(trait ~ 0 + genotypes + (1|block),
                        augData,
                        na.action = na.omit))

      if (class(model) != "try-error") {
        phenoTrait <- data.frame(fixef(model))
        
        colnames(phenoTrait) <- trait

        nn <- gsub('genotypes', '', rownames(phenoTrait))  
        rownames(phenoTrait) <- nn
      
        phenoTrait <- round(phenoTrait, digits = 2)
      }
            
    } else if (experimentalDesign == 'Alpha') {
   
      message("Experimental desgin: ", experimentalDesign)
      
      alphaData <- subset(phenoData,
                            select = c("object_name", "object_id","block", "replicate", trait)
                            )
      
      colnames(alphaData)[1] <- "genotypes"
      colnames(alphaData)[5] <- "trait"
         
      model <- try(lmer(trait ~ 0 + genotypes + (1|replicate/block),
                        alphaData,
                        na.action = na.omit))
        
      if (class(model) != "try-error") {
        phenoTrait <- data.frame(fixef(model))
      
        colnames(phenoTrait) <- trait

        nn <- gsub('genotypes', '', rownames(phenoTrait))     
        rownames(phenoTrait) <- nn
      
        phenoTrait <- round(phenoTrait, digits = 2)
        
      }
      
    } else {

      phenoTrait <- subset(phenoData,
                           select = c("object_name", "object_id",  trait))
       
      if (sum(is.na(phenoTrait)) > 0) {
        message("No. of pheno missing values: ", sum(is.na(phenoTrait)))      
        phenoTrait <- na.omit(phenoTrait)
      }

        #calculate mean of reps/plots of the same accession and
        #create new df with the accession means    
     
      phenoTrait   <- phenoTrait[order(row.names(phenoTrait)), ]
      phenoTrait   <- data.frame(phenoTrait)
      message('phenotyped lines before averaging: ', length(row.names(phenoTrait)))
   
      phenoTrait<-ddply(phenoTrait, "object_name", colwise(mean))
      message('phenotyped lines after averaging: ', length(row.names(phenoTrait)))
        
      phenoTrait <- subset(phenoTrait, select = c("object_name", trait))
      row.names(phenoTrait) <- phenoTrait[, 1]
      phenoTrait[, 1] <- NULL
       
        #format all-traits population phenotype dataset
        ## formattedPhenoData <- phenoData
        ## dropColumns <- c("object_id", "stock_id", "design", "block", "replicate" )

        ## formattedPhenoData <- formattedPhenoData[, !(names(formattedPhenoData) %in% dropColumns)]
        ## formattedPhenoData <- ddply(formattedPhenoData,
        ##                             "object_name",
        ##                             colwise(mean)
        ##                             )

        ## row.names(formattedPhenoData) <- formattedPhenoData[, 1]
        ## formattedPhenoData[, 1] <- NULL

        ## formattedPhenoData <- round(formattedPhenoData,
        ##                             digits=3
        ##                             )     
    }
  }
}

if (is.null(filteredGenoData)) {

  #remove markers with > 60% missing marker data
  message('no of markers before filtering out: ', ncol(genoData))
  genoData[, which(colSums(is.na(genoData)) >= nrow(genoData) * 0.6) := NULL]
  message('no of markers after filtering out 60% missing: ', ncol(genoData))

  #remove indls with > 80% missing marker data
  genoData[, noMissing := apply(.SD, 1, function(x) sum(is.na(x)))]
  genoData <- genoData[noMissing <= ncol(genoData) * 0.8]
  genoData[, noMissing := NULL]
  message('no of indls after filtering out ones with 80% missing: ', nrow(genoData))

                                        #remove monomorphic markers
  message('marker no before monomorphic markers cleaning ', ncol(genoData))
  genoData[, which(apply(genoData, 2,  function(x) length(unique(x))) < 2) := NULL ]
  message('marker no after monomorphic markers cleaning ', ncol(genoData))

  ### MAF calculation ###
  calculateMAF <- function(x) {
    a0 <-  length(x[x==0])
    a1 <-  length(x[x==1])
    a2 <-  length(x[x==2])
    aT <- a0 + a1 + a2

    p   <- ((2*a0)+a1)/(2*aT)
    q   <- 1- p
    maf <- min(p, q)
  
    return (maf)

  }

  #remove markers with MAF < 5%
  genoData[, which(apply(genoData, 2,  calculateMAF) < 0.05) := NULL ]
  message('marker no after MAF cleaning ', ncol(genoData))

  genoData           <- as.data.frame(genoData)
  rownames(genoData) <- genoData[, 1]
  genoData[, 1]      <- NULL
  filteredGenoData   <- genoData 
} else {
  genoData           <- as.data.frame(filteredGenoData)
  rownames(genoData) <- genoData[, 1]
  genoData[, 1]      <- NULL
}

predictionTempFile <- grep("prediction_population", inputFiles, ignore.case = TRUE, value = TRUE)
predictionFile     <- c()

message('prediction temp genotype file: ', predictionTempFile)

if (length(predictionTempFile) !=0 ) {
  predictionFile <- scan(predictionTempFile, what = "character")
}

message('prediction genotype file: ', predictionFile)

predictionPopGEBVsFile <- grep("prediction_pop_gebvs", outputFiles, ignore.case = TRUE, value = TRUE)
message("prediction gebv file: ",  predictionPopGEBVsFile)

predictionData <- c()

if (length(predictionFile) !=0 ) {
  
  predictionData <- fread(predictionFile, na.strings = c("NA", " ", "--", "-"),)

  predictionData[, which(apply(predictionData, 2,  function(x) length(unique(x))) < 2) := NULL ]
  
  message('selection population: no of markers before filtering out: ', ncol(genoData))
  predictionData[, which(colSums(is.na(predictionData)) >= nrow(predictionData) * 0.6) := NULL]

  #remove indls with > 80% missing marker data
  predictionData[, noMissing := apply(.SD, 1, function(x) sum(is.na(x)))]
  predictionData <- predictionData[noMissing <= ncol(predictionData) * 0.8]
  predictionData[, noMissing := NULL]
  
  predictionData[, which(apply(predictionData, 2,  calculateMAF) < 0.05) := NULL ]
  message('selection pop marker no after MAF cleaning ', ncol(preditionData))
  predictionData           <- as.data.frame(predictionData)
  rownames(predictionData) <- predictionData[, 1]
  predictionData[, 1]      <- NULL
 
}

#impute genotype values for obs with missing values,
#based on mean of neighbouring 10 (arbitrary) obs
genoDataMissing <- c()

if (sum(is.na(genoData)) > 0) {
  genoDataMissing<- c('yes')

  message("sum of geno missing values, ", sum(is.na(genoData)) )  
  genoData <- na.roughfix(genoData)
  genoData <- data.matrix(genoData)
}

genoData <- genoData[order(row.names(genoData)), ]

#create phenotype and genotype datasets with
#common stocks only
message('phenotyped lines: ', length(row.names(phenoTrait)))
message('genotyped lines: ', length(row.names(genoData)))

#extract observation lines with both
#phenotype and genotype data only.
commonObs <- intersect(row.names(phenoTrait), row.names(genoData))
commonObs <- data.frame(commonObs)
rownames(commonObs)<-commonObs[, 1]

message('lines with both genotype and phenotype data: ', length(row.names(commonObs)))

#include in the genotype dataset only observation lines
#with phenotype data
message("genotype lines before filtering for phenotyped only: ", length(row.names(genoData)))        
genoDataFilteredObs <- genoData[(rownames(genoData) %in% rownames(commonObs)), ]
message("genotype lines after filtering for phenotyped only: ", length(row.names(genoDataFilteredObs)))

#drop observation lines without genotype data
message("phenotype lines before filtering for genotyped only: ", length(row.names(phenoTrait)))        
phenoTrait <- merge(data.frame(phenoTrait), commonObs, by=0, all=FALSE)
rownames(phenoTrait) <- phenoTrait[, 1]
phenoTrait <- subset(phenoTrait, select=trait)

message("phenotype lines after filtering for genotyped only: ", length(row.names(phenoTrait)))
#a set of only observation lines with genotype data

traitPhenoData   <- data.frame(round(phenoTrait, digits = 2))           
phenoTrait       <- data.matrix(phenoTrait)
genoDataFilteredObs <- data.matrix(genoDataFilteredObs)

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

relationshipMatrixFile <- grep("relationship_matrix", outputFiles, ignore.case = TRUE, value = TRUE)

message("relationship matrix file: ", relationshipMatrixFile)

relationshipMatrix <- c()
if (length(relationshipMatrixFile) != 0) {
  if (file.info(relationshipMatrixFile)$size > 0 ) {
    relationshipDf <- as.data.frame(fread(relationshipMatrixFile))

    rownames(relationshipDf) <- relationshipDf[, 1]
    relationshipDf[, 1]      <- NULL
    relationshipMatrix       <- data.matrix(relationshipDf)
  }
}


#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genoTrCode <- grep("2", genoDataFilteredObs[1, ], value = TRUE)
if(length(genoTrCode) != 0) {
  genoDataFilteredObs <- genoDataFilteredObs - 1
}

if (length(predictionData) != 0 ) {
  genoSlCode <- grep("2", predictionData[1, ], value = TRUE)
  if (length(genoSlCode) != 0 ) {
    predictionData <- predictionData - 1
  }
}

ordered.markerEffects <- c()
if ( length(predictionData) == 0 ) {
  markerEffects <- mixed.solve(y = phenoTrait,
                               Z = genoDataFilteredObs
                               )

  ordered.markerEffects <- data.matrix(markerEffects$u)
  ordered.markerEffects <- data.matrix(ordered.markerEffects [order (-ordered.markerEffects[, 1]), ])
  ordered.markerEffects <- round(ordered.markerEffects, digits=5)

  colnames(ordered.markerEffects) <- c("Marker Effects")

}

#additive relationship model
#calculate the inner products for
#genotypes (realized relationship matrix)
if (length(relationshipMatrixFile) != 0) {
  if (file.info(relationshipMatrixFile)$size == 0) {
    relationshipMatrix <- tcrossprod(data.matrix(genoData))
  }
}
relationshipMatrixFiltered <- relationshipMatrix[(rownames(relationshipMatrix) %in% rownames(commonObs)),]
relationshipMatrixFiltered <- relationshipMatrixFiltered[, (colnames(relationshipMatrixFiltered) %in% rownames(commonObs))]

#construct an identity matrix for genotypes
identityMatrix <- diag(nrow(phenoTrait))

relationshipMatrixFiltered <- data.matrix(relationshipMatrixFiltered)

iGEBV  <- mixed.solve(y = phenoTrait, Z = identityMatrix, K = relationshipMatrixFiltered) 
iGEBVu <- iGEBV$u

heritability  <- c()

if ( is.null(predictionFile) == TRUE ) {
  additiveEffects <- data.frame(iGEBVu)
 
  pN <- nrow(phenoTrait)
  aN <- nrow(additiveEffects)

  if (pN <= 1 || pN != aN) {
    stop("phenoTrait and additiveEffects have different lengths: ",
         pN, " and ", aN, ".")
  }
      
  if (TRUE %in% is.na(phenoTrait) || TRUE %in% is.na(additiveEffects)) {
    stop(" Arguments phenoTrait and additiveEffects have missing values.")
  }
  
  phenoVariance <- var(phenoTrait)
  gebvVariance  <- var(additiveEffects)
  heritability  <- round((gebvVariance / phenoVariance), digits = 2)
      
  cat("\n", file = varianceComponentsFile,  append = FALSE)
  cat('Error variance', iGEBV$Ve, file = varianceComponentsFile, sep = "\t", append = TRUE)
  cat("\n", file = varianceComponentsFile,  append = TRUE)
  cat('Additive genetic variance',  iGEBV$Vu, file = varianceComponentsFile, sep = '\t', append = TRUE)
  cat("\n", file = varianceComponentsFile,  append = TRUE)
  cat('Phenotype mean', iGEBV$beta,file = varianceComponentsFile, sep = '\t', append = TRUE)
  cat("\n", file = varianceComponentsFile,  append = TRUE)
  cat('Heritability (h)', heritability, file = varianceComponentsFile, sep = '\t', append = TRUE)
}

iGEBV         <- data.matrix(iGEBVu)
ordered.iGEBV <- as.data.frame(iGEBV[order(-iGEBV[, 1]), ])
ordered.iGEBV <- round(ordered.iGEBV, digits = 3)

combinedGebvsFile <- grep('selected_traits_gebv', outputFiles, ignore.case = TRUE,value = TRUE)

allGebvs<-c()
if (length(combinedGebvsFile) != 0) {
    fileSize <- file.info(combinedGebvsFile)$size
    if (fileSize != 0 ) {
        combinedGebvs <- as.data.frame(fread(combinedGebvsFile))

        rownames(combinedGebvs) <- combinedGebvs[,1]
        combinedGebvs[,1]       <- NULL

        colnames(ordered.iGEBV) <- c(trait)
      
        traitGEBV <- as.data.frame(ordered.iGEBV)
        allGebvs <- merge(combinedGebvs, traitGEBV,
                          by = 0,
                          all = TRUE                     
                          )

        rownames(allGebvs) <- allGebvs[,1]
        allGebvs[,1] <- NULL
     }
  }

colnames(ordered.iGEBV) <- c(trait)
                  
#cross-validation
validationAll <- c()

if(is.null(predictionFile)) {
  genoNum <- nrow(phenoTrait)
if(genoNum < 20 ) {
  warning(genoNum, " is too small number of genotypes.")
}
  
reps <- round_any(genoNum, 10, f = ceiling) %/% 10

genotypeGroups <-c()

if (genoNum %% 10 == 0) {
    genotypeGroups <- rep(1:10, reps)
  } else {
    genotypeGroups <- rep(1:10, reps) [- (genoNum %% 10) ]
  }

set.seed(4567)                                   
genotypeGroups <- genotypeGroups[ order (runif(genoNum)) ]

for (i in 1:10) {
  tr <- paste("trPop", i, sep = ".")
  sl <- paste("slPop", i, sep = ".")
 
  trG <- which(genotypeGroups != i)
  slG <- which(genotypeGroups == i)
  
  assign(tr, trG)
  assign(sl, slG)

  kblup <- paste("rKblup", i, sep = ".")
  
  result <- kinship.BLUP(y = phenoTrait[trG, ],
                         G.train = genoDataFilteredObs[trG, ],
                         G.pred = genoDataFilteredObs[slG, ],                      
                         mixed.method = "REML",
                         K.method = "RR",
                         )
 
  assign(kblup, result)

#calculate cross-validation accuracy  
  valCorData <- merge(phenoTrait[slG, ], result$g.pred, by=0, all=FALSE)
  rownames(valCorData) <- valCorData[, 1]
  valCorData[, 1]      <- NULL
 
  accuracy <- try(cor(valCorData))
  validation <- paste("validation", i, sep = ".")

  cvTest <- paste("Validation test", i, sep = " ")

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

validationAll <- data.matrix(validationAll[order(-validationAll[, 1]), ])
     
if (!is.null(validationAll)) {
    validationMean <- data.matrix(round(colMeans(validationAll), digits = 2))
   
    rownames(validationMean) <- c("Average")
     
    validationAll <- rbind(validationAll, validationMean)
    colnames(validationAll) <- c("Correlation")
  }
}

predictionPopResult <- c()
predictionPopGEBVs  <- c()

if (length(predictionData) != 0) {
    message("running prediction for selection candidates...marker data", ncol(predictionData), " vs. ", ncol(genoDataFilteredObs))

    predictionPopResult <- kinship.BLUP(y = phenoTrait,
                                        G.train = genoDataFilteredObs,
                                        G.pred = predictionData,
                                        mixed.method = "REML",
                                        K.method = "RR"
                                        )
 message("running prediction for selection candidates...DONE!!")

    predictionPopGEBVs <- round(data.matrix(predictionPopResult$g.pred), digits = 3)
    predictionPopGEBVs <- data.matrix(predictionPopGEBVs[order(-predictionPopGEBVs[, 1]), ])
   
    colnames(predictionPopGEBVs) <- c(trait)
  
}

if (!is.null(predictionPopGEBVs) & length(predictionPopGEBVsFile) != 0)  {
    write.table(predictionPopGEBVs,
                file = predictionPopGEBVsFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if(!is.null(validationAll)) {
    write.table(validationAll,
                file = validationFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if (!is.null(ordered.markerEffects)) {
    write.table(ordered.markerEffects,
                file = markerFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if (!is.null(ordered.iGEBV)) {
    write.table(ordered.iGEBV,
                file = blupFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if (length(combinedGebvsFile) != 0 ) {
    if(file.info(combinedGebvsFile)$size == 0) {
        write.table(ordered.iGEBV,
                    file = combinedGebvsFile,
                    sep = "\t",
                    col.names = NA,
                    quote = FALSE,
                    )
      } else {
      write.table(allGebvs,
                  file = combinedGebvsFile,
                  sep = "\t",
                  quote = FALSE,
                  col.names = NA,
                  )
    }
}

if (!is.null(traitPhenoData) & length(traitPhenoFile) != 0) {
    write.table(traitPhenoData,
                file = traitPhenoFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                )
}

if (!is.null(filteredGenoData) && is.null(usedFilteredGenoData)) {
  write.table(filteredGenoData,
              file = filteredGenoFile,
              sep = "\t",
              col.names = NA,
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
  write.table(relationshipMatrix,
              file = relationshipMatrixFile,
              sep = "\t",
              col.names = NA,
              quote = FALSE,
              )
}


if (file.info(formattedPhenoFile)$size == 0 && !is.null(formattedPhenoData) ) {
  write.table(formattedPhenoData,
              file = formattedPhenoFile,
              sep = "\t",
              col.names = NA,
              quote = FALSE,
              )
}

message("Done.")

q(save = "no", runLast = FALSE)
