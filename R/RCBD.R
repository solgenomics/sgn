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

# Now just use the variables:
print(treatments)
print(controls)
print(n_rep)
print(n_row)
print(n_col)
print(n_blocks)
print(serie)


library(agricolae)
# 5 treatments and 6 blocks
all_entries <- c(treatments, controls)
new_seed <- sample(1:1e6, 1)
outdesign <- design.rcbd(all_entries, n_rep , serie=serie, seed = new_seed, "Wichmann-Hill")
book <- outdesign$book 

head(book, 10)