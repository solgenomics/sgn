# Analytical replicate contains the recorded tag, never a field occurrence.
design_source <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) design_source <- frame$ofile
if (is.null(design_source)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    design_source <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) design_source <- invocation[file_index[1] + 1L]
  }
}
if (is.null(design_source) || is.na(design_source) || !nzchar(design_source)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(design_source)), "design_replication.R"))
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
traits <- args[2]

################################################################################
# 3. Process the phenotypic data.
################################################################################
# read in the phenotypic data

userPheno <- with_design_replication(read_analysis_phenotypes(phenotypeFile))
assert_genotype_name_identity(userPheno)

# The user should be able to select their response variables from a drop-down menu
#    of the column names of the userPheno object. Then, those strings should be passed
#    to this vector, 'userResponse'.
userResponse <- unlist(strsplit(traits, split = ",", fixed = T))
userResponse <- userResponse[!userResponse == "notes"] # x[ !x == 'A'] # remove notes from userResponse
if (!"studyDesign" %in% names(userPheno)) stop("Declare studyDesign before fitting spatial design effects.")
design <- unique(tolower(trimws(userPheno$studyDesign)))
if(length(design) != 1L || anyNA(design)) stop("Fit one declared studyDesign at a time.")
userPheno$designReplicate <- factor(userPheno$designReplicate)
userPheno$blockNumber <- factor(userPheno$blockNumber)
replicate <- if(grepl("^crd$|completely randomi[sz]ed",design)) "1" else if(grepl("rcbd|randomi[sz]ed complete block|augmented",design)) "blockNumber" else if(grepl("alpha|lattice|incomplete",design)) "designReplicate/blockNumber" else stop("Unsupported declared spatial studyDesign.")
validate_design_group_terms(stats::as.formula(paste("~",replicate)),userPheno)
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
for (i in seq_along(userResponse)) {
  write(paste("userResponse:", userResponse[i]), stderr())
  # we want response variables with nas < 90% and more than one unique value
  nas <- colMeans(is.na(userPheno[userResponse[i]])) * 100
  standarddev <- sapply(userPheno[userResponse[i]], sd) # not used
  minimum <- min(userPheno[userResponse[i]], na.rm = TRUE)
  maximum <- max(userPheno[userResponse[i]], na.rm = TRUE)

  # so if nas < 90% and there is more than one unique value, run the model
  if (nas < 90 && minimum != maximum) {
    write(paste("userResponse again:", userResponse[i]), stderr())
    write(paste("Percentage of Nas:", nas), stderr())
    write(paste("userResponsedata:", userPheno[userResponse[i]]), stderr())

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
    fixedArg <- modArg
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
    # check if the model with spatial variation is better than the model without spatial variation by difference of 5 in AIC
    if (AIC.with < AIC.without - 5) {
      AIC_output <- rbind(AIC_output, data.frame(Trait = userResponse[i], AIC.without, AIC.with, Spatial.Importance = "Yes"))
    } else if (AIC.with < AIC.without) {
      AIC_output <- rbind(AIC_output, data.frame(Trait = userResponse[i], AIC.without, AIC.with, Spatial.Importance = "Maybe"))
    } else {
      AIC_output <- rbind(AIC_output, data.frame(Trait = userResponse[i], AIC.without, AIC.with, Spatial.Importance = "No"))
    }

    # blues
    blue <- summary(m2.sommer)$betas
    output <- rbind(output, blue)

    # fitted values
    fittedvals <- fitted(m2.sommer)
    colname_fitted <- paste0(userResponse[i], ".fitted")
    fitted_tab <- fittedvals$dataWithFitted[, c(userID, userResponse[i], colname_fitted)] # table with userID, trait values, and fitted values
    colnames(fitted_tab) <- c("Name", "Phenotype_values", "Fitted_values")
    fitted_tab$Phenotype_values <- round(fitted_tab$Phenotype_values, 2)
    fitted_tab$Fitted_values <- round(fitted_tab$Fitted_values, 2)
    # place userResponse[i] in first column
    fitted_tab <- data.frame(Trait = userResponse[i], fitted_tab)
    # fitted_tab <- data.frame(plotNumber = userPheno$plotNumber, fitted_tab)
    write(paste("colnames:", colnames(fitted_tab)), stderr())
    fitted_output <- rbind(fitted_output, fitted_tab)
  }
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

### deal with fitted values output
write(paste("colnames fitted:", colnames(fitted_output)), stderr())
write(paste("fitted_output:", head(fitted_output)), stderr())
outfile_fitted <- paste(phenotypeFile, ".fitted", sep = "")
write.table(fitted_output, outfile_fitted)



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


# unique_ID <- unique(userPheno$germplasmName) # create vector of unique userID
#     unique_row <- unique(userPheno$rowNumber) # create vector of unique row
#     unique_col <- unique(userPheno$colNumber) # create vector of unique col
#     df <- list(unique_ID, unique_row, unique_col) # create list of unique userID, row, and col
#     # write(paste("df:", df), stderr())

#     newdata <- expand.grid(... = df) # create data frame of all combinations of userID, row, and col
#     names(newdata) <- c("userID", "row", "col") # name columns of new data frame

#     # write(paste("newdata:", newdata), stderr())
#     R_matrix <- diag(length(unique(userPheno$R))) # create diagonal matrix of length unique R
#     C_matrix <- diag(length(unique(userPheno$C))) # create diagonal matrix of length unique C
#     Z <- kronecker(R_matrix, C_matrix) # kronecker product of R and C

#     num_combinations <- nrow(newdata) # number of combinations of userID, row, and col
#     # write(paste("num_combinations:", num_combinations), stderr())
#     # Z_list <- list(Z)
#     Z_list <- vector("list", num_combinations) # create list of length num_combinations
#     for (i in 1:num_combinations) {
#       Z_list[[i]] <- Z # fill list with Z
#     }
#     Z <- do.call(rbind, Z_list) # combine list into matrix

#     newdata$spl2Da <- with(newdata, spl2Da(col, row)) # add splines to new data frame
#     newdata[, colnames(Z)] <- Z # add random effects matrix to new data frame
#     # write(paste("newdata:", newdata), stderr())

#     # adj_means <- predict(m2.sommer, newdata, type = "response")
#     adj_means <- predict.mmer(m2.sommer, classify = userID)
#     write(paste("adj_means:", adj_means), stderr())
