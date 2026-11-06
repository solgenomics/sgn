# Load the explicit analytical recorded-design-tag contract.
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
source(file.path(dirname(normalizePath(design_source)), "design_replication.R"), local = TRUE)

################################################################################
# Checking for spatial correlation in the phenotypic data
################################################################################

# There are 6 main steps to this protocol:
# 1. Load the software needed.
# 2. Declare user-supplied variables.
# 3. Process the phenotypic data
# 4. Loop through the traits and check fitst for quality then spatial correlation
# 5. Format the information needed for output
# 6. Save the output


################################################################################
# 1. Load software needed
################################################################################
# Check installation of required packages
# if (!require("dplyr")) {
#     install.packages("dplyr")
# }
# if (!require("spdep")) {
#     install.packages("sf")
#     install.packages("spdep", dependencies = TRUE)
# }
# if (!require("gstat")) {
#     install.packages("gstat", dependencies = TRUE)
# }
# # if (!require("raster")) {
# #     install.packages("raster")
# # }
# if (!require("ggplot2")) {
#     install.packages("ggplot2")
# }
# if (!require("reshape2")) {
#     install.packages("reshape2")
# }
# if (!require("moments")) {
#     install.packages("moments")
# }
# if (!require("stats")) {
#     install.packages("stats")
# }
###################################################################
# Load libraries
###################################################################
library('dplyr')
library('spdep')
library('gstat')
# library(raster)
library('ggplot2')
library('reshape2')
library('moments')
library('stats')
###################################################################
# 2. Declare user-supplied variables.
###################################################################
# Get Arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
    stop("Two or more arguments are required.")
}
phenotypeFile <- args[1]
traits <- args[2]
replicate <- "replicate"
###################################################################
# 3. Process the phenotypic data
###################################################################
# read in the phenotypic data
userPheno <- read_analysis_phenotypes(phenotypeFile)
# and the traits
userResponse <- unlist(strsplit(traits, split = ",", fixed = T))
userResponse <- userResponse[!userResponse == "notes"] # x[ !x == 'A'] # remove notes from userResponse
userResponse <- userResponse[!userResponse == "X50_sprout_emergence_time_estimation_in_yy_mm_dd_CO_343_0000201"] # x[ !x == 'A']
# write(paste("userResponse:", userResponse), stderr())
###################################################################
# 4. Function for checking quality of data
###################################################################
check_quality <- function(data, phenotype, replicate) {
    ###################################################################
    # Check the percentage of missing data
    ###################################################################
    trait_vals <- data[[phenotype]]
    # print(trait_vals)
    nas <- sum(is.na(trait_vals)) / length(trait_vals) * 100
    print(nas)
    ###################################################################
    # Check the uniqueness of the data
    ###################################################################
    unique_vals <- unique(trait_vals, na.rm = TRUE)
    unique_count <- length(unique_vals)
    ###################################################################
    # Check the distribution and normality of phenotypic data
    ###################################################################
    no_na <- trait_vals[!is.na(trait_vals)]
    write(paste("no_na p-value: ", no_na), stderr())
    write(paste("no_na??: ", class(no_na)), stderr())
    if (!is.numeric(no_na)) {
      message("Data not numeric")
      skewness <- NA
      shapiro_val <- data.frame(p.value = NA)
      shapiro_val$p.value <- NA
      return ( summary_table <- data.frame(
        phenotype = phenotype,
        missing_data = nas,
        skewness = skewness,
        shapiro_val = NA,
        outliers = 0,
        unique_count = 0,
        replicate_count = 0))
    } else if (length(no_na) < 3) {
        message("Not enough data to check for normality")
        skewness <- NA
        shapiro_val <- data.frame(p.value = NA)
        shapiro_val$p.value <- NA
    } else if (unique_count < 3) {
        message("Not enough unique data to check for normality")
        skewness <- NA
        shapiro_val <- data.frame(p.value = NA)
        shapiro_val$p.value <- NA
    } else {
        skewness <- skewness(no_na) # install.packages("moments")
        shapiro_val <- shapiro.test(no_na) # install.packages("stats")
    }
    ###################################################################
    # Check the presence of outliers
    ###################################################################
    outliers <- sum(no_na > (mean(no_na) + 3 * sd(no_na)) | no_na < (mean(no_na) - 3 * sd(no_na)))

    ###################################################################
    # Check for replicated data
    ###################################################################
    # Replication QC counts observed measurements, not arbitrary design tags
    # or accession occurrence numbers (which may include unmeasured positions).
    # This plot/trait QC output does not use genotype labels. Count known IDs
    # directly when complete, preserving this workflow for duplicate names.
    genotype_groups <- data$germplasmName
    if ("germplasmDbId" %in% names(data)) {
        ids <- as.character(data$germplasmDbId)
        if (all(!is.na(ids) & !ids %in% c("", "0", "NA", "--", "-", ".", ".."))) genotype_groups <- ids
    }
    observed_counts <- tapply(!is.na(trait_vals), genotype_groups, sum)
    replicate_count <- if (length(observed_counts)) max(observed_counts) else 0
    ###################################################################
    # Create a table to summarize the results
    ###################################################################
    summary_table <- data.frame(
        phenotype = phenotype,
        missing_data = nas,
        skewness = skewness,
        shapiro_val = shapiro_val$p.value,
        outliers = outliers,
        unique_count = unique_count,
        replicate_count = replicate_count
    )
    ###################################################################
    # return the summary table
    ###################################################################
    return(summary_table)
    ###################################################################
}
###################################################################
# 5. Loop through the traits and check fitst for quality then spatial correlation
###################################################################
output <- data.frame(quality = character(0), Moran_pvalue = numeric(0), spatial_correction_needed = character(0), trait = character(0))

for (i in 1:length(userResponse)) {
    quality_summary <- check_quality(userPheno, userResponse[i], replicate)
    # write(paste("quality_summary:", quality_summary), stderr())
    if (quality_summary$missing_data > 90) {
        quality <- "too much missing data"
        Moran_pvalue <- NA
        spatial_correction_needed <- "NO"
    } else if (quality_summary$outliers > 10) {
        quality <- "too many outliers"
        Moran_pvalue <- NA
        spatial_correction_needed <- "NO"
    } else if (is.na(quality_summary$skewness) && is.na(quality_summary$shapiro_val)) {
        quality <- "not enough data to check for normality"
        Moran_pvalue <- NA
        spatial_correction_needed <- "NO"
    } else if (quality_summary$unique_count < 2) {
        quality <- "not enough unique values"
        Moran_pvalue <- NA
        spatial_correction_needed <- "NO"
    } else if (quality_summary$replicate_count < 2) {
        quality <- "not enough replicates"
        Moran_pvalue <- NA
        spatial_correction_needed <- "NO"
    } else {
        write(paste("Trait: ", userResponse[i]), stderr())
        if (quality_summary$shapiro_val < 0.05) {
            quality <- "good but not normally distributed"
            spatial_correction_needed <- "YES"
        } else if (quality_summary$skewness > 1 || quality_summary$skewness < -1) {
            quality <- "good but skewed"
            # Moran_pvalue <- NA
            spatial_correction_needed <- "YES"
        } else {
            quality <- "good data"
            spatial_correction_needed <- "YES"
        }

        ###################################################################
        # 4.2 Check for spatial correlation
        ###################################################################
        rowNumber <- "rowNumber"
        colNumber <- "colNumber"
        # obtain rows in userPheno that are not NA in the userResponse column
        userPheno_subset <- userPheno[complete.cases(userPheno[[userResponse[i]]]), ]
        # data <- data[complete.cases(data[[trait]]), ]
        # print str(userPheno_subset) to stderr()
        # write(paste("userPheno_subset:", userPheno_subset), stderr())
        # get the userResponse column and store it in trait_vals
        trait_vals <- userPheno_subset[[userResponse[i]]]
        # write(paste("Trait values: ", trait_vals), stderr())
        coordinates <- userPheno_subset[, c(rowNumber, colNumber), drop = FALSE]
        write(paste("Coordinates: ", coordinates), stderr())
        k <- 3 # Set the value of k

        # Check if there are enough data points
        num_data_points <- nrow(coordinates)
        write(paste("Number of data points: ", num_data_points), stderr())
        if (num_data_points >= k) {
            kn <- knearneigh(coordinates, k = k)
            # Continue with further processing using kn
            nb <- knn2nb(kn)
            weights <- nb2listw(nb)

            # complete_cases <- !is.na(trait_vals)
            # trait_vals <- trait_vals[complete_cases]
            moran <- moran.test(trait_vals, weights)
            write(paste("Moran p-value: ", moran$p.value), stderr())
            Moran_pvalue <- round(moran$p.value, 5)
            spatial_correction_needed <- ifelse(moran$p.value > 0.05, "NO", "YES")
        } else {
            # Handle the case when there are not enough data points
            message("There are fewer data points than k.")
        }
    }

    output <- rbind(output, data.frame(trait = userResponse[i], quality, Moran_pvalue, spatial_correction_needed))
}
write(paste("Spatial corr output: ", output), stderr())
###################################################################
# 6. Output a table with column indicating if there is spatial correlation or not and quality of data
###################################################################
outfile <- paste(phenotypeFile, ".spatial_correlation_summary", sep = "")
write.table(output, file = outfile, sep = "\t", row.names = FALSE)
###################################################################
