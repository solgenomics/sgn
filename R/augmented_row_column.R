
args=commandArgs(TRUE)

# =============================================================================
# Augmented row-column design allocator
# - Randomizes accessions
# - Places each check once per block
# - Prevents checks from sharing the same row or column inside each block
# - Generates many valid candidate layouts and keeps the best-scored one
# - Prints and writes a field grid
# =============================================================================

if(length(args)==0){
    print("No arguments supplied.")
    ##supply default values
    paramfile=''
} else {
    for(i in 1:length(args)){
        print(paste("Processing arg ", args[[i]]));
        eval(parse(text=args[[i]]))
    }
}

source(paramfile)


library(blocksdesign)
library(agricolae)
library(dplyr)

# Augmented Row-Column Design - R version from Piepho & Williams (2016)
# vc = Number of check varieties
# The number of control or check genotypes that will be replicated across blocks.
# 
# gk = Number of row groups (super-rows)
# The layout is divided vertically into gk super-rows (each containing multiple rows).
# 
# gs = Number of column groups (super-columns)
# The layout is divided horizontally into gs super-columns (each containing multiple columns).
# 
# kb = Number of rows per row group
# Each row group contains kb rows.
# 
# sb = Number of columns per column group
# Each column group contains sb columns.
# 
# pb = Number of check plots per block
# Each block (intersection of a row group and a column group) will have pb checks.

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
validate_inputs <- function(treatments, controls, rows_in_field, cols_in_field,
                            rows_per_block, cols_per_block,
                            n_candidates = 1000) {
  rows_in_field <- as.integer(rows_in_field)
  cols_in_field <- as.integer(cols_in_field)
  rows_per_block <- as.integer(rows_per_block)
  cols_per_block <- as.integer(cols_per_block)
  n_candidates <- as.integer(n_candidates)

  if (rows_in_field <= 0 || cols_in_field <= 0) {
    stop("rows_in_field and cols_in_field must be positive integers.")
  }
  if (rows_per_block <= 0 || cols_per_block <= 0) {
    stop("rows_per_block and cols_per_block must be positive integers.")
  }
  if (is.na(n_candidates) || n_candidates <= 0) {
    stop("n_candidates must be a positive integer.")
  }
  if (rows_in_field %% rows_per_block != 0) {
    stop("rows_in_field must be divisible by rows_per_block.")
  }
  if (cols_in_field %% cols_per_block != 0) {
    stop("cols_in_field must be divisible by cols_per_block.")
  }
  if (length(controls) == 0) {
    stop("At least one control/check is required.")
  }
  if (length(unique(controls)) != length(controls)) {
    stop("controls contains duplicated names. Check names must be unique.")
  }
  if (length(unique(treatments)) != length(treatments)) {
    stop("treatments contains duplicated names. Entry names must be unique.")
  }

  n_checks <- length(controls)
  if (n_checks > rows_per_block || n_checks > cols_per_block) {
    stop(
      paste0(
        "Impossible check placement: ", n_checks, " checks must fit inside each block with no duplicated row or column, but block size is ",
        rows_per_block, " rows x ", cols_per_block, " columns. Increase block size or reduce number of checks."
      )
    )
  }

  super_rows <- rows_in_field / rows_per_block
  super_cols <- cols_in_field / cols_per_block
  n_blocks <- super_rows * super_cols
  expected_entries <- rows_in_field * cols_in_field - n_blocks * n_checks

  if (length(treatments) != expected_entries) {
    stop(
      paste0(
        "The number of treatments does not match the available entry plots. ",
        "Expected ", expected_entries, " entries, but received ", length(treatments), "."
      )
    )
  }

  invisible(TRUE)
}

make_field_template <- function(rows_in_field, cols_in_field, rows_per_block, cols_per_block) {
  super_cols <- cols_in_field / cols_per_block
  
  field <- expand.grid(
    row = seq_len(rows_in_field),
    col = seq_len(cols_in_field),
    KEEP.OUT.ATTRS = FALSE
  )
  
  field$rowgroup <- ((field$row - 1L) %/% rows_per_block) + 1L
  field$colgroup <- ((field$col - 1L) %/% cols_per_block) + 1L
  field$block <- ((field$rowgroup - 1L) * super_cols) + field$colgroup
  field$trt <- NA_character_
  field$type <- "entry"
  field
}

make_plot_order <- function(df, plot_type = "serpentine") {
  plot_type <- tolower(plot_type)
  
  if (plot_type == "serpentine") {
    df$plot_order_col <- ifelse(df$row %% 2 == 1, df$col, -df$col)
    df <- df[order(df$row, df$plot_order_col), ]
    df$plot_order_col <- NULL
  } else if (plot_type %in% c("cartesian", "rowcol", "row_col", "normal")) {
    df <- df[order(df$row, df$col), ]
  } else {
    stop("Unknown plot_type: ", plot_type, ". Use 'serpentine' or 'cartesian'.")
  }
  
  rownames(df) <- NULL
  df$plots <- seq_len(nrow(df))
  df
}


validate_check_layout <- function(df) {
  check_df <- df[df$type == "check", c("block", "row", "col", "trt")]
  
  for (b in sort(unique(check_df$block))) {
    x <- check_df[check_df$block == b, ]
    
    if (anyDuplicated(x$row)) {
      stop("Invalid plot_type: block ", b, " has more than one check in the same row.")
    }
    if (anyDuplicated(x$col)) {
      stop("Invalid plot_type: block ", b, " has more than one check in the same column.")
    }
    if (anyDuplicated(x$trt)) {
      stop("Invalid plot_type: block ", b, " has duplicated check/control labels.")
    }
  }
  
  invisible(TRUE)
}

score_count_balance <- function(x, weight) {
  if (length(x) == 0) {
    return(0)
  }
  weight * sum((as.numeric(x) - mean(as.numeric(x)))^2)
}

score_augmented_design <- function(df) {
  check_df <- df[df$type == "check", ]
  
  if (nrow(check_df) == 0) {
    return(Inf)
  }
  
  score <- 0
  
  # Pairwise Manhattan distance among checks.
  # This is simpler and faster than nested R loops for larger designs.
  coords <- as.matrix(check_df[, c("row", "col")])
  d <- as.matrix(dist(coords, method = "manhattan"))
  d <- d[upper.tri(d)]
  
  if (length(d) > 0) {
    score <- score + sum(d == 0) * 100000
    score <- score + sum(d == 1) * 500
    score <- score + sum(d == 2) * 100
    score <- score + sum(1 / d[d > 0])
  }
  
  # Balance all checks across full-field rows and columns.
  score <- score + score_count_balance(table(check_df$row), 50)
  score <- score + score_count_balance(table(check_df$col), 50)
  
  # Balance each check/control across super-rows and super-columns.
  score <- score + score_count_balance(table(check_df$trt, check_df$rowgroup), 20)
  score <- score + score_count_balance(table(check_df$trt, check_df$colgroup), 20)
  
  # Avoid same check repeated in the same full-field row or column.
  same_check_row <- table(check_df$trt, check_df$row)
  same_check_col <- table(check_df$trt, check_df$col)
  score <- score + sum(pmax(same_check_row - 1, 0)^2) * 100
  score <- score + sum(pmax(same_check_col - 1, 0)^2) * 100
  
  score
}



# -----------------------------------------------------------------------------
# Efficient augmented row-column allocator
# -----------------------------------------------------------------------------
allocate_augmented_row_column <- function(field_template, treatments, controls,
                                          rows_per_block, cols_per_block,
                                          plot_type = "serpentine") {
  field <- field_template
  n_checks <- length(controls)
  
  # Place checks block by block.
  # Each block receives one copy of each check/control.
  # check_rows and check_cols are sampled without replacement, so checks cannot
  # share row or column inside the block.
  for (b in sort(unique(field$block))) {
    block_idx <- which(field$block == b)
    block_rows <- sort(unique(field$row[block_idx]))
    block_cols <- sort(unique(field$col[block_idx]))
    
    check_rows <- sample(block_rows, n_checks, replace = FALSE)
    check_cols <- sample(block_cols, n_checks, replace = FALSE)
    check_trt <- sample(controls, n_checks, replace = FALSE)
    
    local_idx <- match(paste(check_rows, check_cols), paste(field$row[block_idx], field$col[block_idx]))
    check_idx <- block_idx[local_idx]
    
    field$trt[check_idx] <- check_trt
    field$type[check_idx] <- "check"
  }
  
  # Randomize unreplicated entries in all non-check plots.
  entry_idx <- which(field$type == "entry")
  field$trt[entry_idx] <- sample(treatments, length(entry_idx), replace = FALSE)
  
  validate_check_layout(field)
  
  field <- make_plot_order(field, plot_type = plot_type)
  field$rep <- ifelse(field$type == "check", field$block, 1L)
  field$is_control <- ifelse(field$type == "check", 1L, 0L)
  
  field
}

allocate_best_augmented_row_column <- function(treatments, controls,
                                               rows_in_field, cols_in_field,
                                               rows_per_block, cols_per_block,
                                               plot_type = "serpentine",
                                               n_candidates = 1000) {
  validate_inputs(
    treatments = treatments,
    controls = controls,
    rows_in_field = rows_in_field,
    cols_in_field = cols_in_field,
    rows_per_block = rows_per_block,
    cols_per_block = cols_per_block,
    n_candidates = n_candidates
  )
  
  field_template <- make_field_template(
    rows_in_field = rows_in_field,
    cols_in_field = cols_in_field,
    rows_per_block = rows_per_block,
    cols_per_block = cols_per_block
  )
  
  best_design <- NULL
  best_score <- Inf
  
  for (i in seq_len(as.integer(n_candidates))) {
    candidate <- allocate_augmented_row_column(
      field_template = field_template,
      treatments = treatments,
      controls = controls,
      rows_per_block = rows_per_block,
      cols_per_block = cols_per_block,
      plot_type = plot_type
    )
    
    candidate_score <- score_augmented_design(candidate)
    
    if (candidate_score < best_score) {
      best_score <- candidate_score
      best_design <- candidate
    }
  }
  
  attr(best_design, "design_score") <- best_score
  message("Best design selected from ", n_candidates, " candidates.")
  message("Best design score: ", round(best_score, 4))
  
  best_design
}


# -----------------------------------------------------------------------------
# Generate design
# -----------------------------------------------------------------------------
design_full <- allocate_best_augmented_row_column(
  treatments = treatments,
  controls = controls,
  rows_in_field = as.integer(rows_in_field),
  cols_in_field = as.integer(cols_in_field),
  rows_per_block = as.integer(rows_per_block),
  cols_per_block = as.integer(cols_per_block),
  plot_type = plot_type,
  n_candidates = 1000
)

# Keep the same output format used by the original script.
design <- design_full[, c("plots", "block", "trt", "rep", "is_control")]
colnames(design) <- c("plots", "block", "all_entries", "rep", "is_control")

# -----------------------------------------------------------------------------
# Save result file
# -----------------------------------------------------------------------------
basefile <- tools::file_path_sans_ext(paramfile)
outfile <- paste0(basefile, ".design")
sink(outfile)
write.table(design, file = outfile, quote = FALSE, sep = "\t", row.names = FALSE)
sink();






