## Remove all existing objects in the memory
rm(list=ls())

## load the required packages into memory for use

library(dplyr)
library(lme4)
library(lsmeans)
library(tibble)
library(lmerTest)

## Set the working directory

setwd("/Users/guillaume/Desktop/")


## read the excel comma separated value file into R

whtrt <- read.csv(file="uyt30yr1yrtcombined.csv", header=T)

### extract a single environment trial from multienvironment trials

whtrt <- whtrt %>% filter(env=="Ibadan14") %>% select(c(rep,gen,fyld))

## convert rep variable to a factor
whtrt$rep <-as.factor(whtrt$rep)


## Simple descriptive summary statistics of the traits across all genotypes


#### Fit model with random rep effect and genotypes fixed to estimate the adjusted means/BLUE
## Fitting linear mixed model - rep = random effect and clone = fixed effect in order to estimate adjusted mean
fyld_fix <- lmer(fyld~(1|rep)+gen,data=whtrt)


### Calculate adjusted mean/BLUE from the fitted model
#fyld_lsm <-lsmeans(fyld_fix,"gen")
fyld_lsm <-lsmeansLT(fyld_fix,"gen")
fyld_lsm <- as.data.frame(fyld_lsm[1])

### extracted out the genotypes with the BLUE values
#s <-summary(fyld_lsm)
#blue <- s[c("gen", "lsmean")]
blue <- fyld_lsm[1:2]



#### Fit model with rep and genotypes as random effect to get BLUP

 fyld_rand <- lmer(fyld~(1|rep)+(1|gen),data=whtrt)

### Extract the estimates of the fixed effects parameters
grand_mean <-fixef(fyld_rand)

names(grand_mean)<-"grand_mean"


### extract the estimates of the random effects parameters from fitted model (BLUPS)
fyldblup <-ranef(fyld_rand)


### Obtain blups for the genotypes
fyld_gen_blup <- fyldblup$gen
names(fyld_gen_blup)<-"blup"

#fyld_gen_blup <- as.data.frame(add_rownames(fyld_gen_blup, "gen"))
fyld_gen_blup <- as.data.frame(rownames_to_column(fyld_gen_blup, "gen"))

fyld_gen_blup <- fyld_gen_blup %>% mutate(genotypic_value=grand_mean+blup)


## Merge adjusted means with the blup estimates
summary_table <- merge(blue,fyld_gen_blup)

## Summary output of adjusted means (BLUE), grand means, genetic effect and genotypic value (BLUP) by trait and clone
## output the lsmeans(Adjusted mean or BLUE), genetic effect (i.e. blup) and
## genotypic value (the sum of grand mean i.e intercept and blup)
print(summary_table)


## write result to excel file
write.csv(summary_table,file="summary_output.csv",row.names=F)



## adjusted means, summary statistics and genetic parameter estimates for each trait
