# SNOPSIS
# calculates genomic estimated breeding values (GEBVs) using rrBLUP,
# GBLUP method

# AUTHOR
# Isaak Y Tecle (iyt2@cornell.edu)

options(echo = FALSE)

library(methods)
library(rrBLUP)
library(plyr)
library(randomForest)
library(parallel)
library(genoDataFilter)
library(phenoAnalysis)
library(caret)
library(dplyr)
library(tibble)
library(rlang)
library(jsonlite)
library(data.table)


all_args <- commandArgs()

input_files <- scan(grep("input_files", all_args, value = TRUE),
  what = "character"
)

output_files <- scan(grep("output_files", all_args, value = TRUE),
  what = "character"
)

traits_file <- grep("traits", input_files, value = TRUE)
model_info_file <- grep("model_info", input_files, value = TRUE)
message("model_info_file ", model_info_file)

model_info <- read.table(model_info_file,
  header = TRUE, sep = "\t",
  as.is = c("Value")
)

model_info <- column_to_rownames(model_info, var = "Name")
trait_id <- model_info["trait_id", 1]
trait_abbr <- model_info["trait_abbr", 1]
model_id <- model_info["model_id", 1]
protocol_id <- model_info["protocol_id", 1]

message("class ", class(trait_abbr))
message("trait_id ", trait_id)
message("trait_abbr ", trait_abbr)
message("protocol_id ", protocol_id)
message("model_id ", model_id)

dataset_info_file <- grep("dataset_info", input_files, value = TRUE)
dataset_info <- c()

if (length(dataset_info_file) != 0) {
  dataset_info <- scan(dataset_info_file, what = "character")
  dataset_info <- paste(dataset_info, collapse = " ")
} else {
  dataset_info <- c("single population")
}

validation_file <- grep("validation", output_files, value = TRUE)

if (is.null(validation_file)) {
  stop("Validation output file is missing.")
}

blup_file <- grep("rrblup_training_gebvs", output_files, value = TRUE)

if (is.null(blup_file)) {
  stop("GEBVs file is missing.")
}

marker_file <- grep("marker_effects", output_files, value = TRUE)

model_pheno_file <- grep("model_pheno_data", output_files, value = TRUE)
message("model input trait pheno file ", model_pheno_file)
trait_raw_pheno_file <- grep("trait_raw_pheno_data", output_files, value = TRUE)
variance_components_file <- grep("variance_components", output_files, value = TRUE)
filtered_geno_file <- grep("filtered_genotype_data", output_files, value = TRUE)
formatted_pheno_file <- grep("formatted_phenotype_data", input_files, value = TRUE)

geno_file <- grep("genotype_data_", input_files, value = TRUE)

if (is.null(geno_file)) {
  stop("genotype data file is missing.")
}

if (file.info(geno_file)$size == 0) {
  stop("genotype data file is empty.")
}

read_filtered_geno_gata <- c()
filtered_geno_data <- c()
formatted_pheno_data <- c()
pheno_data <- c()
geno_data <- c()

if (length(filtered_geno_file) != 0 && file.info(filtered_geno_file)$size != 0) {
  filtered_geno_data <- fread(filtered_geno_file,
    na.strings = c("NA", "", "--", "-"),
    header = TRUE
  )

  geno_data <- data.frame(filtered_geno_data)
  geno_data <- column_to_rownames(geno_data, "V1")
  read_filtered_geno_gata <- 1
}


if (is.null(filtered_geno_data)) {
  geno_data <- fread(geno_file,
    na.strings = c("NA", "", "--", "-"),
    header = TRUE
  )

  geno_data <- unique(geno_data, by = "V1")
  geno_data <- data.frame(geno_data)
  geno_data <- column_to_rownames(geno_data, "V1")

  # genoDataFilter::filterGenoData
  geno_data <- convertToNumeric(geno_data)
  geno_data <- filterGenoData(geno_data, maf = 0.01)
  geno_data <- roundAlleleDosage(geno_data)

  filtered_geno_data <- geno_data
}

geno_data <- geno_data[order(row.names(geno_data)), ]

if (length(formatted_pheno_file) != 0 && file.info(formatted_pheno_file)$size != 0) {
  formatted_pheno_data <- data.frame(fread(formatted_pheno_file,
    header = TRUE,
    na.strings = c("NA", "", "--", "-", ".")
  ))
} else {
  if (dataset_info == "combined populations") {
    pheno_file <- grep("model_pheno_data", input_files, value = TRUE)
  } else {
    pheno_file <- grep("\\/phenotype_data", input_files, value = TRUE)
  }

  if (is.null(pheno_file)) {
    stop("phenotype data file is missing.")
  }

  if (file.info(pheno_file)$size == 0) {
    stop("phenotype data file is empty.")
  }

  pheno_data <- data.frame(fread(pheno_file,
    sep = "\t",
    na.strings = c("NA", "", "--", "-", "."),
    header = TRUE
  ))
}

pheno_trait <- c()
trait_raw_pheno_data <- c()

if (dataset_info == "combined populations") {
  if (!is.null(formatted_pheno_data)) {
    pheno_trait <- subset(formatted_pheno_data, select = trait_abbr)
    pheno_trait <- na.omit(pheno_trait)
  } else {
    if (any(grepl("Average", names(pheno_data)))) {
      pheno_trait <- pheno_data %>%
        select(V1, Average) %>%
        data.frame()
    } else {
      pheno_trait <- pheno_data
    }

    colnames(pheno_trait) <- c("genotypes", trait_abbr)
  }
} else {
  if (!is.null(formatted_pheno_data)) {
    pheno_trait <- subset(formatted_pheno_data, select = c("V1", trait_abbr))
    pheno_trait <- as.data.frame(pheno_trait)
    pheno_trait <- na.omit(pheno_trait)
    print(head(pheno_trait))
    colnames(pheno_trait)[1] <- "genotypes"
  } else if (length(grep("list", pheno_file)) != 0) {
    message("pheno_trait trait_abbr ", trait_abbr)
    pheno_trait <- averageTrait(pheno_data, trait_abbr)
  } else {
    print(head(pheno_trait))
    print(head(pheno_data))
    message("pheno_trait trait_abbr ", trait_abbr)
    print(class(trait_abbr))
    print(trait_abbr)
    pheno_trait <- getAdjMeans(pheno_data,
      traitName = trait_abbr,
      calcAverages = TRUE
    )
  }

  keep_meta_cols <- c(
    "observationUnitName", "germplasmName", "studyDbId", "locationName",
    "studyYear", "replicate", "blockNumber", trait_abbr
  )

  trait_raw_pheno_data <- pheno_data %>%
    select(all_of(keep_meta_cols))
}

print("pheno_trait")
print(head(pheno_trait))
mean_type <- names(pheno_trait)[2]
names(pheno_trait) <- c("genotypes", trait_abbr)

selection_temp_file <- grep("selection_population", input_files, value = TRUE)

selection_file <- c()
filtered_pred_geno_file <- c()
selection_all_files <- c()

if (length(selection_temp_file) != 0) {
  selection_all_files <- scan(selection_temp_file, what = "character")

  selection_file <- grep("\\/genotype_data", selection_all_files, value = TRUE)

  # filtered_pred_geno_file   <- grep("filtered_genotype_data_",  selection_all_files, value = TRUE)
}

selection_pop_gebvs_file <- grep("rrblup_selection_gebvs", output_files, value = TRUE)

selection_data <- c()
read_filtered_pred_geno_data <- c()
filtered_pred_geno_data <- c()

## if (length(filtered_pred_geno_file) != 0 && file.info(filtered_pred_geno_file)$size != 0) {
##   selection_data <- fread(filtered_pred_geno_file, na.strings = c("NA", " ", "--", "-"),)
##   read_filtered_pred_geno_data <- 1

##   selection_data <- data.frame(selection_data)
##   rownames(selection_data) <- selection_data[, 1]
##   selection_data[, 1]      <- NULL

## } else
if (length(selection_file) != 0) {
  selection_data <- fread(selection_file,
    header = TRUE,
    na.strings = c("NA", "", "--", "-")
  )

  selection_data <- unique(selection_data, by = "V1")
  selection_data <- data.frame(selection_data)
  selection_data <- column_to_rownames(selection_data, "V1")

  selection_data <- convertToNumeric(selection_data)
  selection_data <- filterGenoData(selection_data, maf = 0.01)
  selection_data <- roundAlleleDosage(selection_data)

  filtered_pred_geno_data <- selection_data
}


# impute genotype values for obs with missing values,
geno_data_missing <- c()

if (sum(is.na(geno_data)) > 0) {
  geno_data_missing <- c("yes")

  geno_data <- na.roughfix(geno_data)
  geno_data <- data.frame(geno_data)
}

# create phenotype and genotype datasets with
# common stocks only

# extract observation lines with both
# phenotype and genotype data only.
common_obs <- intersect(pheno_trait$genotypes, row.names(geno_data))
common_obs <- data.frame(common_obs)
rownames(common_obs) <- common_obs[, 1]

# include in the genotype dataset only phenotyped lines
geno_data_filtered_obs <- geno_data[(rownames(geno_data) %in% rownames(common_obs)), ] # nolint

# drop phenotyped lines without genotype data
pheno_trait <- pheno_trait[(pheno_trait$genotypes %in% rownames(common_obs)), ]

pheno_trait_marker <- data.frame(pheno_trait)
rownames(pheno_trait_marker) <- pheno_trait_marker[, 1]
pheno_trait_marker[, 1] <- NULL

# impute missing data in prediction data
selection_data_missing <- c()
if (length(selection_data) != 0) {
  # purge markers unique to both populations
  common_markers <- intersect(names(data.frame(geno_data_filtered_obs)), names(selection_data))
  selection_data <- subset(selection_data, select = common_markers)
  geno_data_filtered_obs <- subset(geno_data_filtered_obs, select = common_markers)

  if (sum(is.na(selection_data)) > 0) {
    selection_data_missing <- c("yes")
    selection_data <- na.roughfix(selection_data)
    selection_data <- data.frame(selection_data)
  }
}

# change genotype coding to [-1, 0, 1], to use the A.mat ) if  [0, 1, 2]
geno_tr_code <- grep("2", geno_data_filtered_obs[1, ], value = TRUE)
if (length(geno_tr_code) != 0) {
  geno_data <- geno_data - 1
  geno_data_filtered_obs <- geno_data_filtered_obs - 1
}

if (length(selection_data) != 0) {
  geno_sl_code <- grep("2", selection_data[1, ], value = TRUE)
  if (length(geno_sl_code) != 0) {
    selection_data <- selection_data - 1
  }
}

ordered.marker_effects <- c()
tr_gebv <- c()
validation_all <- c()
combined_gebvs_file <- c()
all_gebvs <- c()
model_pheno_data <- c()
kinship_matrix <- c()

# additive relationship model
# calculate the inner products for
# genotypes (realized relationship matrix)
kinship_matrix_file <- grep("relationship_matrix_table",
  output_files,
  value = TRUE
)
kinship_matrix_json_file <- grep("relationship_matrix_json",
  output_files,
  value = TRUE
)

trait_kinship_matrix_file <- grep("relationship_matrix_adjusted_table",
  output_files,
  value = TRUE
)
trait_kinship_matrix_json_file <- grep("relationship_matrix_adjusted_json",
  output_files,
  value = TRUE
)

inbreeding_file <- grep("inbreeding_coefficients", output_files, value = TRUE)
ave_kinship_file <- grep("average_kinship", output_files, value = TRUE)

inbreeding <- c()
ave_kinship <- c()

if (length(kinship_matrix_file) != 0) {
  if (file.info(kinship_matrix_file)$size > 0) {
    kinship_matrix <- data.frame(fread(kinship_matrix_file,
      header = TRUE
    ))

    rownames(kinship_matrix) <- kinship_matrix[, 1]
    kinship_matrix[, 1] <- NULL
    colnames(kinship_matrix) <- rownames(kinship_matrix)
    kinship_matrix <- data.matrix(kinship_matrix)
  } else {
    kinship_matrix <- A.mat(geno_data)
    diag(kinship_matrix) <- diag(kinship_matrix) + 1e-6

    inbreeding <- diag(kinship_matrix)
    inbreeding <- inbreeding - 1

    inbreeding <- inbreeding %>% replace(., . < 0, 0)
    inbreeding <- data.frame(inbreeding)

    inbreeding <- inbreeding %>%
      rownames_to_column("genotypes") %>%
      rename(Inbreeding = inbreeding) %>%
      arrange(Inbreeding) %>%
      mutate_at("Inbreeding", round, 3) %>%
      column_to_rownames("genotypes")
  }
}

kinship_matrix <- data.frame(kinship_matrix)
colnames(kinship_matrix) <- rownames(kinship_matrix)

kinship_matrix <- rownames_to_column(kinship_matrix, var = "genotypes")
kinship_matrix <- kinship_matrix %>% mutate_if(is.numeric, round, 3)
kinship_matrix <- column_to_rownames(kinship_matrix, var = "genotypes")

trait_kinship_matrix <- kinship_matrix[(rownames(kinship_matrix) %in% rownames(common_obs)), ]
trait_kinship_matrix <- trait_kinship_matrix[, (colnames(trait_kinship_matrix) %in% rownames(common_obs))]

trait_kinship_matrix <- data.matrix(trait_kinship_matrix)

# relationshipMatrixFiltered <- relationshipMatrixFiltered + 1e-3

n_cores <- detectCores()

if (n_cores > 1) {
  n_cores <- (n_cores %/% 2)
} else {
  n_cores <- 1
}


if (length(selection_data) == 0) {
  training_model <- kin.blup(
    data = pheno_trait,
    geno = "genotypes",
    pheno = trait_abbr,
    K = trait_kinship_matrix,
    n.core = n_cores,
    PEV = TRUE
  )

  tr_gebv <- training_model$g
  tr_gebv_pev <- training_model$PEV
  tr_gebv_se <- sqrt(tr_gebv_pev)
  tr_gebv_se <- data.frame(round(tr_gebv_se, 2))

  tr_gebv <- data.frame(round(tr_gebv, 2))

  colnames(tr_gebv_se) <- c("SE")
  colnames(tr_gebv) <- trait_abbr

  tr_gebv_se <- rownames_to_column(tr_gebv_se, var = "genotypes")
  tr_gebv <- rownames_to_column(tr_gebv, var = "genotypes")

  tr_gebv_se <- full_join(tr_gebv, tr_gebv_se)

  tr_gebv_se <- tr_gebv_se %>% arrange_(.dots = paste0("desc(", trait_abbr, ")"))

  tr_gebv_se <- column_to_rownames(tr_gebv_se, var = "genotypes")

  tr_gebv <- tr_gebv %>% arrange_(.dots = paste0("desc(", trait_abbr, ")"))
  tr_gebv <- column_to_rownames(tr_gebv, var = "genotypes")

  pheno_trait_marker <- data.matrix(pheno_trait_marker)
  geno_data_filtered_obs <- data.matrix(geno_data_filtered_obs)

  marker_effects <- mixed.solve(
    y = pheno_trait_marker,
    Z = geno_data_filtered_obs
  )

  ordered.marker_effects <- data.matrix(marker_effects$u)
  ordered.marker_effects <- data.matrix(ordered.marker_effects[order(-ordered.marker_effects[, 1]), ])
  ordered.marker_effects <- round(ordered.marker_effects, 5)

  colnames(ordered.marker_effects) <- c("Marker Effects")
  ordered.marker_effects <- data.frame(ordered.marker_effects)


  model_pheno_data <- data.frame(round(pheno_trait_marker, 2))

  heritability <- round((training_model$Vg / (training_model$Ve + training_model$Vg)), 2)
  additive_var <- round(training_model$Vg, 2)
  error_var <- round(training_model$Ve, 2)

  cat("\n", file = variance_components_file, append = FALSE)
  cat("Additive genetic variance", additive_var,
    file = variance_components_file, sep = "\t", append = TRUE
  )
  cat("\n", file = variance_components_file, append = TRUE)
  cat("Error variance", error_var, file = variance_components_file, sep = "\t", append = TRUE)
  cat("\n", file = variance_components_file, append = TRUE)
  cat("SNP heritability (h)", heritability,
    file = variance_components_file,
    sep = "\t", append = TRUE
  )

  combined_gebvs_file <- grep("selected_traits_gebv",
    output_files,
    ignore.case = TRUE, value = TRUE
  )

  if (length(combined_gebvs_file) != 0) {
    file_size <- file.info(combined_gebvs_file)$size
    if (file_size != 0) {
      combined_gebvs <- data.frame(fread(combined_gebvs_file,
        header = TRUE
      ))

      rownames(combined_gebvs) <- combined_gebvs[, 1]
      combined_gebvs[, 1] <- NULL

      all_gebvs <- merge(combined_gebvs, tr_gebv,
        by = 0,
        all = TRUE
      )

      rownames(all_gebvs) <- all_gebvs[, 1]
      all_gebvs[, 1] <- NULL
    }
  }

  # cross-validation

  if (is.null(selection_file)) {
    geno_count <- nrow(pheno_trait)

    if (geno_count < 20) {
      warning(geno_count, " is too small number of genotypes.")
    }

    set.seed(4567)

    k <- 10
    times <- 2
    cv_folds <- createMultiFolds(pheno_trait[, 2], k = k, times = times)

    for (r in 1:times) {
      re <- paste0("Rep", r)

      for (i in 1:k) {
        fo <- ifelse(i < 10, "Fold0", "Fold")

        tr_fo_re <- paste0(fo, i, ".", re)
        tr_g <- cv_folds[[tr_fo_re]]
        sl_g <- as.numeric(rownames(pheno_trait[-tr_g, ]))

        kblup <- paste("rKblup", i, sep = ".")

        result <- kin.blup(
          data = pheno_trait[tr_g, ],
          geno = "genotypes",
          pheno = trait_abbr,
          K = trait_kinship_matrix,
          n.core = n_cores,
          PEV = TRUE
        )

        assign(kblup, result)

        # calculate cross-validation accuracy
        val_blups <- result$g

        val_blups <- data.frame(val_blups)

        sl_g <- sl_g[which(sl_g <= nrow(pheno_trait))]

        sl_G_df <- pheno_trait[(rownames(pheno_trait) %in% sl_g), ]
        rownames(sl_G_df) <- sl_G_df[, 1]
        sl_G_df[, 1] <- NULL

        val_blups <- rownames_to_column(val_blups, var = "genotypes")
        sl_G_df <- rownames_to_column(sl_G_df, var = "genotypes")

        val_cor_data <- inner_join(sl_G_df, val_blups, by = "genotypes")
        val_cor_data$genotypes <- NULL

        accuracy <- try(cor(val_cor_data))
        validation <- paste("validation", tr_fo_re, sep = ".")
        cv_test <- paste("CV", tr_fo_re, sep = " ")

        if (inherits(accuracy, "try-error") == FALSE) {
          accuracy <- round(accuracy[1, 2], digits = 3)
          accuracy <- data.matrix(accuracy)

          colnames(accuracy) <- c("correlation")
          rownames(accuracy) <- cv_test

          assign(validation, accuracy)

          if (!is.na(accuracy[1, 1])) {
            validation_all <- rbind(validation_all, accuracy)
          }
        }
      }
    }

    validation_all <- data.frame(validation_all[order(-validation_all[, 1]), ])
    colnames(validation_all) <- c("Correlation")
  }
}

selection_pop_result <- c()
selection_pop_gebvs <- c()
selection_pop_gebv_se <- c()

if (length(selection_data) != 0) {
  geno_data_tr_sl <- rbind(geno_data_filtered_obs, selection_data)
  kinship_tr_sl_combined <- A.mat(geno_data_tr_sl)

  selection_pop_result <- kin.blup(
    data = pheno_trait,
    geno = "genotypes",
    pheno = trait_abbr,
    K = kinship_tr_sl_combined,
    n.core = n_cores,
    PEV = TRUE
  )

  selection_pop_gebvs <- round(data.frame(selection_pop_result$g), 2)
  colnames(selection_pop_gebvs) <- trait_abbr
  selection_pop_gebvs <- rownames_to_column(
    selection_pop_gebvs,
    var = "genotypes"
  )

  selection_pop_pev <- selection_pop_result$PEV
  selection_pop_se <- sqrt(selection_pop_pev)
  selection_pop_se <- data.frame(round(selection_pop_se, 2))
  colnames(selection_pop_se) <- "SE"
  selection_pop_genotypes <- rownames(selection_data)

  selection_pop_se <- rownames_to_column(selection_pop_se, var = "genotypes")
  selection_pop_se <- selection_pop_se %>%
    filter(genotypes %in% selection_pop_genotypes)

  selection_pop_gebvs <- selection_pop_gebvs %>%
    filter(genotypes %in% selection_pop_genotypes)

  selection_pop_gebv_se <- inner_join(selection_pop_gebvs, selection_pop_se, by = "genotypes")

  sort_var <- parse_expr(trait_abbr)
  selection_pop_gebvs <- selection_pop_gebvs %>%
    arrange(desc((!!sort_var)))
  selection_pop_gebvs <- column_to_rownames(selection_pop_gebvs,
    var = "genotypes"
  )

  selection_pop_gebv_se <- selection_pop_gebv_se %>%
    arrange(desc((!!sort_var)))

  selection_pop_gebv_se <- column_to_rownames(selection_pop_gebv_se, var = "genotypes")
}

if (!is.null(selection_pop_gebvs) & length(selection_pop_gebvs_file) != 0) {
  fwrite(selection_pop_gebvs,
    file = selection_pop_gebvs_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}

if (!is.null(validation_all)) {
  fwrite(validation_all,
    file = validation_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}


if (!is.null(ordered.marker_effects)) {
  fwrite(ordered.marker_effects,
    file = marker_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}


if (!is.null(tr_gebv)) {
  fwrite(tr_gebv,
    file = blup_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}

if (length(combined_gebvs_file) != 0) {
  if (file.info(combined_gebvs_file)$size == 0) {
    fwrite(tr_gebv,
      file = combined_gebvs_file,
      row.names = TRUE,
      sep = "\t",
      quote = FALSE,
    )
  } else {
    fwrite(all_gebvs,
      file = combined_gebvs_file,
      row.names = TRUE,
      sep = "\t",
      quote = FALSE,
    )
  }
}


if (!is.null(model_pheno_data) & length(model_pheno_file) != 0) {
  if (!is.null(mean_type)) {
    colnames(model_pheno_data) <- mean_type
  }

  fwrite(model_pheno_data,
    file = model_pheno_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}

if (!is.null(trait_raw_pheno_data) & length(trait_raw_pheno_file) != 0) {
  fwrite(trait_raw_pheno_data,
    file = trait_raw_pheno_file,
    row.names = FALSE,
    sep = "\t",
    na = "NA",
    quote = FALSE,
  )
}



if (!is.null(filtered_geno_data) && is.null(read_filtered_geno_gata)) {
  fwrite(filtered_geno_data,
    file = filtered_geno_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}

## if (length(filtered_pred_geno_file) != 0 && is.null(read_filtered_pred_geno_data)) {
##   fwrite(filtered_pred_geno_data,
##          file  = filtered_pred_geno_file,
##          row.names = TRUE,
##          sep   = "\t",
##          quote = FALSE,
##          )
## }

## if (!is.null(geno_data_missing)) {
##   write.table(geno_data,
##               file = geno_file,
##               sep = "\t",
##               col.names = NA,
##               quote = FALSE,
##             )

## }

## if (!is.null(predictionDataMissing)) {
##   write.table(predictionData,
##               file = predictionFile,
##               sep = "\t",
##               col.names = NA,
##               quote = FALSE,
##               )
## }


if (file.info(kinship_matrix_file)$size == 0) {
  fwrite(kinship_matrix,
    file = kinship_matrix_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}

if (file.info(kinship_matrix_json_file)$size == 0) {
  kinship_matrix_json <- kinship_matrix
  kinship_matrix_json[upper.tri(kinship_matrix_json)] <- NA


  kinship_matrix_json <- data.frame(kinship_matrix_json)

  kinship_matrix_list <- list(
    labels = names(kinship_matrix_json),
    values = kinship_matrix_json
  )

  kinship_matrix_json <- jsonlite::toJSON(kinship_matrix_list)


  write(kinship_matrix_json,
    file = kinship_matrix_json_file,
  )
}


if (file.info(trait_kinship_matrix_file)$size == 0) {
  inbre <- diag(trait_kinship_matrix)
  inbre <- inbre - 1

  diag(trait_kinship_matrix) <- inbre

  trait_kinship_matrix <- data.frame(trait_kinship_matrix) %>%
    replace(., . < 0, 0)

  fwrite(trait_kinship_matrix,
    file = trait_kinship_matrix_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )

  if (file.info(trait_kinship_matrix_json_file)$size == 0) {
    trait_kinship_matrix_json <- trait_kinship_matrix
    trait_kinship_matrix_json[upper.tri(trait_kinship_matrix_json)] <- NA

    trait_kinship_matrix_json <- data.frame(trait_kinship_matrix_json)

    trait_kinship_matrix_list <- list(
      labels = names(trait_kinship_matrix_json),
      values = trait_kinship_matrix_json
    )

    trait_kinship_matrix_json <- jsonlite::toJSON(trait_kinship_matrix_list)

    write(trait_kinship_matrix_json,
      file = trait_kinship_matrix_json_file,
    )
  }
}


if (file.info(inbreeding_file)$size == 0) {
  fwrite(inbreeding,
    file = inbreeding_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}


if (file.info(ave_kinship_file)$size == 0) {
  ave_kinship <- data.frame(apply(trait_kinship_matrix, 1, mean))

  ave_kinship <- ave_kinship %>%
    rownames_to_column("genotypes") %>%
    rename(Mean_kinship = contains("traitRe")) %>%
    arrange(Mean_kinship) %>%
    mutate_at("Mean_kinship", round, 3) %>%
    column_to_rownames("genotypes")

  fwrite(ave_kinship,
    file = ave_kinship_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}


if (file.info(formatted_pheno_file)$size == 0 && !is.null(formatted_pheno_data)) {
  fwrite(formatted_pheno_data,
    file = formatted_pheno_file,
    row.names = TRUE,
    sep = "\t",
    quote = FALSE,
  )
}

message("Done.")

q(save = "no", runLast = FALSE)