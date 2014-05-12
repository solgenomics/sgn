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


allargs<-commandArgs()

refererQtl <- grep("qtl",
                allargs,
                ignore.case=TRUE,
                perl=TRUE,
                value=TRUE
                )

message(" referer: ", refererQtl)

phenoDataFile<-grep("phenotype_data",
               allargs,
               ignore.case=TRUE,
               perl=TRUE,
               value=TRUE
               )

correCoefficientsFile<-grep("corre_coefficients_table",
               allargs,
               ignore.case=TRUE,
               perl=TRUE,
               value=TRUE
               )

correCoefficientsJsonFile<-grep("corre_coefficients_json",
               allargs,
               ignore.case=TRUE,
               perl=TRUE,
               value=TRUE
               )
message("correlation table file:", correCoefficientsFile)
message("pheno data file:", phenoDataFile)


phenoData <- c()

if(length(refererQtl) != 0  ) {
  message("phenotype data from solQTL", refererQtl)
  phenoData<-read.csv(phenoDataFile,
                      header=TRUE,
                      row.names = NULL,
                      dec=".",
                      sep=",",
                      na.strings=c("NA", "-")
                      )

  colnames(phenoData)[1] <- c('object_name')

    
} else {
  message(" phenotype data from solGS ", refererQtl)
  phenoData <- read.table(phenoDataFile,
                          header = TRUE,
                          row.names = NULL,
                          sep = "\t",
                          na.strings = c("NA", " ", "--", "-", "."),
                          dec = "."
                          )
}

### average out clone phenotype values and impute missing values
dropColumns <- c("uniquename", "stock_name")
phenoData   <- phenoData[,!(names(phenoData) %in% dropColumns)]

#format all-traits population phenotype dataset
formattedPhenoData <- phenoData
allTraitNames <- names(phenoData)

dropElements <- c("object_name", "object_id", "stock_id")
allTraitNames <- allTraitNames[! allTraitNames %in% dropElements]

for (i in allTraitNames)
{
  message("trait name : ", i)
 
  if (sum(is.na(formattedPhenoData[, i])) > 0)
    {
     
      message("number of  pheno missing values for ", i, ": ", sum(is.na(formattedPhenoData[, i])))

     #fill in for missing data with mean value
      formattedPhenoData[, i]  <- replace (formattedPhenoData[, i],
                                           is.na(formattedPhenoData[, i]),
                                           mean(formattedPhenoData[, i],
                                                na.rm =TRUE)
                                           ) 
    }

}

dropColumns <- c("object_id", "stock_id")

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

coefpvalues <- rcor.test(formattedPhenoData,
                         method="pearson",
                         use="pairwise"
                         )


coefficients <- coefpvalues$cor.mat
allcordata   <- coefpvalues$cor.mat
allcordata[lower.tri(allcordata)]<-coefpvalues$p.values[, 3]
diag(allcordata)<-1.00


pvalues<-as.matrix(allcordata)


pvalues<-round(pvalues,
               digits=2
               )

coefficients<-round(coefficients,
                    digits=3
                   )

allcordata<-round(allcordata,
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


#file.create(correlationJsonFile)

message("correlation text file: ", correCoefficientsFile)
message("correlation json file: ", correCoefficientsJsonFile)

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
