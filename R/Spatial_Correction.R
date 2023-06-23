################################################################################
# Modeling Spatial Variation
################################################################################

# There are ten main steps to this protocol:
# 1. Load the software needed.
# 2. Declare user-supplied variables.
# 3. Process the phenotypic data.
# 4. Fit the two models with and without 2D Spline model in sommer
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
spatialFile <- args[2]
spatialHeaders <- args[3]

################################################################################
# 3. Process the phenotypic data.
################################################################################
# read in the phenotypic data

userPheno <- read.delim(phenotypeFile, header = TRUE, sep = "\t", fill = TRUE)
spatialPheno <- read.delim(spatialFile, header = FALSE, sep = "\t", fill = TRUE)
colnames(spatialPheno) <- c("Data.Quality", "Moran.P.Value", "Correction.Needed", "Trait")
# select all the traits that need correction: Correction.Needed == "YES" and save them in a vector
traits <- paste(spatialPheno$Trait[spatialPheno$Correction.Needed == "YES"], collapse = ",")


# The user should be able to select their response variables from a drop-down menu
#    of the column names of the userPheno object. Then, those strings should be passed
#    to this vector, 'userResponse'.
userResponse <- unlist(strsplit(traits, split = ",", fixed = T))
userResponse <- userResponse[!userResponse == "notes"] # x[ !x == 'A'] # remove notes from userResponse
replicate <- "replicate"
userID <- "germplasmName"
row <- "rowNumber"
col <- "colNumber"
userPheno$R <- as.factor(userPheno$rowNumber)
userPheno$C <- as.factor(userPheno$colNumber)

################################################################################
# 4. Fit the two models with and without 2D Spline model in sommer
################################################################################
# Make a list to save the models.
userModelsWith <- list()
userModelsWithout <- list()

# Make lists to save the outputs for AIC, blues and fitted values
AIC_output <- data.frame()
output <- data.frame()
fitted_output <- data.frame()

# Loop through the response variables running the model with and without spatial variation
for (i in 1:length(userResponse)) {
    write(paste("userResponse:", userResponse[i]), stderr())

    ## Fit the model without spatial variation ##
    modArg <- paste(userResponse[i], " ~ ", userID, " + ", replicate, sep = "")
    write(paste("modArg:", modArg), stderr())
    mod <- mmer(
        as.formula(modArg),
        data = userPheno,
        verbose = FALSE
    )

    write(paste("modArg:", modArg), stderr())
    userModelsWithout[[i]] <- mod

    ## Fit the model with spatial variation ##

    # create a formula for the fixed effects
    fixedArg <- paste(userResponse[i], " ~ ", "1 +", userID, sep = "")
    write(paste("fixedArg:", fixedArg), stderr())
    # create a formula for the random effects
    randArg <- paste("~vsr(R)+vsr(C)+ spl2Da(", col, ",", row, ")", sep = "")
    write(paste("randArg:", randArg), stderr())
    # the model
    m2.sommer <- mmer(
        fixed = as.formula(fixedArg),
        random = as.formula(randArg),
        rcov = ~units,
        data = userPheno, verbose = FALSE
    )

    userModelsWith[[i]] <- m2.sommer

    ## Obtaining the results from the models: AIC, blues and fitted values ##
    # AIC
    AIC.without <- summary(mod)$logo$AIC
    AIC.with <- summary(m2.sommer)$logo$AIC

    # blues
    blue <- summary(m2.sommer)$betas
    blue_sum <- 0
    is_intercept <- FALSE
    # Iterate over each row in the data
    for (i in 1:nrow(blue)) {
        # Check if the current row is an Intercept row
        if (grepl("\\(Intercept\\)", blue$Effect[i])) {
            # If it is an Intercept row, update the blue_sum variable
            blue_sum <- blue$Estimate[i]
            is_intercept <- TRUE
        } else {
            # If it is not an Intercept row, add the blue_sum to the current Estimate value
            if (is_intercept) {
                blue$BLUE[i] <- blue_sum + blue$Estimate[i]
            } else {
                # If the first row is not an Intercept row, assign NA to BLUE
                blue$BLUE[i] <- NA
            }
        }

        # Update the is_intercept flag if the next row is an Intercept row
        if (i < nrow(blue) && grepl("\\(Intercept\\)", blue$Effect[i + 1])) {
            is_intercept <- FALSE
        }
    }
    blue_tab <- blue[, c("Trait", "Effect", "BLUE", "Std.Error")]
    output <- rbind(output, blue_tab)
}

################################################################################
# 5. Write the results to files.
################################################################################
### deal with AIC output
outfile_AIC <- paste(phenotypeFile, ".AIC", sep = "")
write.table(AIC_output, outfile_AIC)

## dealing with blues output
print(colnames(output))
colnames(output) <- c("ID", "Trait", "Name", "Estimate", "Std.Error")
BLUE <- as.data.frame(output)
outfile_blue <- paste(phenotypeFile, ".blues", sep = "")
write.table(BLUE, outfile_blue)
