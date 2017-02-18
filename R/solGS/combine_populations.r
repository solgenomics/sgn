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
  popId <- str_extract(allPhenoFiles[[popPhenoNum]], "\\d+")
  popIds <- append(popIds, popId)

  phenoData <- fread(allPhenoFiles[[popPhenoNum]],
                            na.strings = c("NA", " ", "--", "-", "."),
                           )
  phenoTrait <- subset(phenoData,
                       select = c("object_name", "object_id", "design", "block", "replicate", traitName)
                       )
  phenoTrait  <- as.data.frame(phenoTrait)
  
  experimentalDesign <- phenoTrait[2, 'design']
    
  if (is.na(experimentalDesign) == TRUE) {experimentalDesign <- c('No Design')}

  if ((experimentalDesign == 'Augmented' || experimentalDesign == 'RCBD')  &&  length(phenoTrait$block) > 1) { 

    message("experimental design: ", experimentalDesign)

    augData <- subset(phenoTrait,
                      select = c("object_name", "object_id",  "block",  traitName)
                      )

    colnames(augData)[1] <- "genotypes"
    colnames(augData)[4] <- "trait"

    model <- try(lmer(trait ~ 0 + genotypes + (1|block),
                      augData,
                      na.action = na.omit
                      ))
     
    if (class(model) != "try-error") {
      phenoTrait <- data.frame(fixef(model))
        
      colnames(phenoTrait) <- traitName

      nn <- gsub('genotypes', '', rownames(phenoTrait))  
      rownames(phenoTrait) <- nn
      
      phenoTrait <- round(phenoTrait,  2)
    }      
  } else if ((experimentalDesign == 'CRD')  &&  length(unique(phenoData$replicate)) > 1) {

    message("GS experimental design: ", experimentalDesign)

    crdData <- subset(phenoData, select = c("object_name", "object_id",  "replicate",  trait))

    colnames(crdData)[1] <- "genotypes"
    colnames(crdData)[4] <- "trait"

    model <- try(lmer(trait ~ 0 + genotypes + (1|replicate),
                        crdData,
                        na.action = na.omit))

    if (class(model) != "try-error") {
      phenoTrait <- data.frame(fixef(model))
        
      colnames(phenoTrait) <- trait

      nn <- gsub('genotypes', '', rownames(phenoTrait))  
      rownames(phenoTrait) <- nn
      
      phenoTrait           <- round(phenoTrait, 2)       
  
    }
  } else if (experimentalDesign == 'Alpha') {

    message("experimental design: ", experimentalDesign)
     
    alphaData <- subset(phenoData,
                        select = c("object_name", "object_id", "block", "replicate", traitName)
                        )
      
    colnames(alphaData)[1] <- "genotypes"
    colnames(alphaData)[5] <- "trait"
   
    model <- try(lmer(trait ~ 0 + genotypes + (1|replicate/block),
                      alphaData,
                      na.action = na.omit
                      ))
        
    if (class(model) != "try-error") {
      phenoTrait <- data.frame(fixef(model))
      
      colnames(phenoTrait) <- traitName
        
      nn <- gsub('genotypes', '', rownames(phenoTrait))     
      rownames(phenoTrait) <- nn
      
      phenoTrait <- round(phenoTrait, 2)
    }      
  } else {

    phenoTrait <- subset(phenoData,
                         select = c("object_name", "stock_id", traitName)
                         )
    
    if (sum(is.na(phenoTrait)) > 0) {
      message("No. of pheno missing values: ", sum(is.na(phenoTrait))) 
     
      phenoTrait <- na.omit(phenoTrait)
       
      #calculate mean of reps/plots of the same accession and
      #create new df with the accession means
      phenoTrait$stock_id <- NULL
      phenoTrait   <- phenoTrait[order(row.names(phenoTrait)), ]
   
      print('phenotyped lines before averaging')
      print(length(row.names(phenoTrait)))
        
      phenoTrait<-ddply(phenoTrait, "object_name", colwise(mean))
        
      print('phenotyped lines after averaging')
      print(length(row.names(phenoTrait)))
   
      row.names(phenoTrait) <- phenoTrait[, 1]
      phenoTrait[, 1] <- NULL

      phenoTrait <- round(phenoTrait, 2)

    } else {
      print ('No missing data')
      phenoTrait$stock_id <- NULL
      phenoTrait   <- phenoTrait[order(row.names(phenoTrait)), ]
   
      print('phenotyped lines before averaging')
      print(length(row.names(phenoTrait)))
      
      phenoTrait<-ddply(phenoTrait, "object_name", colwise(mean))
      
      print('phenotyped lines after averaging')
      print(length(row.names(phenoTrait)))

      row.names(phenoTrait) <- phenoTrait[, 1]
      phenoTrait[, 1] <- NULL

      phenoTrait <- round(phenoTrait, 2)    
    }
  }    
    newTraitName = paste(traitName, popId, sep = "_")
    colnames(phenoTrait)[1] <- newTraitName

    if (popPhenoNum == 1 )
      {
        print('no need to combine, yet')       
        combinedPhenoPops <- phenoTrait
        
      } else {
      print('combining...') 
      combinedPhenoPops <- merge(combinedPhenoPops, phenoTrait,
                            by = 0,
                            all=TRUE,
                            )

      rownames(combinedPhenoPops) <- combinedPhenoPops[, 1]
      combinedPhenoPops$Row.names <- NULL
      
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
