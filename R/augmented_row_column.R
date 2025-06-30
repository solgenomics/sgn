
args=commandArgs(TRUE)

##args is now a list of character vectors
## First check to see if arguments are passed.
## Then cycle through each element of the list and evaluate the expressions.

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

super_rows <- rows_in_field/rows_per_block #gk
super_cols <- cols_in_field/cols_per_block #gs

n_block <- super_rows * super_cols

n_checks <- length(controls) #vc = pb
n_treatments <- length(treatments)


# Step 1: Generate initial layout files
generate_layout_files <- function(g_k, g_s, k_b, s_b, p_b) {
  layout <- expand.grid(rowgroup = 1:g_k, colgroup = 1:g_s)
  layout$no_of_plots_per_block <- p_b
  
  rows_per_rowgroup <- data.frame(
    rowgroup = 1:g_k,
    no_of_rows = rep(k_b, g_k)
  )
  
  cols_per_colgroup <- data.frame(
    colgroup = 1:g_s,
    no_of_cols = rep(s_b, g_s)
  )
  
  list(layout = layout, rows = rows_per_rowgroup, cols = cols_per_colgroup)
}

# Step 2: Expand layout into full plot list
expand_layout <- function(layout_df) {
  layout_expanded <- layout_df[rep(1:nrow(layout_df), layout_df$no_of_plots_per_block), ]
  layout_expanded$plot_in_block <- ave(layout_expanded$rowgroup, layout_expanded$rowgroup, layout_expanded$colgroup, FUN = seq_along)
  layout_expanded
}

# Step 3: Generate row and column coordinates
expand_rows_cols <- function(rows_df, cols_df) {
  row_coords <- unlist(mapply(function(group, n) rep(group, each = n),
                              rows_df$rowgroup, rows_df$no_of_rows))
  col_coords <- unlist(mapply(function(group, n) rep(group, each = n),
                              cols_df$colgroup, cols_df$no_of_cols))
  
  list(row_coords = row_coords, col_coords = col_coords)
}

# Step 4: Assign checks (one per row/col/block in a valid configuration)
assign_checks <- function(layout_df, v_c) {
  layout_df$type <- NA
  layout_df$trt <- NA
  
  blocks <- unique(paste(layout_df$rowgroup, layout_df$colgroup, sep = "."))
  check_labels <- LETTERS[1:v_c]
  
  used_rows <- list()
  used_cols <- list()
  result <- list()
  
  for (b in blocks) {
    block_df <- subset(layout_df, paste(rowgroup, colgroup, sep = ".") == b)
    block_id <- unique(paste(block_df$rowgroup, block_df$colgroup, sep = "."))
    
    block_rows <- unique(block_df$row)
    block_cols <- unique(block_df$col)
    
    assigned <- data.frame()
    remaining_checks <- check_labels
    
    for (chk in remaining_checks) {
      pos <- subset(block_df,
                    !(row %in% used_rows[[chk]]) &
                      !(col %in% used_cols[[chk]]))
      if (nrow(pos) == 0) stop(paste("Cannot assign check", chk, "in block", b))
      
      chosen <- pos[1, ]
      chosen$type <- "check"
      chosen$trt <- chk
      
      used_rows[[chk]] <- unique(c(used_rows[[chk]], chosen$row))
      used_cols[[chk]] <- unique(c(used_cols[[chk]], chosen$col))
      
      block_df <- dplyr::anti_join(block_df, chosen, by = c("row", "col"))
      assigned <- rbind(assigned, chosen)
    }
    
    result[[length(result) + 1]] <- rbind(assigned, block_df)
  }
  
  do.call(rbind, result)
}

# Step 5: Fill in unreplicated entries
assign_unreplicated <- function(df, n_entries) {
  empty_slots <- which(is.na(df$trt))
  entry_labels <- paste0("E", seq_len(n_entries))
  df$trt[empty_slots] <- sample(entry_labels, length(empty_slots))
  df$type[empty_slots] <- "entry"
  df
}

# Step 6: Simulate and return dataframe layout with placeholders for checks and block assignments
augmented_design_df <- function(vc, gk, gs, kb, sb, pb) {
  total_rows <- gk * kb
  total_cols <- gs * sb
  total_blocks <- gk * gs
  total_plots <- total_blocks * pb
  ve <- total_rows * total_cols - total_plots

  field <- expand.grid(row = 1:total_rows, col = 1:total_cols)
  field$trt <- NA
  field$type <- NA
  field$block <- NA

  block_id <- 1
  for (i in 0:(gk - 1)) {
    for (j in 0:(gs - 1)) {
      block_rows <- (i * kb + 1):(i * kb + kb)
      block_cols <- (j * sb + 1):(j * sb + sb)
      block_cells <- expand.grid(row = block_rows, col = block_cols)

      # Only keep positions with unique row/col combinations
      success <- FALSE
      max_tries <- 1000
      tries <- 0
      while (!success && tries < max_tries) {
        tries <- tries + 1
        sampled <- block_cells[sample(nrow(block_cells)), ]
        sampled_unique <- sampled[!duplicated(sampled$row) & !duplicated(sampled$col), ]
        if (nrow(sampled_unique) >= pb) {
          check_cells <- sampled_unique[1:pb, ]
          success <- TRUE
        }
      }

      if (!success) {
        stop(paste("Failed to assign non-conflicting checks in block", block_id))
      }

      for (k in 1:pb) {
        r <- check_cells$row[k]
        c <- check_cells$col[k]
        field$trt[field$row == r & field$col == c] <- "C"
        field$type[field$row == r & field$col == c] <- "check"
      }

      idx <- with(field, row %in% block_rows & col %in% block_cols)
      field$block[idx] <- block_id
      block_id <- block_id + 1
    }
  }

  entry_index <- 1
  for (i in 1:nrow(field)) {
    if (is.na(field$trt[i])) {
      field$trt[i] <- paste0("E", entry_index)
      field$type[i] <- "entry"
      entry_index <- entry_index + 1
    }
  }

  return(field)
}




# Generating Design
df <- augmented_design_df(vc =n_checks,gk = super_rows, gs = super_cols, kb = rows_per_block, sb = cols_per_block, pb = n_checks )


df2 <- df[df$trt == "C", ] %>% select(block, row, col) %>% arrange(block, col, row)


checks_vec <- factor(rep(controls, n_block))


df2$block <- as.factor(df2$block)
df2$row <- as.factor(df2$row)
df2$col <- as.factor(df2$col)

Z <- design(checks_vec, df2)$Design

Z$block <- as.numeric(Z$block)
Z$row <- as.numeric(Z$row)
Z$col <- as.numeric(Z$col)
Z$treatments <- as.character(Z$treatments)

df2$treatments <- Z$treatments

for(i in 1:nrow(df2)){
  row_i <- df2$row[i]
  col_i <- df2$col[i]
  check_i <- df2$treatments[i]
  
  df[df$row == row_i & df$col == col_i, "trt"] <- check_i
}

pre_design <- df[!df$trt %in% controls, ]

## treatments are placed in completed randomized design
pre_design$trt <- agricolae::design.crd(trt = pre_design$trt, r = 1)$book$`pre_design$trt`


design <- rbind(pre_design, df[df$trt %in% controls,]) %>% arrange(row, col, block)
design$plot <- c(1:nrow(design))

## Fixing rep number for checks
str(design)
design$rep <- design$block
design[design$type == "entry", "rep"] <- 1


design <- design %>% select(plot, block, trt, rep, type)
design[design$type == "check", "type"] <- 1
design[design$type == "entry", "type"] <- 0

colnames(design) <- c("plots", "block", "all_entries", "rep", "is_control")


head(design)

# save result files
basefile <- tools::file_path_sans_ext(paramfile)
outfile = paste(basefile, ".design", sep="");
sink(outfile)
write.table(design, quote=F, sep='\t', row.names=FALSE)
sink();







