## File was edited in ESS mode in emacs and some indents changed. sorry.
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
    
} else {
    for(i in 1:length(args)){
        print(paste("Processing arg ", args[[i]]));
        eval(parse(text=args[[i]]))
    }
}


workdir = dirname(datafile);
setwd(workdir);

library(lme4)
#library(lmerTest)
library(emmeans)
library(effects)
library(stringr)
library(dplyr)

pd = read.csv(datafile, sep="\t")

source(paramfile)  # should give us dependent_variable and the model

trait = dependent_variables
pd$studyYear = as.factor(pd$studyYear)
print(paste("MODEL :", model))
print(paste("FIXED FACTORS: ", fixed_factors));
print(paste("RANDOM FACTORS: ", random_factors));
print(head(pd))

BLUE = as.data.frame(unique(pd$germplasmName))
colnames(BLUE) = "germplasmName"
adjustedBLUE = BLUE

BLUP = BLUE
adjusted_means = BLUE

for(i in 1:length(trait)){

    print(paste("processing trait", trait[i]))
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
    
    if (genotypeEffectType=="random") {
        
        mixmodel = lmer(as.formula(model_string), data=pd)

        print("---------")
        print(mixmodel)
        print("---------")
        
        res <- (ranef(mixmodel)$germplasmName)
        
        blup <- res%>%mutate("germplasmName" = rownames(res))
        names(blup)[1] = trait[i]
        blup <- blup[,c("germplasmName",trait[i])]
        
        blup <- as.data.frame(blup)
        
        BLUP <- merge(x = BLUP, y = blup, by ="germplasmName", all=TRUE)
        
        adj = coef(mixmodel)$germplasmName

        print(paste("adj", adj));

        adj = adj[1]  # keep only one column
        adj_means = adj%>%mutate("germplasmName" = rownames(adj))
        names(adj_means)[1] = trait[i]
        adj_means = as.data.frame(adj_means)

        adjusted_means =  merge(x = adjusted_means, y = adj_means, by ="germplasmName", all=TRUE)

    } else {

        mixmodel = lmer(as.formula(model_string), data=pd)

        # compute adjusted blues
        #
        adj <- summary(lsmeans(mixmodel, "germplasmName"))
        blue <- adj[c("germplasmName", "lsmean")]
        colnames(blue)[2] = trait[i]
        blueadj = as.data.frame(blue)
        adjustedBLUE =  merge(x = adjustedBLUE, y = blueadj, by ="germplasmName", all=TRUE)

        #Computing fixed effects
        #feff <- (fixef(mixmodel)$germplasmName)
        feff<-data.frame(coef(summary(mixmodel))[ , "Estimate"])
        rownames(feff) <- blue$germplasmName
        colnames(feff) <- trait[i]

        fixedeff <- feff%>%mutate("germplasmName" = rownames(feff))
        fixedeff<- fixedeff[,c("germplasmName", trait[i])]
        fixedeff<-as.data.frame(fixedeff)

        #file with fixed effect
        print(fixedeff) 
        
        #file with blues
        print(blue)

        BLUE = merge(x = BLUE, y = fixedeff, by="germplasmName", all=TRUE)

        
    }
}

# save result files
#
# for random effects: file.BLUPs and file.adjustedBLUPs
# for fixed effects: file.BLUEs and file.adjustedBLUEs
#
if (genotypeEffectType=="random") {
    outfile_blup = paste(datafile, ".BLUPs", sep="");
    sink(outfile_blup)
    write.table(BLUP, quote=F, sep='\t', row.names=FALSE)
    sink();
    outfile_adjmeans = paste(datafile, ".adjustedBLUPs", sep="")
    sink(outfile_adjmeans)
    write.table(adjusted_means, quote=F , sep='\t', row.names=FALSE)
    sink();
  
} else {   #fixed
    outfile_blue = paste(datafile, ".BLUEs", sep="")
    sink(outfile_blue)
    write.table(BLUE, quote=F , sep='\t', row.names=FALSE)
    sink();
    outfile_adjblues = paste(datafile, ".adjustedBLUEs", sep="")
    sink(outfile_adjblues)
    write.table(adjustedBLUE, quote=F , sep='\t', row.names=FALSE)
    sink();
}