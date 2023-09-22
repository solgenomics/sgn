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
library(methods)
library(na.tools)
library(lme4)

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
cat("Dim phenoData ", dim(phenoData),"\n")

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

print("Trait names:")
print(allTraitNames)

print("colnames:")
colnames(phenoData)

#Calculating missing data
missingData <- apply(phenoData, 2, function(x) sum(is.na(x)))
md = data.frame(missingData)

nCols <- ncol(phenoData)-1
nTraits <- nCols-30

#Removing non numeric data
for (i in 31:nCols){
  test = is.numeric(phenoData[,i])
  if (test == 'FALSE'){
    phenoData[,i] <- NULL
  }
}

# Preparing variance vectors
her = rep(NA, nTraits)
Vg = rep(NA, nTraits)
Vres = rep(NA, nTraits)
resp_var = rep(NA, nTraits)

counter = 1
cat("Traits: ", colnames(phenoData[31:nCols]),"\n")
for (i in 31:nCols) {
    outcome = colnames(phenoData)[i]    

    print(paste0('outcome ', outcome))
    
    model <- lmer(get(outcome)~ 1 + (1|germplasmName),
      na.action = na.exclude,
      data=phenoData)

    
    # variance = as.data.frame(VarCorr(model))
    variance = data.frame(VarCorr(model))
    
    H2 = variance$vcov[1]/ (variance$vcov[1] + variance$vcov[2])
    #H2 = gvar/(gvar + (envar))
    H2nw = format(round(H2, 4), nsmall = 4)
    her[counter] = round(as.numeric(H2nw), digits =3)
    Vg[counter] = round(as.numeric(variance$vcov[1]), digits = 3)
    Vres[counter] = round(as.numeric(variance$vcov[2]), digits = 3)
    resp_var[counter] = colnames(phenoData)[i]
    
    counter = counter + 1
}

#Prepare information to export data
Heritability = data.frame(resp_var,Vg, Vres, her)
print(Heritability)
Heritability = Heritability %>% 
  dplyr::rename(
    trait = resp_var,
    Hert = her,
    Vg = Vg,
    Vres = Vres
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
