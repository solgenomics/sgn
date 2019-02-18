
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

workdir = dirname(datafile);
setwd(workdir);

library(lme4)

pd = read.csv(datafile, sep="\t")
source(paramfile)  # should give us dependent_variable, fixed_factors, and random_factors

pd$studyYear = as.factor(pd$studyYear)
print(paste(dependent_variable, fixed_factors, random_factors))

if (fixed_factors_interaction == T) { 
   fixed_factor_op = '*'
} else { 
   fixed_factor_op = '+'
}


print(head(pd))
dependent_variable = gsub(" ", "\\.", dependent_variable) # replace space with "." in variable name
dependent_variable = gsub("\\|", "\\.", dependent_variable) # replace | with .
dependent_variable = gsub("\\:", "\\.", dependent_variable)
dependent_variable = gsub("\\-", "\\.", dependent_variable)
dependent_variable = gsub("\\/", "\\.", dependent_variable)
print(paste("Dependent variable : ", dependent_variable))
model_string = paste(dependent_variable, '~', paste(fixed_factors, collapse=fixed_factor_op), '+', paste(random_factors, collapse='+'))

print(paste('MODEL STRING:', model_string));
model = lmer(as.formula(model_string), data=pd)

model_summary = summary(model)
outfile = paste(datafile, ".results", sep="")
print(outfile)
print(model)
print(model_summary)
print(colnames(model))
print(coef(model))
sink(outfile)
write.table(coef(model)$germplasmName)
sink();
