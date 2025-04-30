# ################################################################################
# # Modeling Spatial Variation
# ################################################################################

# # There are ten main steps to this protocol:
# # 1. Load the software needed.
# # 2. Declare user-supplied variables.
# # 3. Process the phenotypic data.
# # 4. Fit the two models with and without 2D Spline model in sommer
# # 5. Format the information needed for output.


# ################################################################################
# # 1. Load software needed
# ################################################################################

library(SpATS)

# ################################################################################
# # 2. Declare user-supplied variables.
# ################################################################################
# Get Arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Two or more arguments are required.")
}
phenotypeFile <- args[1]
spatialFile <- args[2]
spatialHeaders <- args[3]

# ################################################################################
# # 3. Process the phenotypic data.
# ################################################################################
# # read in the phenotypic data

userPheno <- read.delim(phenotypeFile, header = TRUE, sep = "\t", fill = TRUE)
spatialPheno <- read.delim(spatialFile, header = TRUE, sep = "\t", fill = TRUE)
colnames(spatialPheno) <- c("Trait", "Data.Quality", "Moran.P.Value", "Correction.Needed")
traits <- spatialPheno$Trait[spatialPheno$Correction.Needed == "YES"]
# The user should be able to select their response variables from a drop-down menu
#    of the column names of the userPheno object. Then, those strings should be passed
#    to this vector, 'userResponse'.
userResponse <- unlist(strsplit(traits, split = ",", fixed = T))
userResponse <- userResponse[!userResponse == "notes"] # x[ !x == 'A'] # remove notes from userResponse
rownames(userPheno) <- userPheno$observationUnitName
userPheno$germplasmName <- as.factor(userPheno$germplasmName)

output <- data.frame(
    observationUnitName = userPheno$observationUnitName,
    germplasmName = userPheno$germplasmName,
    rowNumber = userPheno$rowNumber,
    colNumber = userPheno$colNumber,
    replicate = userPheno$replicate
)

for (trait in userResponse) {
    spatial_model <- SpATS(
        response = trait,
        spatial = ~ SAP(colNumber, rowNumber),
        genotype = "germplasmName",
        genotype.as.random = TRUE,
        data = userPheno
    )
    output[[trait]] <- userPheno[[trait]]
    output[[paste(trait, "_spatially_corrected", sep = "")]] <- fitted(spatial_model);
    output[[paste(trait, "_spatial_adjustment", sep = "")]] <- output[[paste(trait, "_spatially_corrected", sep = "")]] - output[[trait]]
}

outfile <- paste(phenotypeFile, ".spatially_corrected", sep="")

write.table(output, file = outfile, quote = FALSE, sep = "\t", col.names = TRUE, row.names = FALSE)
