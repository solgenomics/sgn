################################################################################
# Modeling Spatial Variation
################################################################################

# There are ten main steps to this protocol:
# 1. Load the software needed.
# 2. Declare user-supplied variables.
# 3. Process the phenotypic data.
# 4. Fit the mixed models in sommer.
# 5. Format the information needed for output.


################################################################################
# 1. Load software needed
################################################################################

library(sommer)


################################################################################
# 2. Declare user-supplied variables.
################################################################################
# Get Arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Two or more arguments are required.")
}
phenotypeFile <- args[1]
traits <- args[2]


################################################################################
# 3. Process the phenotypic data.
################################################################################
# read in the phenotypic data

userPheno <- read.delim(phenotypeFile, header = TRUE, sep = "\t", fill = TRUE)

# The user should be able to select their response variables from a drop-down menu
#    of the column names of the userPheno object. Then, those strings should be passed
#    to this vector, 'userResponse'.

userResponse <- unlist(strsplit(traits, split = ",", fixed = T))
userID <- "germplasmName"
row <- "rowNumber"
col <- "colNumber"
userPheno$R <- as.factor(userPheno$rowNumber)
userPheno$C <- as.factor(userPheno$colNumber)

################################################################################
# 4. Fit the 2D Spline model in sommer
################################################################################
# Make a list to save the models.

userModels <- list()
output <- data.frame()

for (i in 2:length(userResponse)) {
  nas <- colMeans(is.na(userPheno[userResponse[i]])) * 100
  standarddev <- sapply(userPheno[userResponse[i]], sd)
  minimum <- min(userPheno[userResponse[i]], na.rm = TRUE)
  maximum <- max(userPheno[userResponse[i]], na.rm = TRUE)
  write(paste("MINIMUM:", minimum), stderr())
  if (nas < 90 && minimum != maximum) {
    # if (standarddev!=0) {
    write(paste("Percentage of Nas:", nas), stderr())
    write(paste("userResponse:", userResponse[i]), stderr())
    write(paste("userResponsedata:", userPheno[userResponse[i]]), stderr())
    fixedArg <- paste(userResponse[i], " ~ ", "1 +", userID, sep = "")
    write(paste("fixedArg:", fixedArg), stderr())

    randArg <- paste("~vsr(R)+vsr(C)+ spl2Da(", col, ",", row, ")", sep = "")
    write(paste("randArg:", randArg), stderr())

    m2.sommer <- mmer(
      fixed = as.formula(fixedArg),
      random = as.formula(randArg),
      rcov = ~units,
      data = userPheno, verbose = FALSE
    )

    # write(paste('model:', m2.sommer), stderr())


    userModels[[i]] <- m2.sommer
    blue <- summary(m2.sommer)$betas
    # output[[i]] <- blue
    output <- rbind(output, blue)
    # write(paste("blues:", blue), stderr())
  }
}
write(paste("blues:", output), stderr())
BLUE <- as.data.frame(output)
write(paste("BLUE:", BLUE), stderr())

# adj = coef(m2.sommer)$Trait
# outfile_blue <- paste(phenotypeFile, ".BLUEs", sep = "")
outfile_blue <- paste(phenotypeFile, ".out", sep = "")
write.table(BLUE, outfile_blue)

################################################################################
# 5. Format the information needed for output.
################################################################################


# for (i in 1:length(userModels)) {
#   m2.sommer <- userModels[[i]]
#   # write(paste("model:", head(m2.sommer)), stderr())
#   m3.sommer <- data.frame(matrix(unlist(m2.sommer), nrow = length(m2.sommer), byrow = TRUE))
#   write(paste("model:", head(m3.sommer)), stderr())
#   outfile_model <- paste(phenotypeFile, ".model", sep = "")
#   write.table(m3.sommer, outfile_model)

#   #   m2.sommer<-as.data.frame(m2.sommer)
#   #   blue = summary(m2.sommer)$beta
#   #   BLUE<-as.data.frame(blue)
#   #   write(paste('BLUE:', BLUE), stderr())

#   #  # adj = coef(m2.sommer)$Trait
#   #   outfile_blue = paste(phenotypeFile, ".BLUEs", sep="");
#   #   write.table(BLUE, outfile_blue)
# }
