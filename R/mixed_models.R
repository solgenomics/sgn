
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
  fixed_factors<-c()
  random_factors<-c()
}else{
  for(i in 1:length(args)){
    print(paste("Processing arg ", args[[i]]));
    eval(parse(text=args[[i]]))
  }
}

workdir = dirname(datafile);
setwd(workdir);

library(lme4)
library(lmerTest)
library(emmeans)
library(effects)
#library(phenoAnalysis)
library(stringr)
library(dplyr)

headers = read.csv(datafile, sep="\t",skip = 3, header = F, nrows = 1, as.is = T)
pd = read.csv(datafile, skip = 4, header = F)
colnames(pd) = headers
pd = data.frame(pd)

source(paramfile)  # should give us dependent_variable and the model

trait = dependent_variables
pd$studyYear = as.factor(pd$studyYear)
print(paste("MODEL :", model))
print(paste("FIXED FACTORS: ", fixed_factors));
print(paste("RANDOM FACTORS: ", random_factors));
print(head(pd))

BLUE = as.data.frame(unique(pd$germplasmName))
colnames(BLUE) = "germplasmName"

BLUP = BLUE


for(i in 1:length(trait)){

  dependent_variables = trait[i]
  dependent_variables = gsub(" ", "\\.", dependent_variables) # replace space with "." in variable name
  dependent_variables = gsub("\\|", "\\.", dependent_variables) # replace | with .
  dependent_variables = gsub("\\:", "\\.", dependent_variables)
  dependent_variables = gsub("\\-", "\\.", dependent_variables)
  dependent_variables = gsub("\\/", "\\.", dependent_variables)

  print(paste("Dependent variables : ", dependent_variables))

 model_string = paste(dependent_variables, '~', model)

  print(paste('MODEL STRING:', model_string));
  #mixmodel = lmer(as.formula(model_string), data=pd)

  #model_summary = summary(allEffects(model,se=T))

  #pdout = model
  #print(pdout)

  genotypeEffectType = as.vector(str_match(model_string, '1\\|germplasmName'))
  genotypeEffectType = ifelse(is.na(genotypeEffectType), 'fixed', 'random')
  print(paste('modeling genotypes as: ', genotypeEffectType))

  if(genotypeEffectType=="random")
    {
    mixmodel = lmer(as.formula(model_string), data=pd)
    res <- (ranef(mixmodel)$germplasmName)

    blup <- res%>%mutate("germplasmName" = rownames(res))
    names(blup)[1] = trait[i]
    blup <- blup[,c("germplasmName",trait[i])]

    blup <- as.data.frame(blup)

    BLUP <- merge(x = BLUP, y = blup, by ="germplasmName", all=TRUE)

  }
  else{
    mixmodel = lm(as.formula(model_string), data=pd)
    adj <- summary(lsmeans(mixmodel, "germplasmName"))
    blue <- adj[c("germplasmName", "lsmean")]
    colnames(blue)[2] = trait[i]
    adjusted_means = as.data.frame(blue)

    BLUE =  merge(x = BLUE, y = adjusted_means, by ="germplasmName", all=TRUE)

  }

}

if(genotypeEffectType=="fixed"){

outfile_blue = paste(datafile, ".adjusted_means", sep="")
sink(outfile_blue)
write.table(BLUE, quote=F , sep='\t')
sink();
}else{
  outfile_blup = paste(datafile, ".blups", sep="");
  sink(outfile_blup)
  write.table(BLUP, quote=F, sep='\t')
  sink();
}
