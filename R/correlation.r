 #SNOPSIS

 #commands for running correlation analyis,
 #outputs the correlation 
 #coefficients (also in json format) and their p-values


 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(gplots)
library(ltm)
library(plyr)
library(rjson)
library(nlme)

allargs<-commandArgs()

refererQtl <- grep("qtl",
                   allargs,
                   ignore.case=TRUE,
                   perl=TRUE,
                   value=TRUE
                   )

phenoDataFile <- grep("phenotype_data",
                      allargs,
                      ignore.case=TRUE,
                      perl=TRUE,
                      value=TRUE
                      )

correCoefficientsFile <- grep("corre_coefficients_table",
                              allargs,
                              ignore.case=TRUE,
                              perl=TRUE,
                              value=TRUE
                              )

correCoefficientsJsonFile <- grep("corre_coefficients_json",
                                  allargs,
                                  ignore.case=TRUE,
                                  perl=TRUE,
                                  value=TRUE
                                  )

phenoData <- c()

if(length(refererQtl) != 0  ) {
  phenoData<-read.csv(phenoDataFile,
                      header=TRUE,
                      row.names = NULL,
                      dec=".",
                      sep=",",
                      na.strings=c("NA", "-", " ", ".")
                      )

  colnames(phenoData)[1] <- c('object_name')
    
} else {  
  phenoData <- read.table(phenoDataFile,
                          header = TRUE,
                          row.names = NULL,
                          sep = "\t",
                          na.strings = c("NA", " ", "--", "-", "."),
                          dec = "."
                          )
}

dropColumns <- c("uniquename", "stock_name")
phenoData   <- phenoData[,!(names(phenoData) %in% dropColumns)]

formattedPhenoData <- phenoData
allTraitNames <- names(phenoData)
dropElements  <- c("object_name", "design", "block", "replicate", "object_id", "stock_id")
allTraitNames <- allTraitNames[! allTraitNames %in% dropElements]

for (i in allTraitNames) {
  trait <- i
  phenoTrait  <- subset(phenoData,
                        select = c("object_name", "stock_id", "design", "block", "replicate", trait)
                        )
   
  experimentalDesign <- phenoTrait[2, 'design']
  if (is.na(experimentalDesign) == TRUE) {experimentalDesign <- c('No Design')}

  if (experimentalDesign == 'augmented') {

    bloLevels  <- length(unique(phenoTrait$blocks))
    replicates <- unique(phenoTrait$replicates)
    allGenos   <- phenoTrait$object_name
    response   <- phenoData[, trait]
         
    allGenosFreq <- data.frame(table(phenoTrait$object_name))

    checkGenos <- subset(allGenosFreq, Freq == bloLevels)
    unRepGenos <- subset(allGenosFreq, Freq == 1)
    cG         <- checkGenos[, 1]
    uRG        <- unRepGenos[, 1]
    
    checkGenos <- data.frame(phenoTrait[phenoTrait$object_name %in% cG, ]) 
    bloMeans   <- data.frame(tapply(checkGenos[, trait], checkGenos[, "blocks"], mean))
    checkMeans <- data.frame(tapply(checkGenos[, trait], checkGenos[, "object_name"], mean))
    checkMeans <- subset(checkMeans, is.na(checkMeans)==FALSE)
     
    gBloMean   <- mean(checkGenos[, trait])
    colnames(bloMeans)   <- c("mean")
    colnames(checkMeans) <- c("mean")
      
    adjMeans <- data.matrix(checkMeans)
  
    adjGenoMeans <- function(x) {

      xG <- x[[1]]
      mr <- c()
    
      if(length(grep(xG, cG)) != 1) {
     
        bm <- as.numeric(bloMeans[x[[4]], ])       
        rV <- as.numeric(x[[6]])       
        m  <-  rV - bm + gBloMean 
        mr <- data.frame(xG, "mean"=m)
        rownames(mr) <- mr[, 1]
        mr[, 1] <- NULL
        mr <- data.matrix(mr)
    
      }

      return (mr)
        
    }
  
    nr <- nrow(phenoTrait)
    for (j in 1:nr ) {
    
      mr       <- adjGenoMeans(phenoTrait[j, ]) 
      adjMeans <- rbind(adjMeans, mr)
           
    }

    adjMeans <- round(adjMeans, digits=2)
      
    phenoTrait <- data.frame(adjMeans)
    formattedPhenoData[, trait] <- phenoTrait
 
  } else if (experimentalDesign == 'alpha lattice') {
    trait <- i
    alphaData <-   subset(phenoData,
                          select = c("stock_id", "object_name","block", "replicate", trait)
                          )
      
    colnames(alphaData)[2] <- "genotypes"
    colnames(alphaData)[5] <- "trait"
     
    ff <- trait ~ 0 + genotypes
      
    model <- lme(ff,
                 data = alphaData,
                 random = ~1|replicates/blocks,
                 method = "REML",
                 na.action = na.omit
                 )
   
    adjMeans <- data.matrix(fixed.effects(model))
    colnames(adjMeans) <- trait
      
    nn <- gsub('genotypes', '', rownames(adjMeans))
    rownames(adjMeans) <- nn
    adjMeans <- round(adjMeans, digits = 2)

    phenoTrait <- data.frame(adjMeans)
    formattedPhenoData[, i] <- phenoTrait
  
  } else {
 
    if (sum(is.na(formattedPhenoData[, i])) > 0)
      {
        formattedPhenoData[, i]  <- replace (formattedPhenoData[, i],
                                             is.na(formattedPhenoData[, i]),
                                             mean(formattedPhenoData[, i],
                                                  na.rm =TRUE)
                                             ) 
      }
  }
}

dropColumns <- c("object_id", "stock_id", "design",  "block", "replicate")

formattedPhenoData <- formattedPhenoData[, !(names(formattedPhenoData) %in% dropColumns)]

if (experimentalDesign != 'augmented' || experimentalDesign != 'alpha lattice') {

  formattedPhenoData <- ddply(formattedPhenoData,
                              "object_name",
                              colwise(mean)
                              )
}

row.names(formattedPhenoData) <- formattedPhenoData[, 1]
formattedPhenoData[, 1] <- NULL

formattedPhenoData <- round(formattedPhenoData,
                            digits=2
                            )

coefpvalues <- rcor.test(formattedPhenoData,
                         method="pearson",
                         use="pairwise"
                         )


coefficients <- coefpvalues$cor.mat
allcordata   <- coefpvalues$cor.mat
allcordata[lower.tri(allcordata)] <- coefpvalues$p.values[, 3]
diag(allcordata) <- 1.00

pvalues <- as.matrix(allcordata)

pvalues <- round(pvalues,
                 digits=2
                 )

coefficients <- round(coefficients,
                      digits=3
                      )

allcordata <- round(allcordata,
                    digits=3
                    )

#remove rows and columns that are all "NA"
if ( apply(coefficients,
           1,
           function(x)any(is.na(x))
           )
    ||
    apply(coefficients,
          2,
          function(x)any(is.na(x))
          )
    )
  {
                                                            
    coefficients<-coefficients[-which(apply(coefficients,
                                            1,
                                            function(x)all(is.na(x)))
                                      ),
                               -which(apply(coefficients,
                                            2,
                                            function(x)all(is.na(x)))
                                      )
                               ]
  }


pvalues[upper.tri(pvalues)]<-NA
coefficients[upper.tri(coefficients)]<-NA

coefficients2json <- function(mat){
    mat <- as.list(as.data.frame(t(mat)))
    names(mat) <- NULL
    toJSON(mat)
}

traits <- colnames(coefficients)

correlationList <- list(
                   "traits"=toJSON(traits),
                   "coefficients"=coefficients2json(coefficients)
                   )

correlationJson <- paste("{",paste("\"", names(correlationList), "\":", correlationList, collapse=","), "}")

write.table(coefficients,
      file=correCoefficientsFile,
      col.names=TRUE,
      row.names=TRUE,
      quote=FALSE,
      dec="."
      )

write.table(correlationJson,
      file=correCoefficientsJsonFile,
      col.names=FALSE,
      row.names=FALSE,
      )

q(save = "no", runLast = FALSE)
