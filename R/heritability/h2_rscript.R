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

# print("colnames:")
# colnames(phenoData)

#Calculating missing data
missingData <- apply(phenoData, 2, function(x) sum(is.na(x)))
md = data.frame(missingData)
rangeTraits <- which(colnames(phenoData) %in% allTraitNames)

# Calculating the number of replicates per accession
replicateData <- data.frame(replicates = tapply(phenoData$replicate, phenoData$germplasmName, function(x){
  return(max(unique(x)))
}))
replicateData <- tibble::rownames_to_column(replicateData, "germplasmName")



#Removing non numeric data
for( traits in rangeTraits){
  if(is.numeric(phenoData[,traits]) == 'FALSE'){
    phenoData <- phenoData[,-traits]
    allTraitNames <- allTraitNames[-which(allTraitNames == colnames(phenoData)[traits])]
  }
}

#Range after filtering
rangeTraits <- which(names(phenoData)%in%allTraitNames)

nTraits <- length(rangeTraits)
# Preparing variance vectors
her = c()
Vg = c()
Vres = c()
resp_var = c()

library(lmerTest)
for (i in rangeTraits) {
  outcome = colnames(phenoData)[i]   

  #Calculating missing data per trait
  missingData <- data.frame(missingData = tapply(phenoData[,outcome], phenoData$germplasmName, function(x){
    return(length(which(is.na(x))))
  }))

  missingData <- tibble::rownames_to_column(missingData, "germplasmName")
  missingReplicates <- dplyr::left_join(missingData, replicateData, by = "germplasmName")
  missingReplicates$limitRep <- missingReplicates$replicates - missingReplicates$missingData
  missingReplicates <- missingReplicates[missingReplicates$limitRep > 1,]

  # Filtering the dataset
  phenoData <- phenoData[phenoData$germplasmName %in% missingReplicates$germplasmName,]
   
  
  print(paste0('outcome ', outcome))
  
  model <- lmer(get(outcome)~ (1|germplasmName) + replicate,
                na.action = na.exclude,
                data=phenoData)
  
  
  # variance = as.data.frame(VarCorr(model))
  variance = data.frame(VarCorr(model))
  
  H2 = variance$vcov[1]/ (variance$vcov[1] + variance$vcov[2])
  her = append(her, round(as.numeric(H2), digits =3))
  Vg = append(Vg, round(as.numeric(variance$vcov[1]), digits = 3))
  Vres = append(Vres, round(as.numeric(variance$vcov[2]), digits = 3))
  resp_var = append(resp_var, colnames(phenoData)[i])

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
