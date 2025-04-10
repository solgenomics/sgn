## This is a script for Un-replicated Diagonal Designs

args=commandArgs(TRUE)

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

library(FielDHub)

source(paramfile)

nStocks <- length(stocks)
nChecks <- length(controls)

## Separating treatments from checks
treatments <- stocks[!stocks %in% controls]

## Setting the same number of treatments per block
nInd <- nLines/nBlocks
nIndBlock <- rep(nInd, nBlocks)

if(nBlocks>1){typeDesign = 'DBUDC'}else{typeDesign='SUDC'}
if(layout=="serpentine"){lType<-"serpentine"}else{lType<-"cartesian"}


treatment_list <- data.frame(list(ENTRY = 1:nStocks, NAME = c(controls, treatments)))

if(serie == 1){
  startPlot <- 1
}else if(serie == 2){
  startPlot <- 101
}else if(serie == 3){
  startPlot <- 1001
}

## Grant the right format
nRow <- as.integer(nRow)
nCol <- as.integer(nCol)
nLines <- as.integer(nLines)
nChecks <- as.integer(nChecks)

## FieldHub Design
output <- capture.output({
  multi_diag <- diagonal_arrangement(
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
  errorFile <- paste(basefile, "design.error", sep = "")
  writeLines(output, con = errorFile)
  quit(status = 1)
}



field_book <- multi_diag$fieldBook

## Fixing names to match with breedbase
field_book$EXPT <- gsub("Block","",field_book$EXPT)
field_book$CHECKS[field_book$CHECKS>0] <- 1

head(field_book,10)

# save result files
basefile <- tools::file_path_sans_ext(paramfile)
outfile = paste(basefile, ".design", sep="");
sink(outfile)
write.table(field_book, quote=F, sep='\t', row.names=FALSE)
sink();