#combines gebvs of traits of a population
# Isaak Y Tecle


options(echo = FALSE)


allArgs <- commandArgs()

inFile <- grep("gebv_files",
               allArgs,
               ignore.case = TRUE,
               perl = TRUE,
               value = TRUE
               )

outputFile <- grep("combined_gebvs",
                allArgs,
                ignore.case = TRUE,
                perl = TRUE,
                value = TRUE
                )

inputFiles <- scan(inFile,
                   what = "character"
                   )


combinedGebvs <- c()
count         <- 0

for (i in inputFiles) {
  
  traitGebv <- read.table(i,
                          header = TRUE,
                          row.names = NULL,
                          sep = "\t",
                          dec = "."
                          )

  trait <- colnames(traitGebv)
  count <- count + 1
 
  traitGebv <- traitGebv[order(traitGebv$X), ]

  if(count == 1) {
    combinedGebvs <- traitGebv
  
    row.names(combinedGebvs) <- combinedGebvs[, 1]
    combinedGebvs[, 1] <- NULL
  
  } else {
    row.names(traitGebv) <- traitGebv[, 1]
    traitGebv[, 1] <- NULL

    combinedGebvs <- merge(traitGebv,
                           combinedGebvs,
                           by=0,
                           all=FALSE
                           )
   
    rownames(combinedGebvs) <- combinedGebvs[, 1]      
    combinedGebvs$Row.names <- NULL
  }  
}

if (length(outputFile) != 0 ) {
  write.table(combinedGebvs,
              file = outputFile,
              sep = "\t",
              quote = FALSE,
              col.names = NA,
              )
}
 
q(save = "no", runLast = FALSE)
