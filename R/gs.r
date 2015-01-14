#a script for calculating genomic
#estimated breeding values (GEBVs) using rrBLUP

options(echo = FALSE)

library(rrBLUP)
library(plyr)
library(mail)
library(imputation)
library(stringr)
library(nlme)


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

inFiles <- scan(inFile,
                what = "character"
                )


traitsFile <- grep("traits",
                   inFiles,
                   ignore.case = TRUE,
                   fixed = FALSE,
                   value = TRUE
                   )

traitFile <- grep("trait_info",
                   inFiles,
                   ignore.case = TRUE,
                   fixed = FALSE,
                   value = TRUE
                  )


traitInfo <- scan(traitFile,
               what = "character",
               )

traitInfo <- strsplit(traitInfo, "\t");
traitId   <- traitInfo[[1]]
trait     <- traitInfo[[2]]

datasetInfoFile <- grep("dataset_info",
                        inFiles,
                        ignore.case = TRUE,
                        fixed = FALSE,
                        value = TRUE
                        )
datasetInfo <- c()

if(length(datasetInfoFile) != 0 ) {
    datasetInfo <- scan(datasetInfoFile,
                        what= "character"
                        )
    
    datasetInfo <- paste(datasetInfo, collapse = " ")
    
  } else {    
    datasetInfo <- c('single population')
    
  }

validationTrait <- paste("validation", trait, sep = "_")

validationFile  <- grep(validationTrait,
                        outFiles,
                        ignore.case=TRUE,
                        fixed = FALSE,
                        value=TRUE
                        )

kinshipTrait <- paste("kinship", trait, sep = "_")

blupFile <- grep(kinshipTrait,
                 outFiles,
                 ignore.case = TRUE,
                 fixed = FALSE,
                 value = TRUE
                 )

markerTrait <- paste("marker", trait, sep = "_")
markerFile  <- grep(markerTrait,
                   outFiles,
                   ignore.case = TRUE,
                   fixed = FALSE,
                   value = TRUE
                   )

traitPhenoFile <- paste("phenotype_trait", trait, sep = "_")
traitPhenoFile <- grep(traitPhenoFile,
                       outFiles,
                       ignore.case = TRUE,
                       fixed = FALSE,
                       value = TRUE
                       )


formattedPhenoDataFile <- grep("formatted_phenotype_data",
                               outFiles,
                               ignore.case = TRUE,
                               fixed = FALSE,
                               value = TRUE
                               )

varianceComponentsFile <- grep("variance_components",
                               outFiles,
                               ignore.case = TRUE,
                               fixed = FALSE,
                               value = TRUE
                               )

phenoFile <- grep("phenotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )

message("phenotype dataset file: ", phenoFile)
message("dataset info: ", datasetInfo)

#phenoFile <- c("/home/tecle/Desktop/phenotype_data_176_augmented.txt")
message("phenotype dataset file: ", phenoFile)
phenoData <- read.table(phenoFile,
                        header = TRUE,
                        row.names = NULL,
                        sep = "\t",
                        na.strings = c("NA", " ", "--", "-", "."),
                        dec = "."
                        )

phenoTrait         <- c()
formattedPhenoData <- c()

if (datasetInfo == 'combined populations') {  
    dropColumns <- grep(trait,
                        names(phenoData),
                        ignore.case = TRUE,
                        value = TRUE,
                        fixed = FALSE
                        )

    phenoTrait <- phenoData[,!(names(phenoData) %in% dropColumns)]
   
    phenoTrait <- as.data.frame(phenoTrait)
    row.names(phenoTrait) <- phenoTrait[, 1]
    phenoTrait[, 1] <- NULL
    colnames(phenoTrait) <- trait

  } else {

    dropColumns <- c("uniquename", "stock_name")
    phenoData   <- phenoData[,!(names(phenoData) %in% dropColumns)]
    
    phenoTrait <- subset(phenoData,
                          select = c("object_name", "object_id", "design", "block", "replicate", trait)
                          )
   
    experimentalDesign <- phenoTrait[2, 'design']
    if (is.na(experimentalDesign) == TRUE) {experimentalDesign <- c('No Design')}
    
    if (experimentalDesign == 'augmented' || experimentalDesign == 'RCBD') {
      message("experimental design: ", experimentalDesign)

      augData <- subset(phenoData,
                        select = c("object_name", "object_id",  "block",  trait)
                        )

      colnames(augData)[1] <- "genotypes"
      colnames(augData)[4] <- "trait"
    
      ff <- trait ~ 0 + genotypes
    
      model <- lme(ff,
                   data=augData,
                   random = ~1|block,
                   method="REML",
                   na.action = na.omit
                   )
   
      adjMeans <- data.matrix(fixed.effects(model))
     
      colnames(adjMeans) <- trait
      
      nn <- gsub('genotypes', '', rownames(adjMeans))
      rownames(adjMeans) <- nn
      adjMeans <- round(adjMeans, digits = 2)

      phenoTrait <- data.frame(adjMeans)
      
    } else if (experimentalDesign == 'alpha') {
      message("experimental design: ", experimentalDesign)

      alphaData <-   subset(phenoData,
                            select = c("object_name", "object_id", "block", "replicate", trait)
                            )
      
      colnames(alphaData)[2] <- "genotypes"
      colnames(alphaData)[5] <- "trait"
     
      ff <- trait ~ 0 + genotypes
      
      model <- lme(ff,
                   data=alphaData,
                   random = ~1|replicate/block,
                   method="REML",
                   na.action = na.omit
                   )
   
      adjMeans <- data.matrix(fixed.effects(model))
      colnames(adjMeans) <- trait
      
      nn <- gsub('genotypes', '', rownames(adjMeans))
      rownames(adjMeans) <- nn
      adjMeans <- round(adjMeans, digits = 2)

      phenoTrait <- data.frame(adjMeans)

    } else {

      phenoTrait <- subset(phenoData,
                           select = c("object_name", "object_id",  trait)
                           )
       
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
     
      row.names(phenoTrait) <- phenoTrait[, 1]
      phenoTrait[, 1] <- NULL

    #format all-traits population phenotype dataset
      formattedPhenoData <- phenoData
      dropColumns <- c("object_id", "stock_id", "design", "block", "replicate" )

      formattedPhenoData <- formattedPhenoData[, !(names(formattedPhenoData) %in% dropColumns)]
      formattedPhenoData <- ddply(formattedPhenoData,
                                  "object_name",
                                  colwise(mean)
                                  )

      row.names(formattedPhenoData) <- formattedPhenoData[, 1]
      formattedPhenoData[, 1] <- NULL

      formattedPhenoData <- round(formattedPhenoData,
                                  digits=2
                                  )     
    }
  }

genoFile <- grep("genotype_data",
                 inFiles,
                 ignore.case = TRUE,                
                 fixed = FALSE,
                 value = TRUE
                 )

genoData <- read.table(genoFile,
                       header = TRUE,
                       row.names = 1,
                       sep = "\t",
                       na.strings = c("NA", " ", "--", "-"),
                       dec = "."
                      )

genoData   <- data.matrix(genoData[order(row.names(genoData)), ])

predictionTempFile <- grep("prediction_population",
                       inFiles,
                       ignore.case = TRUE,
                       fixed = FALSE,
                       value = TRUE
                       )

predictionFile <- c()
message('prediction temp genotype file: ', predictionTempFile)
if (length(predictionTempFile) !=0 ) {
    predictionFile <- scan(predictionTempFile,
                       what="character"
                       )
}

message('prediction genotype file: ', predictionFile)
predictionPopGEBVsFile <- grep("prediction_pop_gebvs",
                       outFiles,
                       ignore.case = TRUE,
                       fixed = FALSE,
                       value = TRUE
                       )

message("prediction gebv file: ",  predictionPopGEBVsFile)


predictionData <- c()

if (length(predictionFile) !=0 )
  {
    predictionData <- read.table(predictionFile,
                       header = TRUE,
                       row.names = 1,
                       sep = "\t",
                       na.strings = c("NA", " ", "--", "-"),
                       dec = "."
                      )
  }

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
genoData<-genoData[(rownames(genoData) %in% rownames(commonObs)), ]
message("genotype lines after filtering for phenotyped only: ", length(row.names(genoData)))
#drop observation lines without genotype data
message("phenotype lines before filtering for genotyped only: ", length(row.names(phenoTrait)))        

phenoTrait <- merge(data.frame(phenoTrait), commonObs, by=0, all=FALSE)
rownames(phenoTrait) <-phenoTrait[, 1]
phenoTrait <- subset(phenoTrait, select=trait)

message("phenotype lines after filtering for genotyped only: ", length(row.names(phenoTrait)))

#a set of only observation lines with genotype data
traitPhenoData <- as.data.frame(round(phenoTrait, digits=2))           
phenoTrait     <- data.matrix(phenoTrait)
genoDataMatrix <- data.matrix(genoData)

#impute genotype values for obs with missing values,
#based on mean of neighbouring 10 (arbitrary) obs
if (sum(is.na(genoDataMatrix)) > 0) {
    message("sum of geno missing values, ", sum(is.na(genoDataMatrix)) )
    genoDataMatrix <-kNNImpute(genoDataMatrix, 10)
    genoDataMatrix <-as.data.frame(genoDataMatrix)

    #extract columns with imputed values
    genoDataMatrix <- subset(genoDataMatrix,
                         select = grep("^x", names(genoDataMatrix))
                )

    #remove prefix 'x.' from imputed columns
    names(genoDataMatrix) <- sub("x.", "", names(genoDataMatrix))

    genoDataMatrix <- round(genoDataMatrix, digits = 0)
    genoDataMatrix <- data.matrix(genoDataMatrix)
  }

#impute missing data in prediction data
if (length(predictionData) != 0) {

  #purge markers unique to both populations
  commonMarkers  <- intersect(names(data.frame(genoDataMatrix)), names(predictionData))
  predictionData <- subset(predictionData, select = commonMarkers)
  genoDataMatrix <- subset(genoDataMatrix, select= commonMarkers)
  
  predictionData <- data.matrix(predictionData)
 
  if (sum(is.na(predictionData)) > 0) {
    message("sum of geno missing values in prediction data: ", sum(is.na(predictionData)) )
    predictionData <-kNNImpute(predictionData, 10)
    predictionData <-as.data.frame(predictionData)

    #extract columns with imputed values
    predictionData <- subset(predictionData,
                             select = grep("^x", names(predictionData))
                             )

    #remove prefix 'x.' from imputed columns
    names(predictionData) <- sub("x.", "", names(predictionData))

    predictionData <- round(predictionData, digits = 0)
    predictionData <- data.matrix(predictionData)
  }

}

#change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
genoTrCode <- grep("2", genoDataMatrix[1, ], fixed=TRUE, value=TRUE)
if(length(genoTrCode) != 0) {
  genoDataMatrix <- genoDataMatrix - 1
}

if (length(predictionData) != 0 ) {
  genoSlCode <- grep("2", predictionData[1, ], fixed=TRUE, value=TRUE)
  if (length(genoSlCode) != 0 ) {
    predictionData <- predictionData - 1
  }
}

#use REML (default) to calculate variance components
#calculate GEBV using marker effects (as random effects)
markerGEBV <- mixed.solve(y = phenoTrait,
                          Z = genoDataMatrix
                         )

ordered.markerGEBV2 <- data.matrix(markerGEBV$u)
ordered.markerGEBV2 <- data.matrix(ordered.markerGEBV2 [order (-ordered.markerGEBV2[, 1]), ])
ordered.markerGEBV2 <- round(ordered.markerGEBV2,
                             digits=5
                             )

colnames(ordered.markerGEBV2) <- c("Marker Effects")

#additive relationship model
#calculate the inner products for
#genotypes (realized relationship matrix)
genocrsprd <- tcrossprod(genoDataMatrix)

#construct an identity matrix for genotypes
identityMatrix <- diag(nrow(phenoTrait))
                  
iGEBV <- mixed.solve(y = phenoTrait,
                     Z = identityMatrix,
                     K = genocrsprd
                     )
 
#correlation between breeding values based on
#marker effects and relationship matrix
corGEBVs <- cor(genoDataMatrix %*% markerGEBV$u, iGEBV$u)

iGEBVu <- iGEBV$u

heritability <- c()
if ( is.null(predictionFile) == TRUE ) {
    heritability <- round((iGEBV$Vu /(iGEBV$Vu + iGEBV$Ve)) * 100, digits=2)
    cat("\n", file=varianceComponentsFile,  append=TRUE)
    cat('Error variance', iGEBV$Ve, file=varianceComponentsFile, sep="\t", append=TRUE)
    cat("\n", file=varianceComponentsFile,  append=TRUE)
    cat('Additive genetic variance',  iGEBV$Vu, file=varianceComponentsFile, sep='\t', append=TRUE)
    cat("\n", file=varianceComponentsFile,  append=TRUE)
    cat('&#956;', iGEBV$beta,file=varianceComponentsFile, sep='\t', append=TRUE)
    cat("\n", file=varianceComponentsFile,  append=TRUE)
    cat('Heritability (h, %)', heritability, file=varianceComponentsFile, sep='\t', append=TRUE)
}

iGEBV <- data.matrix(iGEBVu)

ordered.iGEBV <- as.data.frame(iGEBV[order(-iGEBV[, 1]), ] )

ordered.iGEBV <- round(ordered.iGEBV,
                       digits = 3
                       )

combinedGebvsFile <- grep('selected_traits_gebv',
                          outFiles,
                          ignore.case = TRUE,
                          fixed = FALSE,
                          value = TRUE
                          )

allGebvs<-c()
if (length(combinedGebvsFile) != 0)
  {
    fileSize <- file.info(combinedGebvsFile)$size
    if (fileSize != 0 )
      {
        combinedGebvs<-read.table(combinedGebvsFile,
                                  header = TRUE,
                                  row.names = 1,
                                  dec = ".",
                                  sep = "\t"
                                  )

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

if(is.null(predictionFile) == TRUE) {
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



for (i in 1:reps)
{
  tr <- paste("trPop", i, sep = ".")
  sl <- paste("slPop", i, sep = ".")
 
  trG <- which(genotypeGroups != i)
  slG <- which(genotypeGroups == i)
 
  assign(tr, trG)
  assign(sl, slG)

  kblup <- paste("rKblup", i, sep = ".")
  
  result <- kinship.BLUP(y = phenoTrait[trG],
                         G.train = genoDataMatrix[trG, ],
                         G.pred = genoDataMatrix[slG, ],                      
                         mixed.method = "REML",
                         K.method = "RR",
                         )
 
  assign(kblup, result)
 
#calculate cross-validation accuracy
  accuracy <- try(cor(result$g.pred, phenoTrait[slG]))

  validation <- paste("validation", i, sep = ".")

  cvTest <- paste("Test", i, sep = " ")

  if (class(accuracy) != "try-error")
    {
      accuracy <- round(accuracy, digits = 2)
      accuracy <- data.matrix(accuracy)

      colnames(accuracy) <- c("correlation")
      rownames(accuracy) <- cvTest
    
      assign(validation, accuracy)

      validationAll <- rbind(validationAll, accuracy)
    }
}

validationAll <- data.matrix(validationAll)
validationAll <- data.matrix(validationAll[order(-validationAll[, 1]), ])
     
if (is.null(validationAll) == FALSE) {
    validationMean <- data.matrix(round(colMeans(validationAll),
                                      digits = 2
                                      )
                                )
   
    rownames(validationMean) <- c("Average")
     
    validationAll <- rbind(validationAll, validationMean)
    colnames(validationAll) <- c("Correlation")
  }
}
#predict GEBVs for selection population
if (length(predictionData) !=0 ) {
    predictionData <- data.matrix(round(predictionData, digits = 0 ))
  }

predictionPopResult <- c()
predictionPopGEBVs  <- c()

if(length(predictionData) != 0) {
    message("running prediction for selection candidates...marker data", ncol(predictionData), " vs. ", ncol(genoDataMatrix))

    predictionPopResult <- kinship.BLUP(y = phenoTrait,
                                        G.train = genoDataMatrix,
                                        G.pred = predictionData,
                                        mixed.method = "REML",
                                        K.method = "RR"
                                        )
 message("running prediction for selection candidates...DONE!!")

    predictionPopGEBVs <- round(data.matrix(predictionPopResult$g.pred), digits = 2)
    predictionPopGEBVs <- data.matrix(predictionPopGEBVs[order(-predictionPopGEBVs[, 1]), ])
   
    colnames(predictionPopGEBVs) <- c(trait)
  
}

if(!is.null(predictionPopGEBVs) & length(predictionPopGEBVsFile) != 0)  {
    write.table(predictionPopGEBVs,
                file = predictionPopGEBVsFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if(is.null(validationAll) == FALSE) {
    write.table(validationAll,
                file = validationFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if(is.null(ordered.markerGEBV2) == FALSE) {
    write.table(ordered.markerGEBV2,
                file = markerFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if(is.null(ordered.iGEBV) == FALSE) {
    write.table(ordered.iGEBV,
                file = blupFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

if(length(combinedGebvsFile) != 0 ) {
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

if(!is.null(traitPhenoData) & length(traitPhenoFile) != 0) {
    write.table(traitPhenoData,
                file = traitPhenoFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}


if(!is.null(formattedPhenoData) & length(formattedPhenoDataFile) != 0) {
    write.table(formattedPhenoData,
                file = formattedPhenoDataFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
}

#should also send notification to analysis owner
to      <- c("<iyt2@cornell.edu>")
subject <- paste(trait, ' GS analysis done', sep = ':')
body    <- c("Dear User,\n\n")
body    <- paste(body, 'The genomic selection analysis for', sep = "")
body    <- paste(body, trait, sep = " ")
body    <- paste(body, "is done.\n\nRegards and Thanks.\nSGN", sep = " ")

#should use SGN's smtp server eventually
sendmail(to,  subject, body, password = "rmail")

q(save = "no", runLast = FALSE)
