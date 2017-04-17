rm(list=ls())
library(lme4)

# Define models

#0# fixed effect trait, random effect (genotype)
data_i <- data.frame(phenodata_sub=phenodata[,i],genotype = genotype[,1])
fmer <- lmer(phenodata~1|genotype, data = data_i, na.action = na.omit)

#1# fixed effect: year, random effect (genotype)
fmer <- lmer(phenodata[,i]~year + (1|genotype), data = phenodata)
fmer <- lmer(v~1|w, data = data_i, na.action = na.omit)

#2# fixed effect: block, random effect (genotype)
fmer <- lmer(phenodata[,i]~block + (1|genotype), data = phenodata)

#3# fixed effects: year and block (additive), random effect (genotype) and covariate response identical for all
fmeria  <- lmer(phenodata[,i]~year + block + (1|genotype), data = phenodata)

#4# fixed effects: (year and block (additive),  random effect (genotype),  interaction (genotype:year) and covariate response identical for all
fmerib  <- lmer(phenodata[,i]~year + block + (1|genotype) + (1|genotype:year), data = phenodata)

#5# fixed effects: (year and block (additive), , hierarchical random effect (genotype),(response to genotype covariate based on year):
fmert  <- lmer(phenodata[,i]~year + block + (-1+year|genotype), data = phenodata)

# Model comparison (most complex vs less complex)
#genotype effect on year+block:
model(2) versus model(0)

#year effect on year+block:
model(1) versus model(0)

#block effect on genotype:
model(2) versus model(1)

#genotype:year interaction on genotype:
model(3) versus model(2)

#year + block hierachical effect on genotype:
model(5) versus model(2)
