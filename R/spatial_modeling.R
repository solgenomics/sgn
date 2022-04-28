################################################################################
# Modeling Spatial Variation
################################################################################

# There are ten main steps to this protocol:
# 1. Load the software needed.
# 2. Declare user-supplied variables.
# 3. Process the phenotypic data.
# 4. Fit the mixed models in sommer.
# 5. Format the information needed for output.


################################################################################
# 1. Load software needed
################################################################################

library(sommer)


################################################################################
# 2. Declare user-supplied variables.
################################################################################
#Get Arguments
args = commandArgs(trailingOnly=TRUE)
if (length(args) < 2) {
  stop('Two or more arguments are required.')
}
phenotypeFile = args[1]
traits = args[2]


################################################################################
# 3. Process the phenotypic data.
################################################################################
#read in the phenotypic data
userPheno <- read.delim(phenotypeFile, header = TRUE, sep="\t", fill=TRUE) 

#The user should be able to select their response variables from a drop-down menu
#    of the column names of the userPheno object. Then, those strings should be passed
#    to this vector, 'userResponse'.

userResponse <- unlist(strsplit(traits, split=",", fixed=T))
userID <- "germplasmName"
row <- "rowNumber"
col <- "colNumber"
userPheno$R <- as.factor(userPheno$rowNumber)
userPheno$C <- as.factor(userPheno$colNumber)


################################################################################
# 4. Fit the 2D Spline model in sommer
################################################################################
# Make a list to save the models.

userModels <- list()

for(i in 1:length(userResponse)){
  
   fixedArg <- paste(userResponse[i], " ~ ", "1 +", userID,")", sep = "")
   
   randArg <- paste("~", R, "+", C, "+ spl2Da(",col,"," ,row ,")", sep = "")
   
   
   m2.sommer <- mmer(fixed = as.formula(fixedArg),
                     random = as.formula(randArg),
                     data=userPheno, verbose = FALSE)
   
   
   
   
   userModels[[i]] <- m2.sommer
   
}


################################################################################
# 5. Format the information needed for output.
################################################################################


for(i in 1:length(userModels)){
  
  m2.sommer <- userModels[[i]]
  
  Variance_Components <- summary(m2.sommer)$varcomp
  
  outputFile= paste(userID, " Spatial Variance Components", ".out", sep="")
  
  write.csv(Variance_Components, outputFile)
  
}