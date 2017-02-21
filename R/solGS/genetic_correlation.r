 #SNOPSIS

 #runs genetic correlation analyis.
 #correlation coeffiecients are stored in tabular and json formats 

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(gplots)
library(ltm)
library(plyr)
library(rjson)


allargs<-commandArgs()

geneticDataFile <- grep("combined_gebvs",
                        allargs,
                        ignore.case=TRUE,
                        perl=TRUE,
                        value=TRUE
                      )

correTableFile <- grep("genetic_corre_table",
                       allargs,
                       ignore.case=TRUE,
                       perl=TRUE,
                       value=TRUE
                       )

correJsonFile <- grep("genetic_corre_json",
                      allargs,
                      ignore.case=TRUE,
                      perl=TRUE,
                      value=TRUE
                      )

geneticData <- read.table(geneticDataFile,
                          header = TRUE,
                          row.names = 1,
                          sep = "\t",
                          na.strings = c("NA"),
                          dec = "."
                          )

coefpvalues <- rcor.test(geneticData,
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


pvalues[upper.tri(pvalues)]           <- NA
coefficients[upper.tri(coefficients)] <- NA

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
      file=correTableFile,
      col.names=TRUE,
      row.names=TRUE,
      quote=FALSE,
      dec="."
      )

write.table(correlationJson,
      file=correJsonFile,
      col.names=FALSE,
      row.names=FALSE,
      )

q(save = "no", runLast = FALSE)
