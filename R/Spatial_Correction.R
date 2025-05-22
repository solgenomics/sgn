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
library(spdep)
library(dplyr)

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
row_col_as_rc <- args[3]
genotype_as_random <- FALSE
if (args[4] == 1) {
    genotype_as_random <- TRUE
}
nseg_degree <- as.numeric(args[5])
print(nseg_degree)
spatialHeaders <- args[6]


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
# write(colnames(userPheno), stderr())

userResponse <- unlist(strsplit(traits, split = ",", fixed = T))
userResponse <- userResponse[!userResponse == "notes"] # x[ !x == 'A'] # remove notes from userResponse
rownames(userPheno) <- userPheno$observationUnitName
userPheno$germplasmName <- as.factor(userPheno$germplasmName)
userPheno$R <- as.factor(userPheno$rowNumber)
userPheno$C <- as.factor(userPheno$colNumber)

output <- data.frame(
    observationUnitName = userPheno$observationUnitName,
    germplasmName = userPheno$germplasmName,
    rowNumber = userPheno$rowNumber,
    colNumber = userPheno$colNumber,
    replicate = userPheno$replicate,
    blockNumber = userPheno$blockNumber,
    plotNumber = userPheno$plotNumber
)

round_to_even <- function(n) {
    ifelse(n %% 2 == 0, round(n), round(n / 2) * 2)
}

moran_outfile <- paste(phenotypeFile, ".moran", sep="")

for (trait in userResponse) {
    spatial_model <- NULL
    if (row_col_as_rc == 1) {
        spatial_model <- SpATS(
            response = trait,
            spatial = ~ PSANOVA(colNumber, rowNumber, 
                nseg = c(round_to_even(max(userPheno$colNumber, na.rm = TRUE) * nseg_degree), round_to_even(max(userPheno$rowNumber, na.rm = TRUE) * nseg_degree)),
                degree = c(3,3),
                nest.div = 2),
            genotype = "germplasmName",
            genotype.as.random = genotype_as_random,
            random = ~ R + C ,
            fixed = NULL,
            data = userPheno,
            control = list(tolerance = 1e-03, monitoring = 1)
        )
    } else {
        spatial_model <- SpATS(
            response = trait,
            spatial = ~ PSANOVA(colNumber, rowNumber, 
                nseg = c(round_to_even(max(userPheno$colNumber) * nseg_degree), round_to_even(max(userPheno$rowNumber) * nseg_degree)),
                degree = c(3,3),
                nest.div = 2),
            genotype = "germplasmName",
            genotype.as.random = genotype_as_random,
            # random = ~ R + C ,
            data = userPheno,
            fixed = NULL,
            control = list(tolerance = 1e-03, monitoring = 1)
        )
    }
    
    summary(spatial_model)
    residuals <- as.data.frame(residuals(spatial_model))
    acc_blues <- as.data.frame(predict.SpATS(spatial_model, which='germplasmName'))

    userPheno$residuals <- residuals[["residuals(spatial_model)"]]

    plot_adjusted_vals <- merge(userPheno, acc_blues, by = 'germplasmName', sort = FALSE, all.x = TRUE)
    rownames(plot_adjusted_vals) <- plot_adjusted_vals$observationUnitName

    coordinates <- userPheno[, c("rowNumber", "colNumber"), drop = FALSE]
    k <- 3
    kn <- knearneigh(coordinates, k = k)
    nb <- knn2nb(kn)
    weights <- nb2listw(nb)
    moran <- NULL
    tryCatch({
            moran <- moran.test(plot_adjusted_vals[[trait]] + plot_adjusted_vals$residuals, weights, na.action = na.exclude )
        },
        error = function(e) { #This happens when there is missing data. 
            moran$p.value <- NaN
        }, 
        finally = {
            print(paste("Moran p-value for trait ",trait, " : ", moran$p.value)) #sanity check, spatial autocorrelation should be gone, residuals should not show a spatial pattern
            cat(trait, moran$p.value, sep="\t", file = moran_outfile)
        }
    )
    domain <- NULL
    range <- list(min = min(userPheno[[trait]], na.rm = TRUE), max = max(userPheno[[trait]], na.rm = TRUE))
    if (range$min >= 0 & range$max > 0) { #strictly positive trait vals
        domain <- list(min = 0, max = Inf)
    } else if (range$min < 0 & range$max > 0) { # pos or neg trait vals
        domain <- list(min = -Inf, max = Inf)
    } else { # strictly neg trait vals
        domain <- list(min = -Inf, max = 0)
    }

    output[[trait]] <- userPheno[[trait]]
    output[[paste(trait, "_spatially_corrected", sep = "")]] <- plot_adjusted_vals[[trait]] + plot_adjusted_vals$residuals
    output[[paste(trait, "_spatially_corrected", sep = "")]][output[[paste(trait, "_spatially_corrected", sep = "")]] < domain$min] <- domain$min #prevent out of bounds values
    output[[paste(trait, "_spatially_corrected", sep = "")]][output[[paste(trait, "_spatially_corrected", sep = "")]] > domain$max] <- domain$max
    output[[paste(trait, "_spatial_adjustment", sep = "")]] <- output[[paste(trait, "_spatially_corrected", sep = "")]] - output[[trait]]
}

outfile <- paste(phenotypeFile, ".spatially_corrected", sep="")

write.table(output, file = outfile, quote = FALSE, sep = "\t", col.names = TRUE, row.names = FALSE)
