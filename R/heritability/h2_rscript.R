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
# Resolve the helper both for Rscript and for source()-based regression tests.
script_path <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) script_path <- frame$ofile
if (is.null(script_path)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    script_path <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) script_path <- invocation[file_index[1] + 1L]
  }
}
if (is.null(script_path) || is.na(script_path) || !nzchar(script_path)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(script_path)), "design_factors.R"), local = TRUE)


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

phenoData <- read_analysis_phenotypes(phenoDataFile)
assert_genotype_name_identity(phenoData)

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

# Only numeric trait columns enter the model. Each trait gets its own rows;
# eligibility depends on observed records, never the maximum replicate label.
allTraitNames <- allTraitNames[vapply(phenoData[allTraitNames], is.numeric, logical(1))]
if (!length(allTraitNames)) stop("No numeric traits are available for heritability analysis.")
her <- Vg <- Vres <- resp_var <- c()
library(lmerTest)
if (!all(c("germplasmName", "studyDesign") %in% names(phenoData))) {
  stop("The phenotype data must include germplasmName and studyDesign for heritability analysis.")
}
for (outcome in allTraitNames) {
  observed <- tapply(!is.na(phenoData[[outcome]]), phenoData$germplasmName, sum)
  eligible <- names(observed)[observed > 1]
  traitData <- phenoData[phenoData$germplasmName %in% eligible, , drop = FALSE]
  if (!nrow(traitData)) stop("At least two observed records per accession are required for ", outcome)
  fit <- fit_heritability_trait(traitData, outcome)
  H2 <- fit$Vg / (fit$Vg + fit$Vres)
  her <- c(her, round(H2, 3))
  Vg <- c(Vg, round(fit$Vg, 3))
  Vres <- c(Vres, round(fit$Vres, 3))
  resp_var <- c(resp_var, outcome)
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
