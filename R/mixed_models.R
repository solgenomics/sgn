
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
library(lmerTest)
#library(emmeans)
library(effects)
library(phenoAnalysis)
library(stringr)
library(dplyr)

pd = read.csv(datafile, sep="\t")
source(paramfile)  # should give us dependent_variable and the model

pd$studyYear = as.factor(pd$studyYear)
print(paste("MODEL :", model))

print(head(pd))
dependent_variable = gsub(" ", "\\.", dependent_variable) # replace space with "." in variable name
dependent_variable = gsub("\\|", "\\.", dependent_variable) # replace | with .
dependent_variable = gsub("\\:", "\\.", dependent_variable)
dependent_variable = gsub("\\-", "\\.", dependent_variable)
dependent_variable = gsub("\\/", "\\.", dependent_variable)
print(paste("Dependent variable : ", dependent_variable))
model_string = paste(dependent_variable, '~', model)

print(paste('MODEL STRING:', model_string));
model = lmer(as.formula(model_string), data=pd)


#model_summary = summary(allEffects(model,se=T))

pdout = model
print(pdout)

genotypeEffectType = as.vector(str_match(model_string, '1\\|germplasmName'))
genotypeEffectType = ifelse(is.na(genotypeEffectType), 'fixed', 'random')
print(paste('modeling genotypes as: ', genotypeEffectType))

adjusted_means = getAdjMeans(modelOut=model,
    traitName=dependent_variable,
    genotypeEffectType=genotypeEffectType,
    adjMeansVariable='germplasmName')

print(head(adjusted_means))

outfile = paste(datafile, ".results", sep="")
print(outfile)
print(model)
#print(model_summary)
print(colnames(model))
print(ranef(model))
print(adjusted_means)
sink(outfile)
#write.table(ranef(model)$germplasmName)

write.table(select(adjusted_means, 'germplasmName', dependent_variable), row.names = F)
sink();
