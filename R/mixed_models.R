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

Locations = as.data.frame(unique(pd$locationName))
BLUE = as.data.frame(unique(pd$germplasmName))



colnames(BLUE) = "germplasmName"
adjustedBLUE = BLUE

BLUP = BLUE
adjusted_means = BLUE


 

processingTrait <- function(trait){
    print(paste("processing trait", trait[i]))
    dependent_variables = trait[i]
    dependent_variables = gsub(" ", "\\.", dependent_variables) # replace space with "." in variable name
    dependent_variables = gsub("\\|", "\\.", dependent_variables) # replace | with .
    dependent_variables = gsub("\\:", "\\.", dependent_variables)
    dependent_variables = gsub("\\-", "\\.", dependent_variables)
    dependent_variables = gsub("\\/", "\\.", dependent_variables)
    
    print(paste("Dependent variables : ", dependent_variables))
    
    model_string <<- paste(dependent_variables, '~', model)
    
    print(paste('MODEL STRING:', model_string));
    #mixmodel = lmer(as.formula(model_string), data=pd)
    
    #model_summary = summary(allEffects(model,se=T))
    
    #pdout = model
    #print(pdout)
    
    genotypeEffectType <<- as.vector(str_match(model_string, '1\\|germplasmName'))
    genotypeEffectType <<- ifelse(is.na(genotypeEffectType), 'fixed', 'random')
    print(paste('modeling genotypes as: ', genotypeEffectType))

    trait_name <<- trait[i]

        
    if(genotypeEffectType == 'random'){
        callRandom(model_string, trait_name)
    }else{
        callFixed(model_string, trait_name)
    }

}

   
callRandom <- function(model_string, trait_name){ #Function called when germplasmName is in random effect
    mixmodel = lmer(as.formula(model_string), data=pd)

    print("---------")
    print(mixmodel)
    print("---------")
    
    res <- (ranef(mixmodel)$germplasmName)
    
    blup <- res%>%mutate("germplasmName" = rownames(res))
    names(blup)[1] = trait_name
    blup <- blup[,c("germplasmName",trait_name)]
    
    blup <- as.data.frame(blup)
    
    BLUP <<- merge(x = BLUP, y = blup, by ="germplasmName", all=TRUE)
    
    adj = coef(mixmodel)$germplasmName

    print(paste("adj", adj));

    adj = adj[1]  # keep only one column
    adj_means = adj%>%mutate("germplasmName" = rownames(adj))
    names(adj_means)[1] = trait_name
    adj_means = as.data.frame(adj_means)

    adjusted_means <<-  merge(x = adjusted_means, y = adj_means, by ="germplasmName", all=TRUE)

    
}

    
callFixed <- function(model_string, trait_name){ #function called when germplasmName is in fixed effect
    mixmodel = lmer(as.formula(model_string), data=pd)

    # compute adjusted blues
    #
    adj <- summary(lsmeans(mixmodel, "germplasmName"))
    blue <- adj[c("germplasmName", "lsmean")]
    colnames(blue)[2] = trait_name
    blueadj = as.data.frame(blue)
    adjustedBLUE <<-  merge(x = adjustedBLUE, y = blueadj, by ="germplasmName", all=TRUE)

    #Computing fixed effects
    #feff <- (fixef(mixmodel)$germplasmName)
    feff<-data.frame(coef(summary(mixmodel))[ , "Estimate"])
    rownames(feff) <- blue$germplasmName
    colnames(feff) <- trait_name

    fixedeff <- feff%>%mutate("germplasmName" = rownames(feff))
    fixedeff<- fixedeff[,c("germplasmName", trait[i])]
    fixedeff<-as.data.frame(fixedeff)

    #file with fixed effect
    print(fixedeff) 
    
    #file with blues
    print(blue)

    BLUE <<- merge(x = BLUE, y = fixedeff, by="germplasmName", all=TRUE)

}


        

rowCol <- function(pd, Traits, Treatments, Location){
  library(package = "tidyverse")
  
  # preparing the final dataset
  # Sommer needs to get row and columns as factor and double to calculate 2D correction.
  colNames <- colnames(pd)
  colnamesFinal <- append(pd,"rowFactor", "colFactor", after = 28)
  
  for(i in 1:length(locations)){
    Dat = pd %>% filter(Location == UQ(locations[i]))
    Block = unique(Dat$blockNumber)

    dataF = cbind(Dat[,28],"rowFactor","colFactor",Dat[,29:ncol(Dat)])


    colnames(dataF) = colnamesFinal

    
    rowCol <- matrix(data=0,nrow = nrow(pd), ncol = 2)
    colnames(rowCol) <- c("colNumber","rowNumber")

    create_rowCol <- function(col_number, row_number, start_col, max_col, counter){
      for (j in 1:nrow(Dat_Rep)){
        if(col_number > max_col){
          col_number = start_col
          row_number = row_number+1
        }
        rowCol[counter,1] <<- row_number
        rowCol[counter,2] <<- col_number
        
        col_number = col_number+1
        counter=counter+1
      }
    }

    for (k in 1:length(Block)){
      Dat_Rep = Dat %>% filter(Replication == (UQ(Block[k])))
      start_col = (k*2)-1
      max_col = start_col+1
      row_number = 1
      col_number = start_col
      counter = Block[k]
      create_rowCol(col_number, row_number, start_col, max_col, counter)
    }

    dataF$rowNumber <- rbind(rowCol[,1])
    dataF$rowFactor <- rbind(rowCol[,1])
    dataF$colNumber <- rbind(rowCol[,2])
    dataF$colFactor <- rbind(rowCol[,2])

    dataRowCol <<- rbind(dataF)

  }
  return(dataRowCol)
}      

spatialCorrection <- function(pd){
  library(package="sommer")

  rowNumber = as.data.frame(pd$rowNumber)
  colNumber = as.data.frame(pd$colNumber)
  locations = unique(pd$locadionDbId)

  if (length(rowNumber)==0){
    rowCol(pd, rowNumber)
  }

  dataf=data.frame(variety=as.factor(dataRowCol$germplasmName),
                 Block = as.factor(dataRowCol$blockNumber),
                 Loc = as.factor(dataRowCol$locationName),
                 Colf=as.factor(dataRowCol$colFactor),
                 Rowf=as.factor(dataRowCol$rowFactor),
                 rowNumber=as.double(dataRowCol$rowNumber),
                 colNumber=as.double(dataRowCol$colNumber),
                 Pheno=as.double(dataRowCol[,trait])
                 )


    # data(DT_cpdata)
    # DT <- DT_cpdata
    # GT <- GT_cpdata
    # MP <- MP_cpdata
    
    ### mimic two fields
    model <- mmer( Pheno ~ fixed_factors,
          random=~vs(random_factors) + vs(Rowf) + vs(Colf) + vs(spl2D(rowNumber,colNumber)),
          rcov=~vs(units),
          data=dataf, verbose = FALSE)
      
    (suma <- summary(model)$varcomp)
  

    summary(model1)
    # make a plot to observe the spatial effects found by the spl2D()
    W <- with(dataf,spl2D(rowNumber,colNumber)) # 2D spline incidence matrix
    dataf$spatial <- W%*%model1$U$`u:rowNumber`$Pheno # 2D spline BLUPs
    # lattice::levelplot(spatial~rowNumber*colNumber, data=dataf) # plot the spatial effect by row and column


}

callSpatialCorrection<-function(pd){

}

 
    
for(i in 1:length(trait)){
    processingTrait(trait[i])

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
