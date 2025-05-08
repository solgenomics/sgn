## Script for unreplicated diagonal designs

args <- commandArgs(TRUE)

if (length(args) == 0) {
  message("No arguments supplied.")
  paramfile <- ""
} else {
  for (i in seq_along(args)) {
    message(paste("Processing arg", args[[i]]))
    eval(parse(text = args[[i]]))
  }
}

## Source Files
source(paramfile)
basefile <- tools::file_path_sans_ext(paramfile)
if (!exists("engine", inherits = FALSE)) engine <- "breedbase"


## Entry stocks
if(engine != "trial_allocation"){
   n_stocks <- length(stocks)
   treatments <- stocks[!stocks %in% controls]
} else {
   n_stocks <- length(c(treatments, controls))
   n_lines <- length(treatments)
}

n_checks <- length(controls)



## Setting the same number of treatments per block
if (is.null(n_blocks)) {
  n_ind <- n_lines
  n_ind_block <- n_lines
} else {
  n_ind <- n_lines / n_blocks
  n_ind_block <- rep(n_ind, n_blocks)
}

n_controls <- length(controls)

type_design <- if (n_blocks > 1) "DBUDC" else "SUDC"


if( engine == "trial_allocation"){
  layout_type <- "cartesian"
} else {
  layout_type <- if (layout == "serpentine") "serpentine" else "cartesian"
}


treatment_list <- data.frame(
  entry = seq_len(n_stocks),
  name = c(controls, treatments)
)

start_plot <- switch(
  as.character(serie),
  "1" = 1,
  "2" = 101,
  "3" = 1001,
  1  # default to 1 if none matched
)

## Grant the right format
n_row <- as.integer(n_row)
n_col <- as.integer(n_col)
n_lines <- as.integer(n_lines)
n_checks <- as.integer(n_checks)


## FieldHub design
output <- capture.output({
  multi_diag <- FielDHub::diagonal_arrangement(
    nrows = n_row,
    ncols = n_col,
    lines = n_lines,
    planter = layout_type,
    plotNumber = start_plot,
    kindExpt = type_design,
    blocks = n_ind_block,
    checks = n_checks,
    splitBy = "row",
    l = 1,
    data = treatment_list
  )
})

if (any(grepl("Field dimensions do not fit", output))) {
  error_file <- paste0(basefile, ".design.error")
  writeLines(output, con = error_file)
  quit(status = 1)
}

field_book <- multi_diag$fieldBook

## Fixing names to match with Breedbase
field_book$EXPT <- gsub("Block", "", field_book$EXPT)
field_book$CHECKS[field_book$CHECKS > 0] <- 1

if(engine == 'trial_allocation'){
  library(dplyr)
  field_book <- field_book %>% select(PLOT, EXPT, TREATMENT, LOCATION, CHECKS)
  colnames(field_book) <- c("plots", "block", "all_entries", "rep", "is_control")
  field_book <- field_book[order(field_book$plots),]
}


print(head(field_book, 10))

## Save result files
out_file <- paste0(basefile, ".design")
sink(out_file)
write.table(field_book, quote = FALSE, sep = "\t", row.names = FALSE)
sink()
