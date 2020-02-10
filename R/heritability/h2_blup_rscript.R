

library("methods")
library("dplyr")

##### Get data #####
args = commandArgs(trailingOnly = TRUE)

pheno <- read.table(args[1], sep = "\t", header = TRUE)

# figure3_file_name = paste(pheno, ".figure3.png", sep="")
figure3_file_name <- args[2]
figure4_file_name <- args[3]
h2File <- args[4]



#Calculating missing data
missingData <- apply(pheno, 2, function(x) sum(is.na(x)))
md = data.frame(missingData)

#Removing traits with more than 60% of missing data
z=0
for (i in 40:ncol(pheno)){
  if (md[i,1]/nrow(pheno)>0.6){
    pheno[[i-z]] <- NULL
    z = z+1
  }
}

colnames(pheno)
traits <- colnames(pheno)[40:ncol(pheno)]

png(figure3_file_name)
par(mfrow=c(2,2))
z=1
for(i in 40:ncol(pheno)){
  hist(pheno[,i], main = "Data Distribution", xlab = traits[z])
  z=z+1
}
dev.off()


png(figure4_file_name)
par(mfrow=c(2,2))
z=1
for(i in 40:ncol(pheno)){
  boxplot(pheno[,i], main = "Boxplot", xlab= traits[z])
  z=z+1
}
dev.off()



#Calculating components of variance and heritability
her = rep(NA,(ncol(pheno)-39))
Vg = rep(NA,(ncol(pheno)-39))
Ve = rep(NA,(ncol(pheno)-39))
resp_var = rep(NA,(ncol(pheno)-39))
numb = 1

library(lmerTest)
# Still need check temp data to ensure wright dimension

for (i in 40:(ncol(pheno)))
{
  outcome = colnames(pheno)[i]
  
  model <- lmer(get(outcome) ~ (1|germplasmName) + studyYear + replicate + blockNumber,
                na.action = na.exclude,
                data=pheno)
  
  
  variance = as.data.frame(VarCorr(model))
  gvar = variance [1,'vcov']
  ervar = variance [2,'vcov']
  
  H2 = gvar/ (gvar + (ervar))
  H2nw = format(round(H2, 4), nsmall = 4)
  her[numb] = as.numeric(H2nw)
  Vg[numb] = as.numeric(gvar)
  Ve[numb] = as.numeric(ervar)
  resp_var[numb] = colnames(pheno)[i]
  
  numb = numb + 1
  
}

#Prepare information to export data
Heritability = data.frame(resp_var,Vg, Ve, her)

library(tidyverse)
Heritability = Heritability %>% 
  rename(
    trait = resp_var,
    Hert = her,
    Vg = Vg,
    Ve = Ve
  )

print(Heritability)

library(gridExtra)
png(h2File, height=(25*numb), width=1000)
p<-tableGrob(Heritability)
grid.arrange(p)
dev.off()


#-------------------------------------------------------------------------
