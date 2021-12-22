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


workdir = dirname(datafile);
setwd(workdir);

library(agricolae)
library(blocksdesign)

source(paramfile)

RCblocks <- data.frame(
  block = gl(nRep,length(treatments)),
  row = gl(nRow,1),
  col = gl(nCol,nRow)
)

RC <- design(treatments, RCblocks)$Design
RC <- transform(RC, is_a_control = ifelse(RC$treatments %in% controls, TRUE, FALSE))

CB <- design.rcbd(treatments, r=nRep, serie=serie)$book
RC <- RC[order(RC$col),]
RC$plots <- CB$plots
TRC <- unname(as.matrix(RC))
TRC <- t(TRC)

# save result files
basefile <- tools::file_path_sans_ext(paramfile)
outfile = paste(basefile, ".design", sep="");
sink(outfile)
write.table(TRC, quote=F, sep='\t', row.names=FALSE)
sink();
