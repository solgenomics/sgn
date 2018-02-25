## AUDPC
########
install.packages("caTools")
install.packages("caTools_1.17.1.tgz", repos = NULL, type="source")
install.packages("flux_0.3-0.tgz", repos = NULL, type="source")
library('caTools')
library('flux')

# Script calculates areas under these curves (AUC) using the trapezoid rule as implemented by the auc from flux R package 
# (http://cran.r-project.org/web/packages/flux/index.html)
# for further dev see AUDPS: https://apsjournals.apsnet.org/doi/pdf/10.1094/PHYTO-07-11-0216

### load data ####
#####################
Data <- read.table("2017_GWAS_data_Agre.txt",sep="\t",header=TRUE,stringsAsFactor=T);
Data <- setNames(Data,names(Data))
names(Data)
str(Data)
summary(Data)

## AUDPC on virus and antractnose variables
###########################################
# Virus and Antracnose severity variables in this data set (both 9 timepoints) all start with "ViruSevEst" and "AntracSevEst" respectively
# to be matched with CO IDs
# Severity variables are chronologically ordered

o = NULL
o.trimmed = NULL
auc.o = NULL
auc.final = NULL

## -1- Extract relevant variables (here virus or antracnose) and reformat into "ts' object for AUDPC calc
# Including ts object specific parameters: 
# start "s" and end "e" specify number of collection period span (here 14 weeks)
# frequency "f": collection once every 2 weeks (0.5)
# trait set "g": stores all disease variables, here "ViruSevEst" or "AntracSevEst"
s=0
e=14
f=0.5
## Note: These values are infered from dates of collections, for yambase we would need to infer them acording 
# to selected variables and related time points

g="ViruSevEst"
# Note: Need to loop on temp g, meanwhile doing g selection manually and add Data.temp2 = NULL
# smething like:
#my.names <- c("ViruSevEst","AntracSevEst")
#search.term <- c("Emil", "Meryl")
#for(i in 1:length(search.term)){
#  print(grep(paste("^", search.term, sep="")[i], my.names))
#} 

# Select variables, create ts obj, add plot header, remove empty rows (NA throw error), store remaining plot ID
n <- Data[, grep(paste('^',g,sep=""), names(Data))]
o <- t(apply(n, 1, function(x) ts(as.numeric(t(x)), start=s, end=e, frequency=f)))
o <- cbind.data.frame(Data$Plot,o)
o.trimmed <- o[rowSums(is.na(o[,2:ncol(o)])) == 0,]
o.rownames <- o.trimmed[,1]

## -2- Calculate AUDPC, add plot IDs back, set header, merge AUDPC obj to initial Data obj
auc.o <- as.data.frame(apply(o.trimmed[2:ncol(o.trimmed)], 1, function(x) auc(time(x),x)))
auc.final <- cbind.data.frame(o.rownames,auc.o)
colnames(auc.final) <- c("Plot",paste('AUDPC', g,sep="_"))
Data.temp1 <- merge(Data,auc.final, by="Plot", all=TRUE)
# Note: Need to loop on temp files, meanwhile:
Data.temp2 <- merge(Data.temp1,auc.final, by="Plot", all=TRUE)
write.table(Data.temp2, "Patho_traits_and_AUDPC.txt", row.names = TRUE,col.names = TRUE, sep="\t")