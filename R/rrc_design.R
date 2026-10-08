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

library(agricolae)
library(blocksdesign)

source(paramfile)

## adjusting for trial allocation tool
if (!exists("engine", inherits = FALSE)) engine <- "breedbase"
if(engine == 'trial_allocation'){ treatments <- c(treatments, controls) }

RRCblocks <- data.frame(
  block = gl(nRep,length(treatments)),
  row = gl(nRow,1),
  col = gl(nCol,nRow)
)

RRC <- design(treatments, RRCblocks)$Design
RRC <- transform(RRC, is_a_control = ifelse(RRC$treatments %in% controls, 1, 0))
RRC <- RRC[order(RRC$col),]

RCBD <- design.rcbd(treatments, r=nRep, serie=serie)$book

if(serie == 1){ #Use row numbers as plot names to avoid unwanted agricolae plot num pattern
    RRC$plots <- row.names(RCBD)
} else {
    RRC$plots <- RCBD$plots
}

#Transform to make each column (block#, row#, col#, etc) a row so perl can parse the design file line by line
TRRC <- unname(as.matrix(RRC))
TRRC <- t(TRRC)

# save result files
basefile <- tools::file_path_sans_ext(paramfile)
outfile = paste(basefile, ".design", sep="");
sink(outfile)
write.table(TRRC, quote=F, sep='\t', row.names=FALSE)
sink();
