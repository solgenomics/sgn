 #SNOPSIS

 #runs phenotypic heritability analysis.
 #Heritability coeffiecients are stored in tabular and json formats 

 #AUTHOR
 # Christiano Simoes (ccs263@cornell.edu)


options(echo = FALSE)

library(ltm)
library(rjson)
library(data.table)
library(phenoAnalysis)
library(dplyr)
#library(rbenchmark)
library(methods)
library(na.tools)

allArgs <- commandArgs()


outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                    what = "character")


refererQtl <- grep("qtl", inputFiles, value=TRUE)

phenoDataFile      <- grep("\\/phenotype_data", inputFiles, value=TRUE)
formattedPhenoFile <- grep("formatted_phenotype_data", inputFiles, fixed = FALSE, value = TRUE)
metadataFile       <-  grep("metadata", inputFiles, value=TRUE)

h2CoefficientsFile     <- grep("h2_coefficients_table", outputFiles, value=TRUE)
h2CoefficientsJsonFile <- grep("h2_coefficients_json", outputFiles, value=TRUE)

formattedPhenoData <- c()
phenoData          <- c()

phenoData <- as.data.frame(fread(phenoDataFile, sep="\t",
                                   na.strings = c("NA", "", "--", "-", ".", "..")
                                   ))

metaData <- scan(metadataFile, what="character")

message('pheno file ', phenoDataFile)
print(phenoData[1:3, ])
print(metaData)

allTraitNames <- c()
nonTraitNames <- c()
naTraitNames  <- c()

if (length(refererQtl) != 0) {

  allNames      <- names(phenoData)
  nonTraitNames <- c("ID")
  allTraitNames <- allNames[! allNames %in% nonTraitNames]

} else {
  allNames <- names(phenoData)
  nonTraitNames <- metaData

  allTraitNames <- allNames[! allNames %in% nonTraitNames]
}

print(allTraitNames)

colnames(phenoData)

#Calculating missing data
missingData <- apply(phenoData, 2, function(x) sum(is.na(x)))
md = data.frame(missingData)


#Removing traits with more than 60% of missing data
z=0
for (i in 40:ncol(phenoData)){
  if (md[i,1]/nrow(phenoData)>0.6){
    phenoData[[i-z]] <- NULL
    z = z+1
  }
}

#Removing non numeric data
z=0
for (i in 40:ncol(phenoData)){
  test = is.numeric(phenoData[,i])
  print(paste0('test', test))
  if (test == 'FALSE'){
    phenoData[,i] <- NULL
  }
}

#Removing non variance data
z=0
i=ncol(phenoData)
j=1
traits <- ncol(phenoData)-39
while (i > 39){
  test2 <- var(na.replace(phenoData[,i], na.mean))
  if (test2 == 0){
    cat("removing trait ",allNames[i],"\n")
    phenoData[,i]<-NULL
  }
  z=z+1
  i=i-1
  cat(i,"\n")
  if (i < 40){
    if (j < traits ){
      print("changing i")
      i = ncol(phenoData)
      j=j+1
    }
  }
}

her = rep(NA,(ncol(phenoData)-39))
Vg = rep(NA,(ncol(phenoData)-39))
Ve = rep(NA,(ncol(phenoData)-39))
resp_var = rep(NA,(ncol(phenoData)-39))


#Counting number of locations to create model
locs <- unique(phenoData$locationDbId)
szloc <- length(locs)


numb = 1
library(lmerTest)
print('phenodata before modeling')
print(phenoData[1:3, ])
for (i in 40:(ncol(phenoData))) {
    outcome = colnames(phenoData)[i]    

    print(paste0('outcome ', outcome))
    if (szloc == 1){
      model <- lmer(get(outcome)~(1|germplasmName)+replicate+blockNumber,
        na.action = na.exclude,
        data=phenoData)
    }else{
        model <- lmer(get(outcome) ~ (1|germplasmName) + studyYear + locationDbId + 
        replicate + blockNumber + germplasmName:locationDbId,
        na.action = na.exclude,
        data=phenoData)
    }
 
    #model <- runAnova(phenoData, outcome, genotypeEffectType = 'random')
    
    
    variance = as.data.frame(VarCorr(model))
    gvar = variance [1,'vcov']
    ervar = variance [2,'vcov']
    
    H2 = gvar/ (gvar + (ervar))
    H2nw = format(round(H2, 4), nsmall = 4)
    her[numb] = round(as.numeric(H2nw), digits =3)
    Vg[numb] = round(as.numeric(gvar), digits = 2)
    Ve[numb] = round(as.numeric(ervar), digits = 2)
    resp_var[numb] = colnames(phenoData)[i]

    numb = numb+1
    
    # }
    # else {
    #   resp_var[numb] = colnames(phenoData)[i]
    #     i = i+1 
    # }
}

#Prepare information to export data
Heritability = data.frame(resp_var,Vg, Ve, her)
print(Heritability)
#library(tidyverse)
Heritability = Heritability %>% 
  dplyr::rename(
    trait = resp_var,
    Hert = her,
    Vg = Vg,
    Ve = Ve
  )
print(Heritability)

#remove rows and columns that are all "NA"
heritability2json <- function(mat) {
    mat <- as.list(as.data.frame(t(mat)))
    names(mat) <- NULL
    toJSON(mat)
}

traits <- Heritability$trait

heritabilityList <- list(
                     "traits" = toJSON(traits),
                     "coeffiecients" =heritability2json(Heritability)
                   )

heritabilityJson <- paste("{",paste("\"", names(heritabilityList), "\":", heritabilityList, collapse=","), "}")

heritabilityJson <- list(heritabilityJson)

fwrite(Heritability,
       file      = h2CoefficientsFile,
       row.names = FALSE,
       sep       = "\t",
       quote     = FALSE,
       )

fwrite(heritabilityJson,
       file      = h2CoefficientsJsonFile,
       col.names = FALSE,
       row.names = FALSE,
       qmethod   = "escape"
       )


q(save = "no", runLast = FALSE)
