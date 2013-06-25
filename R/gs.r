#a script for calculating genomic
#estimated breeding values (GEBVs) using rrBLUP

options(echo = FALSE)

library(rrBLUP)
library(plyr)
library(mail)
library(imputation)
library(stringr)

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
print(outFiles)

inFiles <- scan(inFile,
                what = "character"
                )
print(inFiles)

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

print(traitFile)

traitInfo <- scan(traitFile,
               what = "character",
               )

traitInfo<-strsplit(traitInfo, "\t");
traitId<-traitInfo[[1]]
trait<-traitInfo[[2]]

datasetInfoFile <- grep("dataset_info",
                        inFiles,
                        ignore.case = TRUE,
                        fixed = FALSE,
                        value = TRUE
                        )
datasetInfo <- c()

if(length(datasetInfoFile) != 0 )
  {
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
print(blupFile)
markerTrait <- paste("marker", trait, sep = "_")
markerFile  <- grep(markerTrait,
                   outFiles,
                   ignore.case = TRUE,
                   fixed = FALSE,
                   value = TRUE
                   )
print(markerFile)
traitPhenoFile <- paste("phenotype_trait", trait, sep = "_")
traitPhenoFile <- grep(traitPhenoFile,
                       outFiles,
                       ignore.case = TRUE,
                       fixed = FALSE,
                       value = TRUE
                       )

print(traitPhenoFile)

phenoFile <- grep("phenotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )
message("phenotype dataset file: ", phenoFile)
message("dataset info: ", datasetInfo)
## rowNamesColumn <- c()
## if (datasetInfo == 'combined populations')
##   {
##     rowNamesColumn <- 1    
##   }else {
##     rowNamesColumn <- NULL  
##   }
## message("row names column: ", rowNamesColumn)
phenoData <- read.table(phenoFile,
                        header = TRUE,
                        row.names = NULL,
                        sep = "\t",
                        na.strings = c("NA", " ", "--", "-"),
                        dec = "."
                        )

phenoTrait <- c()

if (datasetInfo == 'combined populations')
  {  
    dropColumns <- grep(trait,
                        names(phenoData),
                        ignore.case = TRUE,
                        value = TRUE,
                        fixed = FALSE
                        )
    
    phenoTrait <- phenoData[,!(names(phenoData) %in% dropColumns)]
   
    row.names(phenoTrait) <- phenoTrait[, 1]
    phenoTrait[, 1] <- NULL
    
    print(phenoTrait[1:10, ])

  } else {
   
    dropColumns <- c("uniquename", "stock_name")
    phenoData   <- phenoData[,!(names(phenoData) %in% dropColumns)]
    phenoTrait  <- subset(phenoData,
                     select = c("object_name", "stock_id", trait)
                     )
   
    if (sum(is.na(phenoTrait)) > 0)
      {
        print("sum of pheno missing values")
        print(sum(is.na(phenoTrait)))

        #fill in for missing data with mean value
        phenoTrait[, trait]  <- replace (phenoTrait[, trait],
                                         is.na(phenoTrait[, trait]),
                                         mean(phenoTrait[, trait], na.rm =TRUE)
                                         ) 
      }

    #calculate mean of reps/plots of the same accession and
    #create new df with the accession means
    dropColumns  <- c("stock_id")
    phenoTrait   <- phenoTrait[,!(names(phenoTrait) %in% dropColumns)]
    phenoTrait   <- phenoTrait[order(row.names(phenoTrait)), ]
    phenoTrait   <- data.frame(phenoTrait)
    print('phenotyped lines before averaging')
    print(length(row.names(phenoTrait)))
    phenoTrait<-ddply(phenoTrait, "object_name", colwise(mean))
    print('phenotyped lines after averaging')
    print(length(row.names(phenoTrait)))

    #make stock_names row names
    row.names(phenoTrait) <- phenoTrait[, 1]
    phenoTrait[, 1] <- NULL
    
  }


genoFile <- grep("genotype_data",
                 inFiles,
                 ignore.case = TRUE,                
                 fixed = FALSE,
                 value = TRUE
                 )

print(genoFile)

if (trait == 'FHB' || trait == 'DON')
  {
    genoFile <- c("~/cxgn/sgn-home/isaak/GS/barley/cap123_geno_training.txt")
  }

genoData <- read.table(genoFile,
                       header = TRUE,
                       row.names = 1,
                       sep = "\t",
                       na.strings = c("NA", " ", "--", "-"),
                       dec = "."
                      )

genoData   <- data.matrix(genoData[order(row.names(genoData)), ])
print(genoData[1:10, 1:4])

predictionTempFile <- grep("prediction_population",
                       inFiles,
                       ignore.case = TRUE,
                       fixed = FALSE,
                       value = TRUE
                       )

predictionFile <- c()

if (length(predictionTempFile) !=0 )
  {
    predictionFile <- scan(predictionTempFile,
                       what="character"
                       )
}

predictionPopGEBVsFile <- grep("prediction_pop_gebvs",
                       outFiles,
                       ignore.case = TRUE,
                       fixed = FALSE,
                       value = TRUE
                       )

if (trait == 'FHB' || trait == 'DON')
  {
    predictionFile <- c("~/cxgn/sgn-home/isaak/GS/barley/cap123_geno_prediction.txt")
  }

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

#add checks for all input data
#create phenotype and genotype datasets with
#common stocks only
message('phenotyped lines: ', length(row.names(phenoTrait)))
message('genotyped lines: ', length(row.names(genoData)))

#extract observation lines with both
#phenotype and genotype data only.
commonObs <- intersect(row.names(phenoTrait), row.names(genoData))
commonObs<-data.frame(commonObs)
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
rownames(phenoTrait) <-phenoTrait[,1]
phenoTrait[, 1] <- NULL
phenoTrait[, 2] <- NULL

message("phenotype lines after filtering for genotyped only: ", length(row.names(phenoTrait)))

#a set of only observation lines with genotype data
traitPhenoData <- as.data.frame(round(phenoTrait, digits=2))

#if (length(genotypesDiff) > 0)
#  stop("Genotypes in the phenotype and genotype datasets don't match.")
                
phenoTrait     <- data.matrix(phenoTrait)
genoDataMatrix <- data.matrix(genoData)

#impute genotype values for obs with missing values,
#based on mean of neighbouring 10 (arbitrary) obs
if (sum(is.na(genoDataMatrix)) > 0)
  {
    print("sum of geno missing values")
    print(sum(is.na(genoDataMatrix)))
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
if (length(predictionData) != 0)
  {
    predictionData <- data.matrix(predictionData)
    print('before imputation prediction data')
    print(predictionData[1:10, 1:4])
    if (sum(is.na(predictionData)) > 0)
      {
        print("sum of geno missing values")
        print(sum(is.na(predictionData)))
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

#change genotype coding to [-1, 0, 1], to use the A.mat )
genoDataMatrix <- genoDataMatrix - 1

if (length(predictionData) != 0)
  {
    predictionData <- predictionData - 1
  }

#use REML (default) to calculate variance components

#calculate GEBV using marker effects (as random effects)
markerGEBV <- mixed.solve(y = phenoTrait,
                          Z = genoDataMatrix
                         )

ordered.markerGEBV2 <- data.matrix(markerGEBV$u)
ordered.markerGEBV2 <- data.matrix(ordered.markerGEBV2 [order (-ordered.markerGEBV2[, 1]), ])
ordered.markerGEBV2 <- round(ordered.markerGEBV2,
                             digits=3
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
#iGEBVu<-iGEBVu[order(-ans$u), ]
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
          
#TO-DO:account for minor allele frequency                
                     
#cross-validation

reps <- round_any(nrow(phenoTrait), 10, f = ceiling) %/% 10

genotypeGroups <- rep(1:10, reps) [- (nrow(phenoTrait) %% 10)]

set.seed(4567)                                   
genotypeGroups <- genotypeGroups[order (runif(nrow(phenoTrait))) ]                     

validationAll <- c()

for (i in 1:10)
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
                         K.method = "RR"
                         )
print("BLUP for prediction pop")
#print(result)
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
     
if (is.null(validationAll) == FALSE)
  {
    validationMean <- data.matrix(round(colMeans(validationAll),
                                      digits = 2
                                      )
                                )
   
    rownames(validationMean) <- c("Average")
     
    validationAll <- rbind(validationAll, validationMean)
    colnames(validationAll) <- c("Correlation")
  }

#predict GEBVs for selection population
if (length(predictionData) !=0 )
  {
    predictionData <- data.matrix(round(predictionData, digits = 0 ))
    print(predictionData[1:10, 1:20])
  }

predictionPopResult <- c()
predictionPopGEBVs  <- c()

if(length(predictionData) != 0)
  {
    predictionPopResult <- kinship.BLUP(y = phenoTrait,
                                        G.train = genoDataMatrix,
                                        G.pred = predictionData,
                                        mixed.method = "REML",
                                        K.method = "RR"
                                        )

    predictionPopGEBVs <- round(data.matrix(predictionPopResult$g.pred), digits = 2)
    predictionPopGEBVs <- data.matrix(predictionPopGEBVs[order(-predictionPopGEBVs[, 1]), ])

   
    colnames(predictionPopGEBVs) <- c(trait)
  
  }


if(!is.null(predictionPopGEBVs) & length(predictionPopGEBVsFile) != 0)  
  {
    write.table(predictionPopGEBVs,
                file = predictionPopGEBVsFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
  }

if(is.null(validationAll) == FALSE)
  {
    write.table(validationAll,
                file = validationFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
  }

if(is.null(ordered.markerGEBV2) == FALSE)
  {
    write.table(ordered.markerGEBV2,
                file = markerFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
  }

if(is.null(ordered.iGEBV) == FALSE)
  {
    write.table(ordered.iGEBV,
                file = blupFile,
                sep = "\t",
                col.names = NA,
                quote = FALSE,
                append = FALSE
                )
  }

if(length(combinedGebvsFile) != 0 )
  {
    if(file.info(combinedGebvsFile)$size == 0)
      {
        write.table(ordered.iGEBV,
                    file = combinedGebvsFile,
                    sep = "\t",
                    col.names = NA,
                    quote = FALSE,
                    )
      }else
    {
      write.table(allGebvs,
                  file = combinedGebvsFile,
                  sep = "\t",
                  quote = FALSE,
                  col.names = NA,
                  )
    }
  }

if(!is.null(traitPhenoData) & length(traitPhenoFile) != 0)  
  {
    write.table(traitPhenoData,
                file = traitPhenoFile,
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
