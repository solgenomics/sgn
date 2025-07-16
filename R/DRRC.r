
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

library(reshape2)
library(dplyr)
library(blocksdesign)

source(paramfile)
## 1) Preparing dataframe
all.clones <- treatments
nTrt <- length(all.clones)
nRep <- nRep
nRows <- nRow
nCols <- nCol
# nCols <- nTrt*nRep/nRows
rowsPerBlock <- nTrt/nCols
colsPerBlock <- nTrt/nRows
superCols <- nCols/colsPerBlock
totalPlots <- nTrt*nRep

plot_type <- plot_type 
plot_start <- plot_start

blocks = data.frame(block_number = gl(nRep,nTrt),
                    Cols = gl(superCols,colsPerBlock,totalPlots),
                    row_number = gl(nRows,nCols,totalPlots),
                    col_number = gl(nCols,1,totalPlots))

## Setting rep number orthogonal to block number
rep_number = as.numeric(blocks$Cols)


# treatments = data.frame(treatments =gl(nTrt,1,totalPlots))
Z=design(all.clones,blocks, searches = 50, weighting=0.5)
fieldBook <- Z$Design

trialMatrix <- matrix(0,nRows,nCols)

for(i in 1:nrow(fieldBook)){
  trialMatrix[fieldBook$subRows[i],fieldBook$subCols[i]]<-fieldBook$treatments[i]
}
trialMatrix

## Adding plot number
colnames(fieldBook)[5] <- "plot_number"

fieldBook$block_number <- as.integer(fieldBook$block_number)
fieldBook$row_number <- as.integer(fieldBook$row_number)
fieldBook$col_number <- as.integer(fieldBook$col_number)

# Load dplyr
library(dplyr)

# Arrange fieldBook by row_number and col_number
fieldBook <- fieldBook %>% arrange(row_number, col_number)
fieldBook$plot_number <- c(1:totalPlots)
fieldBook$plot_id <- c(1:nTrt)



## Number start
## 00101 will be added for NCSU
if(plot_start == "00101"){
  fieldBook$plot_number = paste0(formatC(fieldBook$block_number,width=3,flag="0"),
                              formatC(fieldBook$plot_id,width=2,flag="0"))
}else if (plot_start == 1001){
  fieldBook$plot_number <- (1000*fieldBook$block_number)+fieldBook$plot_id
}else if (plot_start == 101) {
  fieldBook$plot_number <- (100*fieldBook$block_number)+fieldBook$plot_id
}

cat("plot start is ", plot_start,"\n")
cat("plot type is ", plot_type,"\n")

plot_type = "serpentine"
## Plot number format
if(plot_type == "serpentine"){
  for(i in 1:nRows){
    if(i%%2==0){
      fieldBook[fieldBook$row_number == i, "plot_number"] <- rev(fieldBook[fieldBook$row_number==i,"plot_number"])
    }
  }
}

fieldBook$rep_number <- rep_number


#### create is_a_control
names(fieldBook)[names(fieldBook) == "treatments"] <- "accession_name"
fieldBook <- transform(fieldBook, is_a_control = ifelse(fieldBook$accession_name %in% controls, 1, 0))

design <- fieldBook %>% dplyr::select(block_number, rep_number, row_number, col_number, plot_number, accession_name, is_a_control)

head(design)

# save result files
basefile <- tools::file_path_sans_ext(paramfile)
outfile = paste(basefile, ".design", sep="");
sink(outfile)
write.table(design, quote=F, sep='\t', row.names=FALSE)
sink();