

library("rjson")
library("dplyr")
library("methods")


##### Get data #####
args = commandArgs(trailingOnly = TRUE)

pheno <- read.table(args[1], sep = "\t", header = TRUE)

study_trait <- args[2]
h2File <- args[3]
h2CsvFile <- args[4]
errorFile <- args[5]

errorMessages <- c()

study_trait <- gsub("\\."," ",study_trait)
cat("study trait is ", study_trait,"\n")


names <- colnames(pheno)
allTraits <- grep("CO_", names, value = TRUE)
library(dplyr)
pheno <- pheno[,colnames(pheno) %in% c("locationName", "germplasmName", "studyYear", "blockNumber","replicate", allTraits)]
names <- colnames(pheno)
new_names <- gsub(".CO_.*","", names)
new_names <- gsub("\\."," ",new_names)
colnames(pheno) <- new_names

#Calculating missing data
missingData <- data.frame(missingData = tapply(pheno[,6], pheno$germplasmName, function(x){
  return(length(which(is.na(x))))
}))

missingData <- tibble::rownames_to_column(missingData, "germplasmName")
md <- sum(missingData$missingData)/nrow(pheno)

#Removing trait with more than 60% of missing data
if(md[1] > 0.6){
  message1 <- c("Please, check your dataset! There are more than 60% of missing data for selected trait.")
}else{
  message1 <- c()
}


#Removing non numeric data
isNumeric <- is.numeric(pheno[,6])
if(isNumeric == "FALSE"){
  message2 <- c("Please, check your dataset! The selected trait is not numeric.")
}else{
  message2 <- c()
}

#checkning number of locations
szloc <- length(unique(pheno$locationName))
szreps <- length(unique(pheno$replicate))
szyr <- length(unique(pheno$studyYear))

library(lmerTest)
# Still need check temp data to ensure wright dimension
an.error.occured <- FALSE

H2 = c()
her = c()
Vg = c()
Ve = c()
Vres = c()
resp_var = c()
j = 1
tryCatch({ for(i in 6:ncol(pheno)){
    outcome = colnames(pheno)[i]    
    if (szreps > 1){
      if (szloc == 1){
        if (szyr == 1){
          model <- lmer(get(outcome)~(1|germplasmName)+replicate,
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = 0
          resvar = variance [2, "vcov"]
        }else{
          model <- lmer(get(outcome) ~ (1|germplasmName) + replicate + studyYear,
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = 0
          resvar = variance [2, "vcov"]
        }
      }else if (szloc > 1) {
        if (szyr == 1){
          model <- lmer(get(outcome) ~ (1|germplasmName) + replicate + (1|locationName),
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = variance [2, "vcov"]
          resvar = variance [3, "vcov"]
        }else{
          model <- lmer(get(outcome) ~ (1|germplasmName) + replicate + (1|locationName) + studyYear,
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = variance [2, "vcov"]
          resvar = variance [3, "vcov"]
        }
      }
    }else if (szreps == 1){
      if (szloc ==1){
        if (szyr == 1){
          model <- lmer(get(outcome)~(1|germplasmName) + blockNumber,
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = 0
          resvar = variance [2, "vcov"]
        }else{
          model <- lmer(get(outcome) ~ (1|germplasmName) + studyYear + blockNumber,
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = 0
          resvar = variance [2, "vcov"]
        }
      }else if (szloc > 1){
        if (szyr ==1){
          model <- lmer(get(outcome)~(1|germplasmName)+ (1|locationName) +  blockNumber,
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = variance [2, "vcov"]
          resvar = variance [3, "vcov"]
        }else{
          model <- lmer(get(outcome) ~ (1|germplasmName) + studyYear + (1|locationName) + blockNumber,
                        na.action = na.exclude,
                        data=pheno)
          variance = as.data.frame(VarCorr(model))
          gvar = variance [1,"vcov"]
          envar = variance [2, "vcov"]
          resvar = variance [3, "vcov"]
        }
      }
    }
    
    H2 = append(H2, gvar/ (gvar + (envar) + (resvar)))
    H2nw = format(round(H2[j], 4), nsmall = 4)
    her = append(her, round(as.numeric(H2nw), digits =3))
    Vg = append(Vg, round(as.numeric(gvar), digits = 3))
    Ve = append(Ve, round(as.numeric(envar), digits = 2))
    Vres = append(Vres, round(as.numeric(resvar), digits = 3))
    resp_var = append(resp_var, colnames(pheno)[i])
    j=j+1
  }

}, error = function(e) {
  an.error.occured <<- TRUE
  errorMessages <<- c(errorMessages, as.character(e))
})



#Prepare information to export data
tryCatch({
  
  Heritability = data.frame(trait = resp_var,
                          Hert = her,
                          Vg = Vg,
                          Ve = Ve,
                          Vres = Vres
                          )
  
  Heritability = na.omit(Heritability)

  h2_json <- jsonlite::toJSON(Heritability)
  jsonlite::write_json(h2_json, h2File)
  write.csv(Heritability, file = h2CsvFile)

}, error = function(e) {
  an.error.occured <<- TRUE
  errorMessages <<- c(errorMessages, as.character(e))
})

errorMessages <- c(errorMessages, as.character(message1))
errorMessages <- c(errorMessages, as.character(message2))

cat("Was there an error? ", an.error.occured,"\n")
if ( length(errorMessages) > 0 ) {
  print(sprintf("Writing Error Messages to file: %s", errorFile))
  print(errorMessages)
  write(errorMessages, errorFile)
}


#-------------------------------------------------------------------------
