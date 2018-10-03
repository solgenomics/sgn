
##First read in the arguments listed at the command line
args=commandArgs(TRUE)

##args is now a list of character vectors
## First check to see if arguments are passed.
## Then cycle through each element of the list and evaluate the expressions.
if(length(args)==0){
    print("No arguments supplied.")
    ##supply default values
    datafile=''
    paramfile=''
}else{
    for(i in 1:length(args)){
         eval(parse(text=args[[i]]))
    }
}

library(lme4)

data = read.csv(datafile)
source(paramfile)  # should give us dependent_variable, fixed_factors, and random_factors

model = lmer(as.formula(paste(dependent_variable, '~', paste(fixed_factors, collapse='+'), '+', paste(random_factors, collapse='+'))), data=data)

write(summary(model), file=paste(datafile, ".out", sep=""));
