#SNOPSIS

 #runs quality control analysis  using st4gi.
 
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
library(st4gi)


allArgs <- commandArgs()


outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                    what = "character")


refererQtl <- grep("qtl", inputFiles, value=TRUE)

phenoDataFile      <- grep("\\/phenotype_data", inputFiles, value=TRUE)
formattedPhenoFile <- grep("formatted_phenotype_data", inputFiles, fixed = FALSE, value = TRUE)
metadataFile       <-  grep("metadata", inputFiles, value=TRUE)

qcCoefficientsFile     <- grep("qc_coefficients_table", outputFiles, value=TRUE)
qcCoefficientsJsonFile <- grep("qc_coefficients_json", outputFiles, value=TRUE)

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


# colnames(phenoData)

# Load the st4gi package


# Load the data

# mydata <- read.csv("PECIP2018_ST01CSR.csv")

# Have a look to the structure of the file
# Check that all numeric traits are of type num or int

str(inputFiles)


# Check data
# This will check for inconsistencies  in the data as well as outliers
# In this example, only extreme values are detected

#This part I must add to breedbase
check.data(mydata)

# See what happens if number of roots were 0 for some plot

d <- mydata # A copy of mydata
d[5, 'nocr'] <- 0 # Zero commercial roots for plot 5
check.data(d)

# Fix all the detected problems in the data file and load the data again
