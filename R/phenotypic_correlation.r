 #SNOPSIS

 #Commands for running phenotypic correlation analysis.
 #Correlation coeffiecients are stored in tabular and json formats 

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(gplots)
library(ltm)
library(plyr)
library(rjson)
library(lme4)
#library(rbenchmark)


allargs<-commandArgs()

refererQtl <- grep("qtl",
                   allargs,
                   ignore.case=TRUE,
                   perl=TRUE,
                   value=TRUE
                   )

phenoDataFile <- grep("\\/phenotype_data",
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


formattedPhenoFile <- grep("formatted_phenotype_data",
                  allargs,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )


formattedPhenoData <- c()
phenoData <- c()

if (file.info(formattedPhenoFile)$size > 0 ) {

  formattedPhenoData <- read.table(formattedPhenoFile,
                                   header = TRUE,
                                   row.names = 1,
                                   sep = "\t",
                                   na.strings = c("NA", " ", "--", "-", "."),
                                   dec = "."
                                   )
} else {

  if ( length(refererQtl) != 0 ) {
    
    phenoData <- read.csv(phenoDataFile,
                          header=TRUE,
                          dec=".",
                          sep=",",
                          na.strings=c("NA", "-", " ", ".", "..")
                          )
 
  } else {

    phenoData <- read.table(phenoDataFile,
                            header = TRUE,
                            row.names = NULL,
                            sep = "\t",
                            na.strings = c("NA", " ", "--", "-", ".", ".."),
                            dec = "."
                            )
  } 
}

allTraitNames <- c()
nonTraitNames <- c()

if (length(refererQtl) != 0) {

  allNames      <- names(phenoData)
  nonTraitNames <- c("ID")

  allTraitNames <- allNames[! allNames %in% nonTraitNames]

} else if (file.info(formattedPhenoFile)$size == 0 && length(refererQtl) == 0) {

  dropColumns <- c("uniquename", "stock_name")
  phenoData   <- phenoData[,!(names(phenoData) %in% dropColumns)]

  allNames      <- names(phenoData)
  nonTraitNames <- c("object_name", "object_id", "stock_id", "design", "block", "replicate")

  allTraitNames <- allNames[! allNames %in% nonTraitNames]
 
}

if (!is.null(phenoData) && length(refererQtl) == 0) {
  
  for (i in allTraitNames) {

    if (class(phenoData[, i]) != 'numeric') {
      phenoData[, i] <- as.numeric(as.character(phenoData[, i]))
    }
    
    if (all(is.nan(phenoData$i))) {
      phenoData[, i] <- sapply(phenoData[, i], function(x) ifelse(is.numeric(x), x, NA))                     
    }
  }
}

phenoData     <- phenoData[, colSums(is.na(phenoData)) < nrow(phenoData)]
allTraitNames <- names(phenoData)[! names(phenoData) %in% nonTraitNames]

###############################
if (length(refererQtl) == 0  ) {
  if (file.info(formattedPhenoFile)$size == 0) {
    
    cnt   <- 0
 
    for (i in allTraitNames) {

      cnt   <- cnt + 1
      trait <- i
  
      experimentalDesign <- c()
      
      if ('design' %in% colnames(phenoData)) {

        experimentalDesign <- phenoData[2, 'design']
  
        if (is.na(experimentalDesign)) {
          experimentalDesign <- c('No Design')
        }
    
      } else {   
        experimentalDesign <- c('No Design')
      }

      if ((experimentalDesign == 'Augmented' || experimentalDesign == 'RCBD')  &&  unique(phenoData$block) > 1) {

      message("GS experimental design: ", experimentalDesign)

      augData <- subset(phenoData,
                        select = c("object_name", "object_id",  "block",  trait)
                        )

      colnames(augData)[1] <- "genotypes"
      colnames(augData)[4] <- "trait"

      model <- try(lmer(trait ~ 0 + genotypes + (1|block),
                        augData,
                        na.action = na.omit
                        ))
      genoEffects <- c()

      if (class(model) != "try-error") {
        genoEffects <- data.frame(fixef(model))
        
        colnames(genoEffects) <- trait

        nn <- gsub('genotypes', '', rownames(genoEffects))  
        rownames(genoEffects) <- nn
      
        genoEffects <- round(genoEffects, digits = 2)
      }
  
      if (cnt == 1 ) {
        formattedPhenoData <- data.frame(genoEffects)
      } else {
        formattedPhenoData <-  merge(formattedPhenoData, genoEffects, by=0, all=TRUE)
        row.names(formattedPhenoData) <- formattedPhenoData[, 1]
        formattedPhenoData[, 1] <- NULL
      }
      
    } else if (experimentalDesign == 'Alpha') {
      trait <- i
      
      message("Experimental desgin: ", experimentalDesign)
      
      alphaData <- subset(phenoData,
                            select = c("object_name", "object_id","block", "replicate", trait)
                            )
      
      colnames(alphaData)[1] <- "genotypes"
      colnames(alphaData)[5] <- "trait"
         
      model <- try(lmer(trait ~ 0 + genotypes + (1|replicate/block),
                        alphaData,
                        na.action = na.omit
                        ))
        
      if (class(model) != "try-error") {
        genoEffects <- data.frame(fixef(model))
      
        colnames(genoEffects) <- trait

        nn <- gsub('genotypes', '', rownames(genoEffects))     
        rownames(genoEffects) <- nn
      
        genoEffects <- round(genoEffects, digits = 2)
        
      }
         
      if(cnt == 1 ) {
        formattedPhenoData <- genoEffects
      } else {
        formattedPhenoData <-  merge(formattedPhenoData, genoEffects, by=0, all=TRUE)
        row.names(formattedPhenoData) <- formattedPhenoData[, 1]
        formattedPhenoData[, 1] <- NULL
      }

    } else {
      message("GS experimental design: ", experimentalDesign)
                                 
      dropColumns <- c("object_id", "stock_id", "design",  "block", "replicate")
   
      formattedPhenoData <- phenoData[, !(names(phenoData) %in% dropColumns)]
     
      formattedPhenoData <- ddply(formattedPhenoData,
                                  "object_name",
                                  colwise(mean, na.rm=TRUE)
                                  )
    
      row.names(formattedPhenoData) <- formattedPhenoData[, 1]
      formattedPhenoData[, 1] <- NULL
  
    } 
    }
  }
} else {
  message("qtl stuff")
  formattedPhenoData <- ddply(phenoData,
                              "ID",
                              colwise(mean, na.rm=TRUE)
                              )

  row.names(formattedPhenoData) <- formattedPhenoData[, 1]
  formattedPhenoData[, 1] <- NULL

  formattedPhenoData <- round(formattedPhenoData, digits = 2)
}

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


if (file.info(formattedPhenoFile)$size == 0 & !is.null(formattedPhenoData) ) {
  write.table(formattedPhenoData,
              file = formattedPhenoFile,
              sep = "\t",
              col.names = NA,
              quote = FALSE,
              )
}


q(save = "no", runLast = FALSE)
