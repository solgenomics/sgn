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
library(agricolae)
library(dplyr)

all_entries <- c(treatments, controls)
new_seed <- sample(1:1e6, 1)


error_message <- NULL
outdesign <- tryCatch({
	design.rcbd(all_entries, n_rep, serie = serie, seed = new_seed, kinds = "Wichmann-Hill")
}, error = function(e) {
	error_message <<- e$message
	return(NULL)
})


if (!is.null(error_message)) {
    out_message <- paste0(basefile, ".message")
    sink(out_message)
    write.table(out_message, quote = FALSE, sep = '\t', row.names = FALSE)
    sink()
  
} else {
	book <- outdesign$book
    book$rep <- book$block

	## setting controls
	book$is_control <- 0
	book[book$all_entries %in% controls, "is_control"] <- 1
	book <- book[book$block != 0, ]
	head(book, 10)

	outfile <- paste0(basefile, ".design")
	sink(outfile)
	write.table(book, quote = FALSE, sep = '\t', row.names = FALSE)
	sink()
}