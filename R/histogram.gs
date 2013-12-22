#trait data clean up,
#missing value imputation,
#and formatting. prepares data
#for trait histogram


options(echo = FALSE)

library(plyr)
library(stringr)

allArgs <- commandArgs()



traitPhenoFile <- grep("trait_phenotype_data",
                       allArgs,
                       ignore.case = TRUE,
                       fixed = FALSE,
                       value = TRUE
                       )

phenoFile <- grep("phenotype_data",
                  allArgs,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )

phenoData <- read.table(phenoFile,
                        header = TRUE,
                        row.names = NULL,
                        sep = "\t",
                        na.strings = c("NA", " ", "--", "-"),
                        dec = "."
                        )

traitPhenoData  <- subset(phenoData,
                          select = c("object_name", "stock_id", trait)
                          )
   
if (sum(is.na(traitPhenoData)) > 0)
  {
    traitPhenoData[, trait]  <- replace (traitPhenoData[, trait],
                                     is.na(traitPhenoData[, trait]),
                                     mean(traitPhenoData[, trait], na.rm =TRUE)
                                     ) 
  }

dropColumns     <- c("stock_id")
traitPhenoData  <- traitPhenoData[,!(names(traitPhenoData) %in% dropColumns)]
traitPhenoData  <- traitPhenoData[order(row.names(traitPhenoData)), ]
traitPhenoData  <- data.frame(traitPhenoData)
traitPhenoData  <- ddply(traitPhenoData, "object_name", colwise(mean))

row.names(traitPhenoData) <- traitPhenoData[, 1]
traitPhenoData[, 1] <- NULL
    
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



q(save = "no", runLast = FALSE)
