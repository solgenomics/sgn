## Creates augmented design with diagonal checks

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

library(agricolae)
library(blocksdesign)
library(dplyr)

totalBlock <- nBlocks * nRow
trt <- treatments[!treatments %in% controls]

teste<- design.dau(controls, trt, serie = serie, r=totalBlock)
dim(teste$book)
fieldBook <- teste$book
colnames(fieldBook)[2] <- "row"
fieldBook$row <- as.numeric(fieldBook$row)
totalPlots <- nrow(fieldBook)
inBlock <- totalPlots/nBlocks
colNumber <- totalPlots/nBlocks/nRow
fieldBook$col <- gl(colNumber,1,totalPlots)
fieldBook$block <- as.numeric(gl(nBlocks,inBlock,totalPlots))

blockSize <- totalPlots/nBlocks
fieldBook$plots <- as.numeric(gl(blockSize,1))

if(serie == 2){
  fieldBook$plots = fieldBook$plots + (100 * fieldBook$block)
}
if(serie == 3){
  fieldBook$plots = fieldBook$plots + (1000 * fieldBook$block)
}

plot_type = "serpentine"
## Plot number format
totalRows <- max(fieldBook$row)

head(fieldBook)

if(plot_type == "serpentine") {
  for(i in 1:totalRows) {
    if(i %% 2 == 0) {
      plots_to_reverse <- fieldBook[fieldBook$row == i, "plots"]
      if(length(plots_to_reverse) > 0) {
        fieldBook[fieldBook$row == i, "plots"] <- rev(plots_to_reverse)
      } else {
        warning(paste("No plots found for row", i))
      }
    }
  }
}

#### create is_a_control
names(fieldBook)[names(fieldBook) == "trt"] <- "accession_name"
names(fieldBook)[names(fieldBook) == "plots"] <- "plot_number"
names(fieldBook)[names(fieldBook) == "row"] <- "row_number"
names(fieldBook)[names(fieldBook) == "col"] <- "col_number"
names(fieldBook)[names(fieldBook) == "block"] <- "block_number"

fieldBook <- transform(fieldBook, is_a_control = ifelse(fieldBook$accession_name %in% controls, 1, 0))

design <- fieldBook %>% dplyr::select(block_number, row_number, col_number, plot_number, accession_name, is_a_control)

head(design)
TARC <- unname(as.matrix(design))
TARC <- t(TARC)

# save result files
basefile <- tools::file_path_sans_ext(paramfile)
outfile = paste(basefile, ".design", sep="");
sink(outfile)
write.table(TARC, quote=F, sep='\t', row.names=FALSE)
sink();
