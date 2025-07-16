################################################################################
# Genomic prediction of cross performance for YamBase
################################################################################

# There are ten main steps to this protocol:
# 1. Load the software needed.
# 2. Declare user-supplied variables.
# 3. Read in the genotype data and convert to numeric allele counts.
# 4. Get the genetic predictors needed.
# 5. Process the phenotypic data.
# 6. Fit the mixed models in sommer.
# 7. Backsolve from individual estimates to marker effect estimates / GBLUP -> RR-BLUP
# 8. Weight the marker effects and add them together to form an index of merit.
# 9. Predict the crosses.
# 10. Format the information needed for output.


# Get Arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Two or more arguments are required.")
}
phenotypeFile <- args[1]
genotypeFile <- args[2]
traits <- args[3]
weights <- args[4]
userSexes <- args[5]
userFixed <- args[6]
userRandom <- args[7]

# userSexes = as.vector(userSexes)

# L = length(userSexes)
# if (L==1 && userSexes[1]!="") {write('PLANT SEX is empty: ', stderr())}
write(paste("PLANT SEX CVTERM: |", userSexes, "|"), stderr())


################################################################################
# 1. Load software needed
################################################################################
library(dplyr)
library(tidyr)
library(sommer)
library(AGHmatrix)
library(VariantAnnotation) # Bioconductor package
library(tools)
# library(rstatix)
Rcpp::sourceCpp("/home/production/cxgn/QuantGenResources/CalcCrossMeans.cpp") # this is called CalcCrossMean.cpp on Github






################################################################################
# 2. Declare user-supplied variables
################################################################################

# a. Define path with internal YamBase instructions such that the object 'userGeno'
#    is defined as a VCF file of genotypes.

# userGeno <- path


# b. Define path2 with internal YamBase instructions such that the object 'userPheno'
#    is defined as the phenotype file.

# userPheno <- path2
# write(paste("READING PHENOTYPEFILE: ",phenotypeFile), stderr())
userPheno <- read.delim(phenotypeFile, header = TRUE, sep = "\t", fill = TRUE) # testing only
# write(colnames(userPheno), stderr())
# write(summary(userPheno), stderr())
## userPheno <- userPheno[userPheno$Trial == "SCG", ] #testing only-- needs to replaced with 2-stage

# write("DONE WITH PHENOTYPEFILE"), stderr())

# c. The user should be able to select their fixed variables from a menu
#    of the column names of the userPheno object. The possible interaction terms
#    also need to be shown somehow. Then, those strings should be passed
#    to this vector, 'userFixed'. Please set userFixed to NA if no fixed effects
#    besides f are requested.
#    f is automatically included as a fixed effect- a note to the user would be good.

# userFixed <- c()
# userFixed <- c("studyYear") # for testing only
userFixed <- unlist(strsplit(userFixed, split = ",", fixed = T))


# d. The user should be able to select their random variables from a menu
#    of the column names of the userPheno object. The possible interaction terms
#    also need to be shown somehow. Then, those strings should be passed
#    to this vector, 'userRandom'.

# userRandom <- c()
# userRandom <- "blockNumber" # for testing only
userRandom <- unlist(strsplit(userRandom, split = ",", fixed = T))

# e. The user should be able to indicate which of the userPheno column names
#    represents individual genotypes identically as they are represented in the VCF
#    column names. No check to ensure matching at this stage. This single string
#    should be passed to this vector, userID.

# userID <- c()
userID <- "germplasmName" # for testing only


# f. The user must indicate the ploidy level of their organism, and the integer
#    provided should be passed to the vector 'userPloidy'. CalcCrossMeans.cpp
#    currently supports ploidy = {2, 4, 6}. Ideally, the user could select
#    their ploidy from a drop-down to avoid errors here, and there would be a note
#    that other ploidies are not currently supported. If not, a possible error is
#    provided.

userPloidy <- c()
userPloidy <- 2 # for testing only

# if(userPloidy %in% c(2, 4, 6) != TRUE){
#   stop("Only ploidies of 2, 4, and 6 are supported currently. \n
#        Please confirm your ploidy level is supported.")
# }


# g. The user should be able to select their response variables from a drop-down menu
#    of the column names of the userPheno object. Then, those strings should be passed
#    to this vector, 'userResponse'.

write(paste("TRAIT STRING:", traits), stderr())
# userResponse <- c()
# userResponse <- c("YIELD", "DMC", "OXBI") # for testing only
userResponse <- unlist(strsplit(traits, split = ",", fixed = T))

write(paste("USER RESPONSE", userResponse), stderr())
write(paste("first element: ", userResponse[1]), stderr())
# h. The user must indicate weights for each response. The order of the vector
#    of response weights must match the order of the responses in userResponse.

# userWeights <- c()
# userWeights <- c(1, 0.8, 0.2) # for YIELD, DMC, and OXBI respectively; for testing only
userWeights <- as.numeric(unlist(strsplit(weights, split = ",", fixed = T)))

write(paste("WEIGHTS", userWeights), stderr())

# i. The user can indicate the number of crosses they wish to output.
#    The maximum possible is a full diallel.

# userNCrosses <- c()
userNCrosses <- 100 # for testing only


# j. The user can (optionally) input the individuals' sexes and indicate the column
#    name of the userPheno object which corresponds to sex. The column name
#   string should be passed to the 'userSexes' object. If the user does not wish
#   to remove crosses with incompatible sexes (e.g. because the information is not available),
#   then userSexes should be set to NA.


# userSexes <- c()
# userSexes <- "Sex" # for testing only
# userPheno$Sex <- sample(c("M", "F"), size = nrow(userPheno), replace = TRUE, prob = c(0.7, 0.3)) # for testing only
# Please note that for the test above, sex is sampled randomly for each entry, so the same accession can have
# different sexes. This does not matter for the code or testing.

################################################################################
# 3. Read in the genotype data and convert to numeric allele counts.
################################################################################

# a. The VCF file object 'userGeno' needs to be converted to a numeric matrix
#    of allele counts in whic:
#    Rownames represent the individual genotype IDs
#    Colnames represent the site IDs
#    A cell within a given row and column represents the row individual's
#    genotype at the site in the column.

#   The individual's genotype should be an integer from 0... ploidy to represent
#   counts of the alternate allele at the site. Diploid example:
#    0 = homozygous reference
#    1 = heterozygous
#    2 = homozygous alternate

#    The genotypes must not contain monomorphic or non-biallelic sites.
#    Users need to pre-process their VCF to remove these (e.g. in TASSEL or R)
#    I can put an error message into this script if a user tries to input
#    monomorphic or biallelic sites which could be communicated through the GUI.
#    It's also possible to filter them here.

if (file_ext(genotypeFile) == "vcf") {
  write(paste("READING VARIANT FILE ", genotypeFile), stderr())
  #  Import VCF with VariantAnnotation package and extract matrix of dosages
  myVCF <- readVcf(genotypeFile)
  # G <- t(geno(myVCF)$DS) # Individual in row, genotype in column
  mat <- genotypeToSnpMatrix(myVCF)
  # G <- t(geno(myVCF)$DS) # Individual in row, genotype in column
  G <- as(mat$genotypes, "numeric")
  G <- G[, colSums(is.na(G)) < nrow(G)]

  #   TEST temporarily import the genotypes via HapMap:
  # source("R/hapMap2numeric.R") # replace and delete
  # G <- hapMap2numeric(genotypeFile) # replace and delete
} else {
  # accession_names     abc      abc2    abc3
  # marker1                   0      0        2
  # marker2                   1      0        0
  # marker3                   0      0        0

  write(paste("READING DOSAGE FILE ", genotypeFile), stderr())
  GF <- read.delim(genotypeFile)
  GD <- GF[, -1]
  GM <- as.matrix(GD)
  G <- t(GM)
}

write("G Matrix start --------", stderr())
write(G[1:5, 1:5], stderr())
write("G Matrix end =========", stderr())




################################################################################
# 4. Get the genetic predictors needed.
################################################################################

write("GENETIC PREDICTIONS...", stderr())
# 4a. Get the inbreeding coefficent, f, as described by Xiang et al., 2016
# The following constructs f as the average heterozygosity of the individual
# The coefficient of f estimated later then needs to be divided by the number of markers
# in the matrix D before adding it to the estimated dominance marker effects
# One unit of change in f represents changing all loci from homozygous to heterozygous

### GC <- G - (userPloidy/2) #this centers G
GC <- G * (userPloidy - G) * (2 / userPloidy)^2 # center at G
f <- rowSums(GC, na.rm = TRUE) / apply(GC, 1, function(x) sum(!is.na(x)))

# Another alternate way to construct f is the total number of heterozygous loci in the individual
# The coefficient of this construction of f does not need to be divided by the number of markers
# It is simply added to each marker dominance effect
# The coefficient of this construction of f represents the average dominance effect of a marker
# One unit of change in f represents changing one locus from homozygous to heterozygous
# f <- rowSums(D, na.rm = TRUE)


write("DISTANCE MATRIX...", stderr())
# 4b. Get the additive and dominance relationship matrices following Batista et al., 2021
# https://doi.org/10.1007/s00122-021-03994-w

# Additive: this gives a different result than AGHmatrix VanRaden's Gmatrix
# AGHmatrix: Weights are implemented for "VanRaden" method as described in Liu (2020)?
allele_freq <- colSums(G) / (userPloidy * nrow(G))
W <- t(G) - userPloidy * allele_freq
WWt <- crossprod(W)
denom <- sum(userPloidy * allele_freq * (1 - allele_freq))
A <- WWt / denom

# Check with paper equation:
# w <- G - (userPloidy/2)
# num <- w %*% t(w)
# denom = sum(userPloidy * allele_freq * (1 - allele_freq))
# A2 <- num/denom
# table(A == A2)
# cor(as.vector(A), as.vector(A2)) # 0.9996...


# Dominance or digenic dominance
if (userPloidy == 2) {
  D <- Gmatrix(G, method = "Su", ploidy = userPloidy, missingValue = NA)
}

if (userPloidy > 2) {
  # Digenic dominance
  C_matrix <- matrix(length(combn(userPloidy, 2)) / 2,
    nrow = nrow(t(G)),
    ncol = ncol(t(G))
  )

  Ploidy_matrix <- matrix(userPloidy,
    nrow = nrow(t(G)),
    ncol = ncol(t(G))
  )

  Q <- (allele_freq^2 * C_matrix) -
    (Ploidy_matrix - 1) * allele_freq * t(G) +
    0.5 * t(G) * (t(G) - 1)

  Dnum <- crossprod(Q)
  denomDom <- sum(C_matrix[, 1] * allele_freq^2 * (1 - allele_freq)^2)
  D <- Dnum / denomDom
}






################################################################################
# 5. Process the phenotypic data.
################################################################################

# write(summary(userPheno), stderr())

# a. Paste f into the phenotype dataframe
write("processing phenotypic data...", stderr())
userPheno$f <- f[as.character(userPheno[, userID])]

# write(summary(userPheno), stderr())

# b. Scale the response variables.
write("processing phenotypic data... scaling...", stderr())
write(paste("USER RESPONSE LENGTH = ", length(userResponse)), stderr())
for (i in 1:length(userResponse)) {
  write(paste("working on user response ", userResponse[i]), stderr())
  userPheno[, userResponse[i]] <- (userPheno[, userResponse[i]] - mean(userPheno[, userResponse[i]], na.rm = TRUE)) / sd(userPheno[, userResponse[i]], na.rm = TRUE)
}

write(paste("accession count: ", length(userPheno[, userID])), stderr())
write("processing phenotypic data... adding dominance effects", stderr())
# c. Paste in a second ID column for the dominance effects.

# write(summary(userPheno), stderr())

dominanceEffectCol <- paste(userID, "2", sep = "")
write(paste("NEW COL NAME: ", dominanceEffectCol), stderr())

write(paste("USER_ID COLUMN: ", userPheno[, userID]), stderr())
userPheno[, dominanceEffectCol] <- userPheno[, userID]

write(paste("USER PHENO userID2 COL", userPheno[, dominanceEffectCol]), stderr())
uniq <- length(sapply(lapply(userPheno, unique), length))
write(paste("UNIQUE", uniq), stderr())


# Additional steps could be added here to remove outliers etc.





################################################################################
# 6. Fit the mixed models in sommer.
################################################################################

write("Fit mixed model in sommer", stderr())
# 6a. Make a list to save the models.

userModels <- list()

for (i in 1:length(userResponse)) {
  write(paste("User response: ", userResponse[i]), stderr())
  # check if fixed effects besides f are requested, then paste together
  # response variable and fixed effects
  if (!is.na(userFixed[1])) {
    fixedEff <- paste(userFixed, collapse = " + ")
    fixedEff <- paste(fixedEff, "f", sep = " + ")
    fixedArg <- paste(userResponse[i], " ~ ", fixedEff, sep = "")
  }
  if (is.na(userFixed[1])) {
    fixedArg <- paste(userResponse[i], " ~ ", "f")
  }


  # check if random effects besides genotypic additive and dominance effects
  # are requested, then paste together the formula

  write("Generate formula...", stderr())

  if (!is.na(userRandom[1])) {
    randEff <- paste(userRandom, collapse = " + ")
    ID2 <- paste(userID, 2, sep = "")
    randEff2 <- paste("~vsr(", userID, ", Gu = A) + vsr(", ID2, ", Gu = D)", sep = "")
    randArg <- paste(randEff2, randEff, sep = " + ")
  }
  if (is.na(userRandom[1])) {
    ID2 <- paste(userID, 2, sep = "")
    randArg <- paste("~vsr(", userID, ", Gu = A) + vsr(", ID2, ", Gu = D)", sep = "")
  }

  write(paste("Fit mixed GBLUP model...", randArg), stderr())

  #  write(paste("USER PHENO:", userPheno), stderr())
  #  write(paste("COLNAMES: ", colnames(userPheno)), stderr())
  # fit the mixed GBLUP model
  myMod <- mmer(
    fixed = as.formula(fixedArg),
    random = as.formula(randArg),
    rcov = ~units,
    getPEV = FALSE,
    data = userPheno
  )


  # save the fit model

  write(paste("I = ", i), stderr())

  userModels[[i]] <- myMod
}






######################################################################################
# 7. Backsolve from individual estimates to marker effect estimates / GBLUP -> RR-BLUP
######################################################################################

# a. Get the matrices and inverses needed
#    This is not correct for polyploids yet.
A.G <- G - (userPloidy / 2) # this is the additive genotype matrix (coded -1 0 1 for diploids)
D.G <- 1 - abs(A.G) # this is the dominance genotype matrix (coded 0 1 0 for diploids)


A.T <- A.G %*% t(A.G) ## additive genotype matrix
A.Tinv <- solve(A.T) # inverse; may cause an error sometimes, if so, add a small amount to the diag
A.TTinv <- t(A.G) %*% A.Tinv # M'%*% (M'M)-

D.T <- D.G %*% t(D.G) ## dominance genotype matrix
D.Tinv <- solve(D.T) ## inverse
D.TTinv <- t(D.G) %*% D.Tinv # M'%*% (M'M)-


# b. Loop through and backsolve to marker effects.

write("backsolve marker effects...", stderr())

userAddEff <- list() # save them in order
userDomEff <- list() # save them in order

for (i in 1:length(userModels)) {
  myMod <- userModels[[i]]

  # get the additive and dominance effects out of the sommer list
  subMod <- myMod$U
  subModA <- subMod[[1]]
  subModA <- subModA[[1]]
  subModD <- subMod[[2]]
  subModD <- subModD[[1]]

  # backsolve
  addEff <- A.TTinv %*% matrix(subModA[colnames(A.TTinv)], ncol = 1) # these must be reordered to match A.TTinv
  domEff <- D.TTinv %*% matrix(subModD[colnames(D.TTinv)], ncol = 1) # these must be reordered to match D.TTinv

  # add f coefficient back into the dominance effects
  subModf <- myMod$Beta
  fCoef <- subModf[subModf$Effect == "f", "Estimate"] # raw f coefficient
  fCoefScal <- fCoef / ncol(G) # divides f coefficient by number of markers
  dirDomEff <- domEff + fCoefScal

  # save
  userAddEff[[i]] <- addEff
  userDomEff[[i]] <- dirDomEff
}






################################################################################
# 8. Weight the marker effects and add them together to form an index of merit.
################################################################################

write("weight marker effects...", stderr())

ai <- 0
di <- 0
for (i in 1:length(userWeights)) {
  # write(paste("USER ADD EFF : ", userAddEff[[i]]), stderr())
  #  write(paste("USER DOM EFF : ", userDomEff[[i]]), stderr())
  # write(paste("USER WEIGHT : ", userWeights[i]), stderr())


  ai <- ai + userAddEff[[i]] * userWeights[i]

  write("DONE WITH ADDITIVE EFFECTS!\n", stderr())
  di <- di + userDomEff[[i]] * userWeights[i]
  write("DONE WITH DOM EFFECTS!\n", stderr())
}






################################################################################
# 9. Predict the crosses.
################################################################################

# If the genotype matrix provides information about individuals for which
# cross prediction is not desired, then the genotype matrix must be subset
# for use in calcCrossMean(). calcCrossMean will return predicted cross
# values for all individuals in the genotype file otherwise.

write("Predict crosses...", stderr())

GP <- G[rownames(G) %in% userPheno[, userID], ]

print("GP:")
print(head(GP))

write("calcCrossMean...", stderr())

crossPlan <- calcCrossMean(
  GP,
  ai,
  di,
  userPloidy
)


write("Done with calcCrossMean!!!!!!", stderr())



################################################################################
# 10. Format the information needed for output.
################################################################################

# Add option to remove crosses with incompatible sexes.


# hash <- new.env(hash = TRUE, parent = emptyenv(), size = 100L)

# assign_hash(userPheno$germplasmName, userPheno$userSexes, hash)

if (userSexes != "") { # "plant sex estimation 0-4"
  # !is.na(userSexes)  && !is.na(sd(userPheno[, userSexes]))

  write(paste("userSexes", sd(userPheno[, userSexes])), stderr())

  # Reformat the cross plan
  crossPlan <- as.data.frame(crossPlan)

  write(paste("CROSSPLAN = ", head(crossPlan)), stderr())
  crossPlan <- crossPlan[order(crossPlan[, 3], decreasing = TRUE), ] # orders the plan by predicted merit
  crossPlan[, 1] <- rownames(GP)[crossPlan[, 1]] # replaces internal ID with genotye file ID
  crossPlan[, 2] <- rownames(GP)[crossPlan[, 2]] # replaces internal ID with genotye file ID
  colnames(crossPlan) <- c("Parent1", "Parent2", "CrossPredictedMerit")

  write(paste("CROSSPLAN REPLACED = ", head(crossPlan)), stderr())

  # Look up the parent sexes and subset
  crossPlan$P1Sex <- userPheno[match(crossPlan$Parent1, userPheno$germplasmName), userSexes] # get sexes ordered by Parent1

  write(paste("PARENTS1 ", head(crossPlan)), stderr())

  crossPlan$P2Sex <- userPheno[match(crossPlan$Parent2, userPheno$germplasmName), userSexes] # get sexes ordered by Parent2

  write(paste("PARENTS2 ", head(crossPlan)), stderr())
  col_repl <- c("P1Sex", "P2Sex")
  crossPlan %>% filter(P1Sex == 0 | P2Sex == 0) # remove the 0s
  crossPlan %>% filter(P1Sex == 1 & P2Sex == 1) # remove same sex crosses with score of 1
  crossPlan %>% filter(P1Sex == 2 & P2Sex == 2) # remove same sex crosses with score of 2

  write(paste("CROSSPLAN FILTERED = ", crossPlan), stderr())
  # crossPlan <- crossPlan[crossPlan$P1Sex != crossPlan$P2Sex, ] # remove crosses with same-sex parents

  ## replace plant sex numbers to male, female etc

  crossPlan[col_repl] <- sapply(crossPlan[col_repl], function(x) replace(x, x %in% "NA", "NA"))
  crossPlan[col_repl] <- sapply(crossPlan[col_repl], function(x) replace(x, x %in% 1, "Male"))
  crossPlan[col_repl] <- sapply(crossPlan[col_repl], function(x) replace(x, x %in% 2, "Female"))
  crossPlan[col_repl] <- sapply(crossPlan[col_repl], function(x) replace(x, x %in% 3, "Monoecious male (m>f)"))
  crossPlan[col_repl] <- sapply(crossPlan[col_repl], function(x) replace(x, x %in% 4, "Monoecious female(f>m)"))

  # ** summary statistics for the cross prediction merit
  avg <- round(mean(crossPlan$CrossPredictedMerit), digits = 3)
  max <- round(max(crossPlan$CrossPredictedMerit), digits = 3)
  min <- round(min(crossPlan$CrossPredictedMerit), digits = 3)
  std <- round(sd(crossPlan$CrossPredictedMerit), digits = 3)
  leng <- length(crossPlan$CrossPredictedMerit)

  ## histogram
  histogra <- paste(phenotypeFile, ".png", sep = "")
  png(file = histogra, width = 600, height = 350)
  hist(crossPlan$CrossPredictedMerit, xlab = "Cross Predicted Merit", main = "Distribution")
  mtext(paste("Mean =", avg), side = 3, adj = 1, line = 0)
  mtext(paste("Standard Deviation = ", std), side = 3, adj = 1, line = -1)
  mtext(paste("Range = (", min, " to ", max, ")"), side = 3, adj = 1, line = -2)
  mtext(paste("No. of predictions = ", leng), side = 3, adj = 1, line = -3)
  dev.off()



  # subset the number of crosses the user wishes to output
  if (nrow(crossPlan)<100) {
    finalcrosses = crossPlan
  } else {
    crossPlan[1:userNCrosses, ]
    finalcrosses=crossPlan[1:userNCrosses, ]
  }
  outputFile <- paste(phenotypeFile, ".out", sep = "")

  write.csv(finalcrosses, outputFile)
} else {
  # only subset the number of crosses the user wishes to output
  crossPlan <- as.data.frame(crossPlan)
  crossPlan <- na.omit(crossPlan)
  crossPlan <- crossPlan[order(crossPlan[, 3], decreasing = TRUE), ] # orders the plan by predicted merit
  crossPlan[, 1] <- rownames(GP)[crossPlan[, 1]] # replaces internal ID with genotye file ID
  crossPlan[, 2] <- rownames(GP)[crossPlan[, 2]] # replaces internal ID with genotye file ID
  colnames(crossPlan) <- c("Parent1", "Parent2", "CrossPredictedMerit")

  # get summary statistics for the cross prediction merit
  avg <- round(mean(crossPlan$CrossPredictedMerit), digits = 3)
  max <- round(max(crossPlan$CrossPredictedMerit), digits = 3)
  min <- round(min(crossPlan$CrossPredictedMerit), digits = 3)
  std <- round(sd(crossPlan$CrossPredictedMerit), digits = 3)
  leng <- length(crossPlan$CrossPredictedMerit)


  ## histogram
  histogra <- paste(phenotypeFile, ".png", sep = "")
  png(file = histogra, width = 600, height = 350)
  hist(crossPlan$CrossPredictedMerit, xlab = "Cross Predicted Merit", main = "Distribution")
  mtext(paste("Mean =", avg), side = 3, adj = 1, line = 0)
  mtext(paste("Standard Deviation = ", std), side = 3, adj = 1, line = -1)
  mtext(paste("Range = (", min, " to ", max, ")"), side = 3, adj = 1, line = -2)
  mtext(paste("No. of predictions = ", leng), side = 3, adj = 1, line = -3)
  dev.off()

  ## save the best 100 predictions
  if (nrow(crossPlan)<100) {
    finalcrosses = crossPlan
  } else {
    crossPlan[1:userNCrosses, ]
    finalcrosses=crossPlan[1:userNCrosses, ]
  }
  outputFile <- paste(phenotypeFile, ".out", sep = "")

  write.csv(finalcrosses, outputFile)
}
