

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
study_ids <- pheno$studyDbId
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


library(lmerTest)
# Still need check temp data to ensure wright dimension
an.error.occurred <- FALSE

H2 = c()
her = c()
Vg = c()
Ve = c()
Vres = c()
resp_var = c()
j = 1
tryCatch({ for(i in 6:ncol(pheno)){
    outcome = colnames(pheno)[i]    
    observed <- !is.na(pheno[[outcome]])
    traitData <- pheno[observed, , drop = FALSE]
    studies <- study_ids[observed]
    multi_study <- length(unique(na.omit(studies))) > 1
    if (multi_study) {
      traitData$blockNumber <- interaction(studies, traitData$blockNumber, drop = TRUE)
    }

    formula <- get(outcome) ~ (1 | germplasmName)
    if (length(unique(na.omit(traitData$blockNumber))) > 1) {
      traitData <- traitData[!is.na(traitData$blockNumber), , drop = FALSE]
      if (multi_study && length(unique(na.omit(traitData$locationName))) > 1) {
        traitData <- traitData[!is.na(traitData$locationName), , drop = FALSE]
        # A separate intercept for every study-block would absorb location means.
        # Fit sum-to-zero differences between the observed blocks at each location.
        contrasts_by_site <- lapply(split(seq_len(nrow(traitData)), traitData$locationName, drop = TRUE), function(rows) {
          blocks <- factor(traitData$blockNumber[rows])
          if (nlevels(blocks) < 2) return(NULL)
          columns <- matrix(0, nrow(traitData), nlevels(blocks) - 1)
          columns[rows, ] <- contr.sum(nlevels(blocks))[as.integer(blocks), , drop = FALSE]
          columns
        })
        block_effects <- do.call(cbind, contrasts_by_site)
        if (!is.null(block_effects)) {
          traitData$block_effects <- I(block_effects)
          formula <- update(formula, . ~ . + block_effects)
        }
      } else if (length(unique(traitData$blockNumber)) > 1) {
        traitData$blockNumber <- factor(traitData$blockNumber)
        formula <- update(formula, . ~ . + blockNumber)
      }
    }
    multi_location <- length(unique(na.omit(traitData$locationName))) > 1
    if (multi_location) {
      formula <- update(formula, . ~ . + (1 | locationName))
    }
    if (length(unique(na.omit(traitData$studyYear))) > 1) {
      formula <- update(formula, . ~ . + studyYear)
    }
    model <- lmer(formula, na.action = na.exclude, data = traitData)
    variance <- as.data.frame(VarCorr(model))
    components <- setNames(variance$vcov, variance$grp)
    gvar <- components[["germplasmName"]]
    envar <- if (multi_location) components[["locationName"]] else 0
    resvar <- components[["Residual"]]

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
  an.error.occurred <<- TRUE
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
  an.error.occurred <<- TRUE
  errorMessages <<- c(errorMessages, as.character(e))
})

errorMessages <- c(errorMessages, as.character(message1))
errorMessages <- c(errorMessages, as.character(message2))

cat("Was there an error? ", an.error.occurred,"\n")
if ( length(errorMessages) > 0 ) {
  print(sprintf("Writing Error Messages to file: %s", errorFile))
  print(errorMessages)
  write(errorMessages, errorFile)
}


#-------------------------------------------------------------------------
