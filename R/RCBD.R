## Create Randomized Complete Block Designs
args = commandArgs(TRUE)

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
basefile <- tools::file_path_sans_ext(paramfile)

# Printing variables:
print(treatments)
print(controls)
print(n_rep)
print(n_row)
print(n_col)
print(n_blocks)
print(serie)

## Preparing design
library(FielDHub)
library(dplyr)

all_entries <- c(treatments, controls)
new_seed <- sample(1:1e6, 1)

init_plot = 1
if( serie == 2 ){ init_plot = 101}
if( serie == 3 ){ init_plot = 1001}


## Design
outdesign <- RCBD(t = length(all_entries), reps = n_blocks, plotNumber = init_plot, seed = new_seed)

## Extracting field book
book <- outdesign$fieldBook

## Adding treatment names
book$TREATMENT <- all_entries[match(book$TREATMENT, paste0("T", seq_along(all_entries)))]
book$block <- book$REP

## setting controls
book$is_control <- 0
book[book$TREATMENT %in% controls, "is_control"] <- 1
book <- book %>% select(PLOT, block, TREATMENT, REP, is_control)

colnames(book) <- c("plots", "block", "all_entries", "rep", "is_control")
head(book, 10)

outfile <- paste0(basefile, ".design")
sink(outfile)
write.table(book, quote = FALSE, sep = '\t', row.names = FALSE)
sink()
