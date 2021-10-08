################################################################################
# Genomic prediction of cross performance in R
################################################################################

# There are four main steps to this protocol:
# 1. Read in the genotype data and convert to numeric allele counts
# 2. Read in the phenotype data.
# 3. Fit the mixed model to get estimated additive and dominance effects
# 4. Predict cross performance using additive effects, dominance effects,
#     and allele frequencies.


# Load software
library(sommer)
library(asreml) #load the library
source("hapMap2numeric.R")
Rcpp::sourceCpp("GPCP_polyploids.cpp")



################################################################################
# 1. Read in the genotype data and convert to numeric allele counts.
################################################################################

# This assumes we start with the genotype data in Hapmap format (.hmp.txt)
# This assumes diploid genotypes.
# This assumes we only allow two alleles per locus (biallelic sites)
# This assumes all loci are polymorphic, not monomorphic
# If the file is a VCF (.vcf), then convert it to a hapmap file in TASSEL5 or other
# software.
# If the hapmap file does not fit the specifications above, then filter it in the
# software preferred. TASSEL works.
# If you feel comfortable writing a custom script to import and convert your VCF
# file to numeric format directly, that works too.
# If you already have a numeric matrix, read it in using read.table() or
# another method. Put individuals in rows and markers in columns- use t() if needed.

# 1a. To read the Hapmap file into R, we need to remove the comment characters
# in the file header. So, open the Hapmap file in Notepad or Notepad ++. 
# *Do not* open the Hapmap file in another software like Word or Excel.

# 1b. Delete the "#" character following the column headers "rs" and "assembly".
#     Do not accidentally delete the space following the "#".

# 1c. Rename and save the file from 1b.

# 1d. Get allele counts of 0, 1, and 2 to make a genotype matrix from your Hapmap file.
#     Uses the hapMap2numeric function imported above.
G <- hapMap2numeric("rotundata_genotypic_IITA_VCF_sequenced_clones_2020_rmMono.hmp.txt") # replace this file name with your file

# 1e. Get the additive (-1, 0, 1) genotype matrix.
A <- G - 1

# 1e. Get the dominance (0, 1, 0) genotype matrix
#D <- G
#D[D == 2] <- 0
D <- 1 - abs(A) # more parsimonious but equivalent to 55-56 above

# 1f. Get the inbreeding coefficent, f, as described by Xiang et al., 2016
# The following constructs f as the average heterozygosity of the individual
# The coefficient of f estimated later then needs to be divided by the number of markers
# in the matrix D before adding it to the estimated dominance marker effects
# One unit of change in f represents changing all loci from homozygous to heterozygous 
f <- rowSums(D, na.rm = TRUE) / apply(D, 1, function(x) sum(!is.na(x)))

# Another way to construct f is the total number of heterozygous loci in the individual
# This construction of f does not need to be divided by the number of markers
# The coefficient of this construction of f represents the average dominance effect of a marker
# One unit of change in f represents changing one locus from homozygous to heterozygous
# f <- rowSums(D, na.rm = TRUE)



# We now have the genotype information needed.




################################################################################
# 2. Read in the clean phenotype data and convert if needed
################################################################################

dt <- read.csv("2020_TDr_PHENO.csv", header = TRUE)
str(dt)
for(i in c(1, 2, 3, 4, 5, 6, 7, 8)){
  dt[,i] <- as.factor(dt[,i])
}
dt$Env <- as.factor(paste(dt$Year, dt$LOC, sep = "")) #variable of year-location
dt$f <- f[as.character(dt$Accession)] #paste in f

table(dt$REP, dt$Block) #one rep per block
table(dt$Accession, dt$Env) #good connectivity of genotypes across environments
table(dt$Accession %in% rownames(G))
table(dt$Design, dt$Trial)
table(dt$Accession, dt$Trial)
table(dt$Trial)
table(dt$Trial, dt$Env)
#no genotype overlap across PPT 1-4
#varying genotype overlap between APT and each PPT 1-4
#some overlap between SCG and APT
#TFE overlaps with nothing except by genetic relatedness (newest)







################################################################################
# 3. Fit the mixed models to get estimated additive and dominance effects
################################################################################

# Let's start with just the 2020 SCG to recycle parents
# Keep it simple

# Subset the SCG
SCG <- dt[dt$Trial == "SCG", ]
SCG$Accession <- as.factor(as.character(SCG$Accession)) # lazy relevel
SCG$Env <- as.factor(as.character(SCG$Env))
table(SCG$Accession %in% rownames(G)) # all phenotyped material is genotyped
G.SCG <- G[rownames(G) %in% SCG$Accession, ]
A.SCG <- A[rownames(A) %in% SCG$Accession, ]
D.SCG <- D[rownames(D) %in% SCG$Accession, ]
SCG$REPf <- SCG$REP

# Let's go ahead and scale the variables, because the yam team weights appear scaled
ivar <- c("Vigor", "AUDPC_YMV", "AUDPC_YAD", "ATW", "YIELD", "DMC", "OXBI")
for(i in 1:length(ivar)){
  SCG[ , ivar[i]] <- (SCG[ , ivar[i]] - mean(SCG[ , ivar[i]], na.rm = TRUE))/sd(SCG[ , ivar[i]], na.rm = TRUE)
}


# Find the possible check varieties and make an indicator column with 1 for the checks
posChecks <- names(table(SCG$Accession)[table(SCG$Accession) > 2])
posChecks <- SCG[SCG$Accession %in% posChecks, ]
posChecks$Accession <- as.factor(as.character(posChecks$Accession))
table(posChecks$Accession, posChecks$Block) #kind of weird-- checks not in all blocks
#use as checks: TDr1100497, TDr8902665, TDr9519177, TDrOjuiyawo
checks <- c("TDr1100497", "TDr8902665", "TDr9519177", "TDrOjuiyawo")
SCG$check <- 0
SCG[SCG$Accession %in% checks, "check"] <- 1 #the checks have a 1 in this column
table(SCG$check)
SCG$check <- as.factor(SCG$check)


#make the matrices and format them for asREML
A.SCG.GRM <- A.mat(A.SCG) #additive genomic relationship matrix
D.SCG.GRM <- D.mat(D.SCG) #dominance genomic relationship matrix
A.GRM.inv <- solve(A.SCG.GRM + diag(1e-6, nrow(A.SCG.GRM)))
D.GRM.inv <- solve(D.SCG.GRM + diag(1e-6, nrow(D.SCG.GRM)))
attr(A.GRM.inv, "INVERSE") <- TRUE
attr(D.GRM.inv, "INVERSE") <- TRUE
attr(A.GRM.inv, "rowNames") <- as.character(rownames(A.SCG.GRM))
attr(A.GRM.inv, "colNames") <- as.character(colnames(A.SCG.GRM))
attr(D.GRM.inv, "rowNames") <- as.character(rownames(D.SCG.GRM))
attr(D.GRM.inv, "colNames") <- as.character(colnames(D.SCG.GRM))






##############################################################################################
# run in asreml to see
##############################################################################################
ivar <- c("Vigor", "AUDPC_YMV", "AUDPC_YAD", "ATW", "YIELD", "DMC", "OXBI")


mod.YIELD <- asreml(fixed = YIELD ~ Env + f,
                    random = ~Block + vm(Accession, A.GRM.inv) + vm(Accession, D.GRM.inv),
                    data = SCG,
                    na.action = na.method(x="include",y="include"))

mod.Vigor <- asreml(fixed = Vigor ~ Env + f,
                    random = ~Block + vm(Accession, A.GRM.inv) + vm(Accession, D.GRM.inv),
                    data = SCG,
                    na.action = na.method(x="include",y="include"))

mod.AUDPC_YMV <- asreml(fixed = AUDPC_YMV ~ Env + f,
                        random = ~Block + vm(Accession, A.GRM.inv) + vm(Accession, D.GRM.inv),
                        data = SCG,
                        na.action = na.method(x="include",y="include"))

mod.AUDPC_YAD <-  asreml(fixed = AUDPC_YAD ~ Env + f,
                         random = ~Block + vm(Accession, A.GRM.inv) + vm(Accession, D.GRM.inv),
                         data = SCG,
                         na.action = na.method(x="include",y="include"))

mod.ATW <-  asreml(fixed = ATW ~ Env + f,
                   random = ~Block + vm(Accession, A.GRM.inv) + vm(Accession, D.GRM.inv),
                   data = SCG,
                   na.action = na.method(x="include",y="include"))

mod.DMC <-  asreml(fixed = DMC ~ Env + f,
                   random = ~Block + vm(Accession, A.GRM.inv) + vm(Accession, D.GRM.inv),
                   data = SCG,
                   na.action = na.method(x="include",y="include"))

mod.OXBI <-  asreml(fixed = OXBI ~ Env + f,
                    random = ~Block + vm(Accession, A.GRM.inv) + vm(Accession, D.GRM.inv),
                    data = SCG,
                    na.action = na.method(x="include",y="include"))


#learn to backsolve in asreml

# Make the matrices needed: this is the same
A.T <- A.SCG %*% t(A.SCG) ## additive relationship matrix
A.Tinv <- solve(A.T) ## inverse
A.TTinv <- t(A.SCG) %*% A.Tinv # M'%*% (M'M)-

D.T <- D.SCG %*% t(D.SCG) ## dominance relationship matrix
D.Tinv <- solve(D.T) ## inverse
D.TTinv <- t(D.SCG) %*% D.Tinv # M'%*% (M'M)-



#ivar <- c("Vigor", "AUDPC_YMV", "AUDPC_YAD", "ATW", "YIELD", "DMC", "OXBI")
# Extract the effects for each trait
ranef.Yield <- mod.YIELD$coefficients$random
aG.Yield <- ranef.Yield[grepl("*A.GRM.inv*", rownames(ranef.Yield))]
names(aG.Yield) <- sapply(strsplit(rownames(ranef.Yield)[grepl("*A.GRM.inv*", rownames(ranef.Yield))], "_"), "[[", 2)
dG.Yield <- ranef.Yield[grepl("*D.GRM.inv*", rownames(ranef.Yield))]
names(dG.Yield) <- sapply(strsplit(rownames(ranef.Yield)[grepl("*D.GRM.inv*", rownames(ranef.Yield))], "_"), "[[", 2)
table(rownames(A.T) == names(aG.Yield)) #these are in the right order

#
ranef.Vigor <- mod.Vigor$coefficients$random
aG.Vigor <- ranef.Vigor[grepl("*A.GRM.inv*", rownames(ranef.Vigor))]
names(aG.Vigor) <- sapply(strsplit(rownames(ranef.Vigor)[grepl("*A.GRM.inv*", rownames(ranef.Vigor))], "_"), "[[", 2)
dG.Vigor <- ranef.Vigor[grepl("*D.GRM.inv*", rownames(ranef.Vigor))]
names(dG.Vigor) <- sapply(strsplit(rownames(ranef.Vigor)[grepl("*D.GRM.inv*", rownames(ranef.Vigor))], "_"), "[[", 2)
table(rownames(A.T) == names(aG.Vigor)) #these are in the right order

#
ranef.AUDPC_YMV <- mod.AUDPC_YMV$coefficients$random
aG.AUDPC_YMV <- ranef.AUDPC_YMV[grepl("*A.GRM.inv*", rownames(ranef.AUDPC_YMV))]
names(aG.AUDPC_YMV) <- sapply(strsplit(rownames(ranef.AUDPC_YMV)[grepl("*A.GRM.inv*", rownames(ranef.AUDPC_YMV))], "_"), "[[", 2)
dG.AUDPC_YMV <- ranef.AUDPC_YMV[grepl("*D.GRM.inv*", rownames(ranef.AUDPC_YMV))]
names(dG.AUDPC_YMV) <- sapply(strsplit(rownames(ranef.AUDPC_YMV)[grepl("*D.GRM.inv*", rownames(ranef.AUDPC_YMV))], "_"), "[[", 2)
table(rownames(A.T) == names(aG.AUDPC_YMV)) #these are in the right order

#
ranef.AUDPC_YAD <- mod.AUDPC_YAD$coefficients$random
aG.AUDPC_YAD <- ranef.AUDPC_YAD[grepl("*A.GRM.inv*", rownames(ranef.AUDPC_YAD))]
names(aG.AUDPC_YAD) <- sapply(strsplit(rownames(ranef.AUDPC_YAD)[grepl("*A.GRM.inv*", rownames(ranef.AUDPC_YAD))], "_"), "[[", 2)
dG.AUDPC_YAD <- ranef.AUDPC_YAD[grepl("*D.GRM.inv*", rownames(ranef.AUDPC_YAD))]
names(dG.AUDPC_YAD) <- sapply(strsplit(rownames(ranef.AUDPC_YAD)[grepl("*D.GRM.inv*", rownames(ranef.AUDPC_YAD))], "_"), "[[", 2)
table(rownames(A.T) == names(aG.AUDPC_YAD)) #these are in the right order

#
ranef.ATW <- mod.ATW$coefficients$random
aG.ATW <- ranef.ATW[grepl("*A.GRM.inv*", rownames(ranef.ATW))]
names(aG.ATW) <- sapply(strsplit(rownames(ranef.ATW)[grepl("*A.GRM.inv*", rownames(ranef.ATW))], "_"), "[[", 2)
dG.ATW <- ranef.ATW[grepl("*D.GRM.inv*", rownames(ranef.ATW))]
names(dG.ATW) <- sapply(strsplit(rownames(ranef.ATW)[grepl("*D.GRM.inv*", rownames(ranef.ATW))], "_"), "[[", 2)
table(rownames(A.T) == names(aG.ATW)) #these are in the right order

#
ranef.DMC <- mod.DMC$coefficients$random
aG.DMC <- ranef.DMC[grepl("*A.GRM.inv*", rownames(ranef.DMC))]
names(aG.DMC) <- sapply(strsplit(rownames(ranef.DMC)[grepl("*A.GRM.inv*", rownames(ranef.DMC))], "_"), "[[", 2)
dG.DMC <- ranef.DMC[grepl("*D.GRM.inv*", rownames(ranef.DMC))]
names(dG.DMC) <- sapply(strsplit(rownames(ranef.DMC)[grepl("*D.GRM.inv*", rownames(ranef.DMC))], "_"), "[[", 2)
table(rownames(A.T) == names(aG.DMC)) #these are in the right order

#
ranef.OXBI <- mod.OXBI$coefficients$random
aG.OXBI <- ranef.OXBI[grepl("*A.GRM.inv*", rownames(ranef.OXBI))]
names(aG.OXBI) <- sapply(strsplit(rownames(ranef.OXBI)[grepl("*A.GRM.inv*", rownames(ranef.OXBI))], "_"), "[[", 2)
dG.OXBI <- ranef.OXBI[grepl("*D.GRM.inv*", rownames(ranef.OXBI))]
names(dG.OXBI) <- sapply(strsplit(rownames(ranef.OXBI)[grepl("*D.GRM.inv*", rownames(ranef.OXBI))], "_"), "[[", 2)
table(rownames(A.T) == names(aG.OXBI)) #these are in the right order





# Format the effects to go into cross prediction
#ivar <- c("Vigor", "AUDPC_YMV", "AUDPC_YAD", "ATW", "YIELD", "DMC", "OXBI")
table(colnames(A.TTinv) == names(aG.Yield)) #A-OK
a.Yield <- as.vector(A.TTinv %*% matrix(aG.Yield, ncol=1))
fCoef.Yield <- mod.YIELD$coefficients$fixed[1, ] / ncol(A) #divides f by nMarkers
dw.Yield <-  as.vector(D.TTinv %*% matrix(dG.Yield, ncol=1))
d.Yield <- dw.Yield + fCoef.Yield 


#
a.Vigor <- as.vector(A.TTinv %*% matrix(aG.Vigor, ncol=1))
fCoef.Vigor <- mod.Vigor$coefficients$fixed[1, ] / ncol(A)
dw.Vigor <-  as.vector(D.TTinv %*% matrix(dG.Vigor, ncol=1))
d.Vigor <- dw.Vigor + fCoef.Vigor

#
a.AUDPC_YMV <- as.vector(A.TTinv %*% matrix(aG.AUDPC_YMV, ncol=1))
fCoef.AUDPC_YMV <- mod.AUDPC_YMV$coefficients$fixed[1, ] / ncol(A)
dw.AUDPC_YMV <-  as.vector(D.TTinv %*% matrix(dG.AUDPC_YMV, ncol=1))
d.AUDPC_YMV <- dw.AUDPC_YMV + fCoef.AUDPC_YMV 


#
a.AUDPC_YAD <- as.vector(A.TTinv %*% matrix(aG.AUDPC_YAD, ncol=1))
fCoef.AUDPC_YAD <- mod.AUDPC_YAD$coefficients$fixed[1, ] / ncol(A)
dw.AUDPC_YAD <-  as.vector(D.TTinv %*% matrix(dG.AUDPC_YAD, ncol=1))
d.AUDPC_YAD <- dw.AUDPC_YAD + fCoef.AUDPC_YAD 


#
a.ATW <- as.vector(A.TTinv %*% matrix(aG.ATW, ncol=1))
fCoef.ATW <- mod.ATW$coefficients$fixed[1, ] / ncol(A)
dw.ATW <-  as.vector(D.TTinv %*% matrix(dG.ATW, ncol=1))
d.ATW <- dw.ATW + fCoef.ATW 


#
a.DMC <- as.vector(A.TTinv %*% matrix(aG.DMC, ncol=1))
fCoef.DMC <- mod.DMC$coefficients$fixed[1, ] / ncol(A)
dw.DMC <-  as.vector(D.TTinv %*% matrix(dG.DMC, ncol=1))
d.DMC <- dw.DMC + fCoef.DMC 


#
a.OXBI <- as.vector(A.TTinv %*% matrix(aG.OXBI, ncol=1))
fCoef.OXBI <- mod.OXBI$coefficients$fixed[1, ] / ncol(A)
dw.OXBI <-  as.vector(D.TTinv %*% matrix(dG.OXBI, ncol=1))
d.OXBI <- dw.OXBI + fCoef.OXBI 





# Now weight and add the marker effects for the index.

# Paterne Agre
#Vigor == 0.5
#AUDPCYMV = rAUDPCYMV = YMV == -1 in TDr population
#AUDPCYAD = rAUDPCYAD =YAD == -0.5 in TDr population
#ATW == 0.8
#Yield == 1 same value for Yield unadjusted, yield per plot and total tuber weight per plant (TTWPL)
#DMC == 1
#OXBI == -1 (this is oxidative browning index) quantitative data

ai <- a.Yield * 1 +
  a.Vigor * 0.5 +
  a.AUDPC_YMV * -1 +
  a.AUDPC_YAD * -0.5 +
  a.ATW * 0.8 +
  a.DMC * 1 +
  a.OXBI * -1

di <- d.Yield * 1 +
  d.Vigor * 0.5 +
  d.AUDPC_YMV * -1 +
  d.AUDPC_YAD * -0.5 +
  d.ATW * 0.8 +
  d.DMC * 1 +
  d.OXBI * -1

table(colnames(G.SCG) == rownames(A.TTinv)) # these are in the right order


# Now predict all the crosses.

plan2 <- calcCrossMean(G.SCG,
                       ai,
                       di,
                       2)

plan2 <- as.data.frame(plan2)
plan2 <- plan2[order(plan2[,3], decreasing = TRUE), ]
plan2[ ,1] <- rownames(G.SCG)[plan2[ ,1]]
plan2[ ,2] <- rownames(G.SCG)[plan2[ ,2]]
plan2
colnames(plan2) <- c("Parent1", "Parent2", "CrossPredictedMerit")
#write.csv(plan2, "IITA_Drotundata_GPCP_2021.csv")



# Since the 2020 SCG became the 2021 PPT for crossing, subset possible crosses
plan2 <- read.csv("IITA_Drotundata_GPCP_2021.csv")
PPT2021 <- read.csv("PPT2021.csv")
CrossPred2021 <- plan2[plan2$Parent1 %in% PPT2021$Accession & plan2$Parent2 %in% PPT2021$Accession, ]
#write.csv(CrossPred2021, "IITA_Drotundata_PPT_GPCP_2021.csv", row.names = FALSE)




################################################################################
# Run RR-BLUP in sommer to confirm that the backsolving worked with both matrices
################################################################################

#
# the marker matrices have to be in the right order. They do not connect by dimnames.
SCG$Accession2 <- SCG$Accession
SCG$Orderer <- as.character(SCG$Accession) #this is critical for the following reorder
AM.SCG <- A.SCG[SCG$Orderer, ]
DM.SCG <- D.SCG[SCG$Orderer, ]
dim(SCG)
dim(AM.SCG)
dim(DM.SCG)
table(SCG$Accession == rownames(AM.SCG))


YIELD.rrblup <- mmer(fixed = YIELD ~ 1, #this won't converge with a fixed effect
                   random = ~vs(AM.SCG) + vs(DM.SCG),
                   rcov = ~units,
                   getPEV = FALSE,
                   data = SCG)

YIELD.gblup <- mmer(fixed = YIELD ~ 1, #this will converge if we put back in the fixed effects
                    random = ~vs(Accession, Gu = A.SCG.GRM) + vs(Accession2, Gu = D.SCG.GRM),
                    rcov = ~units,
                    getPEV = FALSE,
                    data = SCG)

# Backsolve to marker effects method
# Make the matrices needed (again, repeated from above)
A.T <- A.SCG %*% t(A.SCG) ## additive relationship matrix
A.Tinv <- solve(A.T) ## inverse
A.TTinv <- t(A.SCG) %*% A.Tinv # M'%*% (M'M)-

D.T <- D.SCG %*% t(D.SCG) ## dominance relationship matrix
D.Tinv <- solve(D.T) ## inverse
D.TTinv <- t(D.SCG) %*% D.Tinv # M'%*% (M'M)-

# get the gblup backsolved marker effects
me.part <- A.TTinv %*% matrix(YIELD.gblup$U$`u:Accession`$YIELD[colnames(A.TTinv)], ncol=1) #these have to be ordered
me.part2 <- D.TTinv %*% matrix(YIELD.gblup$U$`u:Accession2`$YIELD[colnames(D.TTinv)], ncol=1) #these have to be ordered
table(rownames(me.part) == rownames(me.part2))

# get the rrblup estimated marker effects
summary(YIELD.rrblup)
r.part <- YIELD.rrblup$U$`u:AM.SCG`$YIELD
r.part2 <- YIELD.rrblup$U$`u:DM.SCG`$YIELD


# match the marker name from backsolved gblup to rrblup
table(rownames(me.part) == names(r.part)) #match
table(rownames(me.part2) == names(r.part2)) #match

par(mfrow = c(1,2))
plot(me.part, r.part, xlab = "GBLUP", ylab = "RRBLUP", main = "ADDITIVE") # okay
plot(me.part2, r.part2, xlab = "GBLUP", ylab = "RRBLUP", main = "DOMINANCE") # okay


# What if we just do additive
#YIELD.rrblupA <- mmer(fixed = YIELD ~ 1, #this won't converge with a fixed effect
#                     random = ~vs(AM.SCG),
#                     rcov = ~units,
#                     getPEV = FALSE,
#                     data = SCG)

#YIELD.gblupA <- mmer(fixed = YIELD ~ 1,
#                    random = ~vs(Accession, Gu = A.T),
#                    rcov = ~units,
#                    getPEV = FALSE,
#                    data = SCG)

# get the gblup backsolved marker effects
#table(colnames(A.TTinv) == names(YIELD.gblupA$U$`u:Accession`$YIELD))
#me.partA <- A.TTinv %*% matrix(YIELD.gblupA$U$`u:Accession`$YIELD[colnames(A.TTinv)], ncol=1)
# get the rrblup estimated marker effects
#r.partA <- YIELD.rrblupA$U$`u:AM.SCG`$YIELD
#check
#table(rownames(me.partA) == names(r.partA))
#plot(me.partA, r.partA)
