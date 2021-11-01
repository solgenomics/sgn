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


#Get Arguments
args = commandArgs(trailingOnly=TRUE)
if (length(args)!=2) {
  stop('Two Arguments are required.')
}
phenotype_file= args[1]
genotype_file= args[2]


################################################################################
# 1. Load software needed
################################################################################

library(sommer)
library(AGHmatrix)
Rcpp::sourceCpp("../QuantGenResources/CalcCrossMeans.cpp") # this is called CalcCrossMean.cpp on Github






################################################################################
# 2. Declare user-supplied variables
################################################################################

# a. Define path with internal YamBase instructions such that the object 'userGeno'
#    is defined as a VCF file of genotypes.

#userGeno <- path


# b. Define path2 with internal YamBase instructions such that the object 'userPheno'
#    is defined as the phenotype file.

#userPheno <- path2
userPheno <- read.csv(phenotype_file, header = TRUE) #testing only
userPheno <- userPheno[userPheno$Trial == "SCG", ] #testing only-- needs to replaced with 2-stage


# c. The user should be able to select their fixed variables from a menu
#    of the column names of the userPheno object. The possible interaction terms
#    also need to be shown somehow. Then, those strings should be passed
#    to this vector, 'userFixed'. Please set userFixed to NA if no fixed effects
#    besides f are requested.
#    f is automatically included as a fixed effect- a note to the user would be good.

userFixed <- c()
userFixed <- c("Year") # for testing only


# d. The user should be able to select their random variables from a menu
#    of the column names of the userPheno object. The possible interaction terms
#    also need to be shown somehow. Then, those strings should be passed
#    to this vector, 'userRandom'.

userRandom <- c()
userRandom <- "Block" # for testing only


# e. The user should be able to indicate which of the userPheno column names
#    represents individual genotypes identically as they are represented in the VCF
#    column names. No check to ensure matching at this stage. This single string
#    should be passed to this vector, userID.

userID <- c()
userID <- "Accession" # for testing only


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

userResponse <- c()
userResponse <- c("YIELD", "DMC", "OXBI") # for testing only


# h. The user must indicate weights for each response. The order of the vector
#    of response weights must match the order of the responses in userResponse.

userWeights <- c()
userWeights <- c(1, 0.8, 0.2) # for YIELD, DMC, and OXBI respectively; for testing only


# i. The user can indicate the number of crosses they wish to output.
#    The maximum possible is a full diallel.

userNCrosses <- c()
userNCrosses <- 40 # for testing only


# j. The user can (optionally) input the individuals' sexes and indicate the column
#    name of the userPheno object which corresponds to sex. The column name
#   string should be passed to the 'userSexes' object. If the user does not wish
#   to remove crosses with incompatible sexes (e.g. because the information is not available),
#   then userSexes should be set to NA.


userSexes <- c()
userSexes <- "Sex" # for testing only
userPheno$Sex <- sample(c("M", "F"), size = nrow(userPheno), replace = TRUE, prob = c(0.7, 0.3)) # for testing only
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

#   VCF format is notoriously flexible/variable and to my knowledge it is not
#   considered best practice to parse VCFs with custom scripts. There are a lot
#   of different styles within VCF that technically meet its specifications but
#   cause scripts to break. I am checking in with someone from Ploidyverse
#   to find out best practice for this.

#   TEST temporarily import the genotypes via HapMap:

source("R/hapMap2numeric.R") # replace and delete
G <- hapMap2numeric(genotype_file) # replace and delete






################################################################################
# 4. Get the genetic predictors needed.
################################################################################

# 4a. Get the inbreeding coefficent, f, as described by Xiang et al., 2016
# The following constructs f as the average heterozygosity of the individual
# The coefficient of f estimated later then needs to be divided by the number of markers
# in the matrix D before adding it to the estimated dominance marker effects
# One unit of change in f represents changing all loci from homozygous to heterozygous

GC <- G - (userPloidy/2) #this centers G
f <- rowSums(GC, na.rm = TRUE) / apply(GC, 1, function(x) sum(!is.na(x)))

# Another alternate way to construct f is the total number of heterozygous loci in the individual
# The coefficient of this construction of f does not need to be divided by the number of markers
# It is simply added to each marker dominance effect
# The coefficient of this construction of f represents the average dominance effect of a marker
# One unit of change in f represents changing one locus from homozygous to heterozygous
# f <- rowSums(D, na.rm = TRUE)



# 4b. Get the additive and dominance relationship matrices. This uses AGHmatrix.

A <- Gmatrix(G, method = "VanRaden", ploidy = userPloidy, missingValue = NA)

if(userPloidy == 2){
  D <- Gmatrix(G, method = "Su", ploidy = userPloidy, missingValue = NA)
}

# I haven't tested this yet
if(userPloidy > 2){
  D <- Gmatrix(G, method = "Slater", ploidy = userPloidy, missingValue = NA)
}






################################################################################
# 5. Process the phenotypic data.
################################################################################

# a. Paste f into the phenotype dataframe
userPheno$f <- f[as.character(userPheno[ , userID])]


# b. Scale the response variables.
for(i in 1:length(userResponse)){
  userPheno[ , userResponse[i]] <- (userPheno[ , userResponse[i]] -
                                      mean(userPheno[ , userResponse[i]], na.rm = TRUE))/
    sd(userPheno[ , userResponse[i]], na.rm = TRUE)
}


# c. Paste in a second ID column for the dominance effects.
userPheno[ , paste(userID, 2, sep = "")] <- userPheno[ , userID]


# Additional steps could be added here to remove outliers etc.





################################################################################
# 6. Fit the mixed models in sommer.
################################################################################


# 6a. Make a list to save the models.
userModels <- list()

for(i in 1:length(userResponse)){


  # check if fixed effects besides f are requested, then paste together
  # response variable and fixed effects
  if(!is.na(userFixed[1])){
  fixedEff <- paste(userFixed, collapse = " + ")
  fixedEff <- paste(fixedEff, "f", sep = " + ")
  fixedArg <- paste(userResponse[i], " ~ ", fixedEff, sep = "")
  }
  if(is.na(userFixed[1])){
    fixedArg <- paste(userResponse[i], " ~ ", "f")
  }


  # check if random effects besides genotypic additive and dominance effects
  # are requested, then paste together the formula
  if(!is.na(userRandom[1])){
    randEff <- paste(userRandom, collapse = " + ")
    ID2 <- paste(userID, 2, sep = "")
    randEff2 <- paste("~vs(", userID, ", Gu = A) + vs(", ID2, ", Gu = D)", sep = "")
    randArg <- paste(randEff2, randEff, sep = " + ")
  }
  if(is.na(userRandom[1])){
    randArg <- paste("~vs(", userID, ", Gu = A) + vs(", ID2, ", Gu = D)", sep = "")
  }


  # fit the mixed GBLUP model
  myMod <- mmer(fixed = as.formula(fixedArg),
                random = as.formula(randArg),
                rcov = ~units,
                getPEV = FALSE,
                data = userPheno)


  # save the fit model
  userModels[[i]] <- myMod
}






######################################################################################
# 7. Backsolve from individual estimates to marker effect estimates / GBLUP -> RR-BLUP
######################################################################################

# a. Get the matrices and inverses needed
#    This is not correct for polyploids yet.
A.G <- G - (userPloidy / 2) # this is the additive genotype matrix (coded -1 0 1 for diploids)
D.G <- 1 - abs(A.G)     # this is the dominance genotype matrix (coded 0 1 0 for diploids)


A.T <- A.G %*% t(A.G) ## additive genotype matrix
A.Tinv <- solve(A.T) # inverse; may cause an error sometimes, if so, add a small amount to the diag
A.TTinv <- t(A.G) %*% A.Tinv # M'%*% (M'M)-

D.T <- D.G %*% t(D.G) ## dominance genotype matrix
D.Tinv <- solve(D.T) ## inverse
D.TTinv <- t(D.G) %*% D.Tinv # M'%*% (M'M)-


# b. Loop through and backsolve to marker effects.

userAddEff <- list() # save them in order
userDomEff <- list() # save them in order

for(i in 1:length(userModels)){

  myMod <- userModels[[i]]

  # get the additive and dominance effects out of the sommer list
  subMod <- myMod$U
  subModA <- subMod[[1]]
  subModA <- subModA[[1]]
  subModD <- subMod[[2]]
  subModD <- subModD[[1]]

  # backsolve
  addEff <- A.TTinv %*% matrix(subModA[colnames(A.TTinv)], ncol = 1) # these must be reordered to match A.TTinv
  domEff <- D.TTinv %*% matrix(subModD[colnames(D.TTinv)], ncol=1)   # these must be reordered to match D.TTinv

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

ai <- 0
di <- 0
for(i in 1:length(userWeights)){
  ai <- ai + userAddEff[[i]] * userWeights[i]
  di <- di + userDomEff[[i]] * userWeights[i]
}






################################################################################
# 9. Predict the crosses.
################################################################################

# If the genotype matrix provides information about individuals for which
# cross prediction is not desired, then the genotype matrix must be subset
# for use in calcCrossMean(). calcCrossMean will return predicted cross
# values for all individuals in the genotype file otherwise.

GP <- G[rownames(G) %in% userPheno[ , userID], ]


crossPlan <- calcCrossMean(GP,
                           ai,
                           di,
                           userPloidy)






################################################################################
# 10. Format the information needed for output.
################################################################################

# Add option to remove crosses with incompatible sexes.

if(!is.na(userSexes)){
  
  # Reformat the cross plan
  crossPlan <- as.data.frame(crossPlan)
  crossPlan <- crossPlan[order(crossPlan[,3], decreasing = TRUE), ] # orders the plan by predicted merit
  crossPlan[ ,1] <- rownames(GP)[crossPlan[ ,1]] # replaces internal ID with genotye file ID
  crossPlan[ ,2] <- rownames(GP)[crossPlan[ ,2]] # replaces internal ID with genotye file ID
  colnames(crossPlan) <- c("Parent1", "Parent2", "CrossPredictedMerit")
  
  # Look up the parent sexes and subset
  crossPlan$P1Sex <- userPheno[match(crossPlan$Parent1, userPheno$Accession), userSexes] # get sexes ordered by Parent1
  crossPlan$P2Sex <- userPheno[match(crossPlan$Parent2, userPheno$Accession), userSexes] # get sexes ordered by Parent2
  crossPlan <- crossPlan[crossPlan$P1Sex != crossPlan$P2Sex, ] # remove crosses with same-sex parents
  
  
  # subset the number of crosses the user wishes to output
  crossPlan[1:userNCrosses, ]
  output_file= paste(phenotype_file, ".out", sep="")
  
}


if(is.na(userSexes)){
  
  # only subset the number of crosses the user wishes to output
  crossPlan[1:userNCrosses, ]
  output_file= paste(phenotype_file, ".out", sep="")
  
}
