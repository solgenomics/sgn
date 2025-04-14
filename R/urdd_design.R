## Script for Un-replicated Diagonal Designs

args <- commandArgs(TRUE)

if (length(args) == 0) {
  message("No arguments supplied.")
  paramfile <- ''
} else {
  for (i in seq_along(args)) {
    message(paste("Processing arg", args[[i]]))
    eval(parse(text = args[[i]]))
  }
}

source(paramfile)

nStocks <- length(stocks)
nChecks <- length(controls)

## Separating treatments from checks
treatments <- stocks[!stocks %in% controls]

## Setting the same number of treatments per block
if (is.null(nBlocks)) {
  nInd <- nLines
  nIndBlock <- nLines
} else {
  nInd <- nLines / nBlocks
  nIndBlock <- rep(nInd, nBlocks)
}

nControls <- length(controls)

typeDesign <- if (nBlocks > 1) "DBUDC" else "SUDC"
lType <- if (layout == "serpentine") "serpentine" else "cartesian"

treatment_list <- data.frame(
  ENTRY = seq_len(nStocks),
  NAME = c(controls, treatments)
)

startPlot <- switch(
  as.character(serie),
  "1" = 1,
  "2" = 101,
  "3" = 1001,
  1  # default to 1 if none matched
)

## Grant the right format
nRow <- as.integer(nRow)
nCol <- as.integer(nCol)
nLines <- as.integer(nLines)
nChecks <- as.integer(nChecks)

basefile <- tools::file_path_sans_ext(paramfile)

## FieldHub Design
output <- capture.output({
  multi_diag <- FielDHub::diagonal_arrangement(
    nrows = nRow,
    ncols = nCol,
    lines = nLines,
    planter = lType,
    plotNumber = startPlot,
    kindExpt = typeDesign,
    blocks = nIndBlock,
    checks = nChecks,
    l = 1,
    data = treatment_list
  )
})

if (any(grepl("Field dimensions do not fit", output))) {
  errorFile <- paste0(basefile, ".design.error")
  writeLines(output, con = errorFile)
  quit(status = 1)
}

field_book <- multi_diag$fieldBook

## Fixing names to match with Breedbase
field_book$EXPT <- gsub("Block", "", field_book$EXPT)
field_book$CHECKS[field_book$CHECKS > 0] <- 1

print(head(field_book, 10))

## Save result files
outfile <- paste0(basefile, ".design")
sink(outfile)
write.table(field_book, quote = FALSE, sep = '\t', row.names = FALSE)
sink()
