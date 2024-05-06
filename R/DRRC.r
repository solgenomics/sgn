
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
n.reps <- nRep
n.tiers <- nCol
n.rows <- nRow
plotType <- plot_type 
plotStart <- plot_start
col.per.block <- as.numeric(col_per_block)

all.clones <- treatments


bed.number <- data.frame(accession_name = all.clones,
                         bed_number=c(1:length(all.clones)))


## 1) Preparing dataframe
treatmentdf = data.frame(treatment=all.clones)
list.bed = merge(treatmentdf,bed.number, by.x="treatment", by.y = "accession_name", all.x=TRUE)
list.bed.order = list.bed#[order(list.bed$bed_number),]
colnames(list.bed.order) = c("accession_name","bed_number")
list.bed.order$num = 1:length(all.clones)
list.bed.order = subset(list.bed.order, select = c("num","accession_name","bed_number"))

## 2) create design
blocks <- data.frame(
  rep_number = gl(n.reps,length(all.clones)),
  block_number = gl(n.reps,1),
  dummy_tier = gl(n.tiers*2,n.rows/2)
) 

design <- design(all.clones, blocks)$Design

design$row_number = rep(rep(1:n.rows,each=n.tiers/n.reps),times=n.reps)
design <- design[order(design$row_number),]
design$col_number = rep(1:n.tiers,times=n.rows)


names(design)[names(design) == "treatments"] <- "accession_name"

#### create is_a_control
design <- transform(design, is_a_control = ifelse(design$accession_name %in% controls, 1, 0))

## Fixing Block Number
blcNumber = 1
for(i in 1:n.rows){
  design[design$col_number == i, "block_number"] <- blcNumber
  if(i%%col.per.block == 0){blcNumber = blcNumber+1}
}

## Number start
if(plotStart == "00101"){
  design$plot_number = paste0(formatC(design$row_number,width=3,flag="0"),
                              formatC(design$col_number,width=2,flag="0"))
}else if (plot_start == 1001){
  design$plot_number <- (1000*design$row_number)+design$col_number
}else if (plot_start == 101) {
  design$plot_number <- (100*design$row_number)+design$col_number
}else{
  design$plot_number <- (design$row_number)+design$col_number
}

cat("plot start is ", plotStart,"\n")
cat("plot type is ", plotType,"\n")

## Plot number format
if(plotType == "serpentine"){
  for(i in 1:n.rows){
    if(i%%2==0){
      design[design$row_number == i, "plot_number"] <- rev(design[design$row_number==i,"plot_number"])
    }
  }
}
    
design <- design %>% dplyr::select(block_number, row_number, col_number, plot_number, accession_name, is_a_control)

head(design)


# save result files
basefile <- tools::file_path_sans_ext(paramfile)
outfile = paste(basefile, ".design", sep="");
sink(outfile)
write.table(design, quote=F, sep='\t', row.names=FALSE)
sink();