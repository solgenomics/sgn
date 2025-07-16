
library("methods")
library("agricolae")
library("dplyr")
library("tidyr")


set.seed(54326)

##### Getting data #####
args = commandArgs(trailingOnly = TRUE)

pheno <- read.table(args[1], sep = "\t", header = TRUE)
study_trait <- args[2]
imputPheno <- args[3]
stability_method <- args[4]
jsonFile <- args[5]
graphFile <- args[6]
messageFile <- args[7]
jsonSummary <- args[8]


study_trait <- gsub("\\."," ",study_trait)

#Making names standard
names <- colnames(pheno)
new_names <- gsub(".CO.*","", names)
new_names <- gsub("\\."," ",new_names)
colnames(pheno) <- new_names

## Function for pheno imputation
pheno_imputation <- function(inData){
  library(mice)
  
  dat_imput <- spread(inData, Env, Yield)
  colnames(dat_imput) <- gsub(" ", "", colnames(dat_imput))
  #pmm is is the predictive mean matching
  pre_imputed <- mice(dat_imput,  method = "mean", m = 3, maxit = 10)
  final_imputed <- complete(pre_imputed, 1)
  
  final_imputed <- gather(final_imputed, "Env", "Yield", -c("Gen","Rep"))
  cat("Imput ok!")
  return(final_imputed)
}

imputation_accuracy <- function(checkDF, fMissing){
  checkDF$Gen <- as.character(checkDF$Gen)
  checkDF$Env <- as.character(checkDF$Env)
  
  realData <- pheno_imputation(checkDF)
  
  # Subseting to check imputation accuracy
  realData <- realData[order(realData$Gen, realData$Env), ]
  data_missing <- sample(rownames(realData), nrow(realData)*fMissing)
  testindDF <- realData
  testindDF <- testindDF[order(testindDF$Gen, testindDF$Env), ]
  testindDF[rownames(testindDF)%in% data_missing, "Yield"] <- NA
  
  testindDF$Gen <- as.factor(testindDF$Gen)
  testindDF$Env <- as.factor(testindDF$Env)
  testindDF$Rep <- as.factor(testindDF$Rep)
  
  imputed_test <- pheno_imputation(testindDF)
  imputed_test <- imputed_test[order(imputed_test$Gen, imputed_test$Env), ]
  cat("Imput Acc ok!\n")
  corrImput <- cor(realData$Yield,imputed_test$Yield, use = "complete")
  return(corrImput)
  
}



# Setting dataframe to required format
pheno <- pheno[,colnames(pheno) %in% c("locationName", "germplasmName", "replicate", "entryType", study_trait[1])]



########################################
#           Quality Control            #
# Checking conditions to run analysis  #
#                                      #
########################################

# Getting locations, accessions and reps
accessions_sel <- unique(pheno$germplasmName)
# Some breeding programs are using accession named Filler
accessions_sel <- accessions_sel[!accessions_sel == "Filler" | !accessions_sel == "filler"]

# Taking test accessions 
dat <- pheno %>% dplyr::select(germplasmName, locationName, replicate, entryType, trait=study_trait[1])
dat <- dat[dat$entryType == "test",]
nLoc <- length(unique(dat$locationName))
nReps <- max(dat$replicate)

# Number of reps mat be different for checks
# Fixing here
pheno <- pheno[pheno$replicate <= nReps & pheno$germplasmName %in% accessions_sel,]

# Preparing dataset for for analysis
dat1 <- pheno %>% dplyr::select(germplasmName, locationName, replicate, trait=study_trait[1])

fMissing <- nrow(dat1[is.na(dat1$trait),])/nrow(dat1)
message2 <- paste0("The frequency of missing data is too high. Please, check the dataset.")

summaryData <- data.frame(mean = mean(dat1[,4], na.rm=TRUE),
													min = min(dat1[,4], na.rm=TRUE),
													maxV = max(dat1[,4], na.rm=TRUE),
													sdV = sd(dat1[,4], na.rm=TRUE),
													missing = fMissing
													)

myJson <- jsonlite::toJSON(summaryData)
jsonlite::write_json(myJson, jsonSummary)


find_duplications <- function(inData){
  # Step 1: Identify duplicate rows based on the combination of four columns
  duplicated_rows <- duplicated(inData[, c("Gen", "Env", "Rep")])
  
  # Step 2: Calculate the average of 'Yield' for each unique combination of the four columns
  averages <- aggregate(Yield ~ Gen + Env + Rep, data = dat1, FUN = mean)
  
  # Step 3: Replace the duplicated rows with the calculated average
  pheno_unique <- inData[!duplicated_rows, ]  # Keep only unique rows
  pheno_unique <- merge(pheno_unique, averages, by = c("Gen", "Env", "Rep"), all.x = TRUE)
  
  # If there are any missing values (for rows that were not duplicated), fill them with the original 'Yield'
  pheno_unique$Yield <- ifelse(is.na(pheno_unique$Yield.y), pheno_unique$Yield.x, pheno_unique$Yield.y)
  
  # Remove unnecessary columns (if needed)
  pheno_unique <- pheno_unique[, !(names(pheno_unique) %in% c("Yield.x", "Yield.y"))]

  return(pheno_unique)
  
  # View the resulting data frame
}


dat1$germplasmName <- as.factor(dat1$germplasmName)
dat1$locationName <- as.factor(dat1$locationName)
dat1$replicate <- as.factor(dat1$replicate)
dat1$trait <- as.double(dat1$trait)

# Running model from stability package
# Assuming dat1 is your data frame
dat1 <- dat1[order(dat1$germplasmName, dat1$locationName), ]
colnames(dat1) <- c("Gen", "Env", "Rep", "Yield")


dat2 <- find_duplications(dat1)

if(imputPheno == "imput_yes"){
  testCor <- imputation_accuracy(dat2, fMissing)
  dat2 <- pheno_imputation(dat2)
  cat("The imputation accuracy is: ", sprintf("%.3f",testCor), "\n")
}

# testing if all accessions have the same number of reps in all locations
dat <- na.omit(dat2)
replicate_df <- data.frame(replicate = tapply(dat$Yield, list(dat$Gen, dat$Env), length))
replicate_df$germplasmName <- rownames(replicate_df)
gathered_df <- gather(replicate_df, key = "replicate_locations", value = "value", -germplasmName)
repAcc <- unique(gathered_df$value)
message1 <- paste0("Please, check dataset for accessions per locations and reps.")

# Saving error message
errorMessages <- c()
if(fMissing >= 0.4){
	errorMessages <- append(errorMessages, message2)
}else if(length(repAcc)>1){
  errorMessages <- append(errorMessages, message1)
}

# Setting second rep to compare augmented design with 1 rep per location
if(nReps == 1 && stability_method == "ammi"){
  dat2.1 <- dat2
  dat2.1$Rep <- as.numeric(dat2.1$Rep)
  dat2.1$Rep <- 2
  dat2$Rep <- as.numeric(dat2$Rep)
  dat2 <- rbind(dat2,dat2.1)
  dat2$Rep <- as.factor(dat2$Rep)
}else if (nReps == 1 && stability_method == "gge"){
	errorMessages <- append(errorMessages, "The number of replication must be greater than 1 for gge.")
}


if(stability_method=="ammi" && length(errorMessages) == 0 ){
	library("agricolae")

	model <- NULL
  # Running AMMI model
	tryCatch({
	  # Attempt to execute the code
	  model<- with(dat2,AMMI(Env, Gen, Rep, Yield, console=FALSE))
	}, error = function(e) {
	  # Handle the error by printing a message
	  cat("An error occurred:", conditionMessage(e), "\n")
	  append(errorMessages, paste0("An error occurred:", conditionMessage(e)))
	})

	index<-index.AMMI(model)
	index <- tibble::rownames_to_column(index, "Accession")
	indexDF <- data.frame(Accession = index$Accession, ASV = index$ASV, Rank = index$rASV)

	# Adding a column to scale ASV
	# This column will be used to plot stability lines
	slopes <- data.frame(Accession = index$Accession, slope = index$ASV, scaled= "NA")
	slopes$scaled <-as.vector(scale(slopes$slope, center = T, scale = F))
	indexDF <- left_join(indexDF, slopes, by="Accession")

	indexDF <- as.data.frame(indexDF)
	indexDF <- indexDF[order(indexDF[,3]),]

	## Preparing table with GxE effects
	list_data <- list(model$genXenv)
	dataGraphic <- data.frame(plyr::ldply(list_data))
	rownames(dataGraphic) <- model$means$GEN[1:(nrow(dataGraphic))]
	dataGraphic <- tibble::rownames_to_column(dataGraphic, "Accession")

	myMeans <- data.frame(Accession = model$means$GEN, location = model$means$ENV, means = model$means$Yield)
	myMeans$average <- myMeans$means
	myMeans$means <- as.vector(scale(myMeans$means, center = T, scale = FALSE))
	meanDF <- data.frame(tapply(myMeans$means, myMeans$Accession, mean))
	meanDF$Accession <- rownames(meanDF)
	colnames(meanDF) <- c("means", "Accession")
	meanDF <- left_join(meanDF, slopes, by = "Accession") %>% select(Accession, means, slope)
	meanDF$start <- 0
	meanDF$end <- length(unique(pheno$locationName)) 
	minDF <- data.frame(tapply(myMeans$means, myMeans$Accession, min))
	minDF$Accession <- rownames(minDF)
	colnames(minDF) <- c("minimum", "Accession")

	meanDFF <- left_join(meanDF, minDF, by = "Accession")
	meanDFF$value <- meanDFF$minimum*meanDF$slope
	meanDFF <- gather(meanDFF, key = "T", value = "X",start,end) %>% select(Accession, minimum, value, X) %>% arrange(Accession)
	meanDFF <- left_join(meanDFF, slopes, by = "Accession")

	for ( i in 1:nrow(meanDFF)){
	  if(meanDFF$X[i] == 0){
	    meanDFF$value[i] <- 0 
	  }else{
	    meanDFF$value[i] <- (-1)*meanDFF$slope[i]
	  }
	}

	scaled_values <- (meanDFF$value - min(meanDFF$value)) / (max(meanDFF$value) - min(meanDFF$value))
	meanDFF$value <- scaled_values

	myData <- data.frame(pivot_longer(dataGraphic, 2:ncol(dataGraphic), names_to = "location", values_to = "Effect"))
	myData$location <- gsub("\\."," ", myData$location)

	preFinal <- left_join(myData, myMeans, by = c("Accession", "location"))
	selLocations <- data.frame(locName = unique(preFinal$location), locNumber = c(1:length(unique(preFinal$location))))
	preFinal <- left_join(preFinal, selLocations, by = c("location"="locName")) 

	finalDF <- left_join(preFinal, indexDF, by="Accession") %>% dplyr::select(Accession, location, Effect, Rank, means, slope, scaled)
	finalDF <- finalDF[order(finalDF$Rank, -finalDF$Effect),]
	finalDF$Effect <- sprintf("%.3f", finalDF$Effect)
	finalDF$means <- sprintf("%.3f", finalDF$means)
	finalDF$slope <- sprintf("%.3f", finalDF$slope)
	finalDF$scaled <- sprintf("%.3f", finalDF$scaled)

	graphicJson <- jsonlite::toJSON(meanDFF)
	jsonlite::write_json(graphicJson, graphFile)

	# Parsing files to combine Accession, locations, effects, rank, averages, slopes
	preFinal <- left_join(myData, myMeans, by = c("Accession", "location"))
	finalDF <- left_join(preFinal, indexDF, by="Accession") %>% dplyr::select(Accession, location, Effect, Rank, average, slope, scaled)
	colnames(finalDF)[5] <- "means"
	if(imputPheno == "imput_yes"){finalDF$imputAcc <- testCor}
	finalDF <- finalDF[order(finalDF$Rank, -finalDF$Effect),]

	myJson <- jsonlite::toJSON(finalDF)
	jsonlite::write_json(myJson, jsonFile)

	}else if( stability_method=="gge" && length(errorMessages) == 0){
		library("stability")
		cat("running gge", "\n")
		# dat2 <- pheno_imputation(dat2)
    
    dat2$Env <- as.character(dat2$Env)
		effectsDF <- NULL
		# Use tryCatch to handle potential errors
		tryCatch({
		    # Attempt to execute the code
		    effectsDF <- stability::ge_means(.data = dat2, .y = Yield, .gen = Gen, .env = Env)
		}, error = function(e) {
		    # Handle the error by printing a message
		    cat("An error occurred:", conditionMessage(e), "\n")
		    append(errorMessages, paste0("An error occurred:", conditionMessage(e)))
		})
		
		effectsDF <-  stability::ge_means(.data=dat2, .y= Yield, .gen=Gen, .env=Env)

		test <- data.frame(effectsDF$ge_ranks)
		test$location <- rownames(test)
		gathered_df <- gather(test, key = "rank", value = "genotypes", -location)
		gathered_df$rank <- gsub("X", "", gathered_df$rank)
		gathered_df$rank <- as.numeric(gathered_df$rank)

		test1 <- data.frame(effectsDF$ge_means)
		gathered_mean <- gather(test1, key = "locations", value = "means", -Gen)


		gathered_df$track <- paste0(gathered_df$genotypes,"_",gathered_df$location)
		gathered_mean$track <- paste0(gathered_mean$Gen,"_",gathered_mean$locations)

		gathered_df$track <- gsub(" ","",gathered_df$track)
		gathered_df$track <- gsub("\\.","",gathered_df$track)

		gathered_mean$track <- gsub(" ","",gathered_mean$track)
		gathered_mean$track <- gsub("\\.","",gathered_mean$track)


		finalDF <- left_join(gathered_df, gathered_mean, by = "track") %>% dplyr::select(
		  genotypes, locations, means, rank
		)
		finalDF$locations <- gsub("\\."," ",finalDF$locations)

		rankDF <- data.frame(sumRank=tapply(finalDF$rank, finalDF$genotypes, sum))
		rankDF$genotypes <- rownames(rankDF)
		rankDF$genotypesRank <- rank(rankDF$sumRank, ties.method = "min")
		finalDF <- left_join(finalDF, rankDF, by = "genotypes") %>% dplyr::select(genotypes, locations, means, rank, genotypesRank) 
		colnames(finalDF) <- c("genotypes","locations", "means", "locationRank","genotypeRank")
		finalDF$means <- sprintf("%.2f", finalDF$means)

		colnames(finalDF) <- c("Accession", "location", "means", "locationRank", "genotypeRank")
		if(imputPheno == "imput_yes"){finalDF$imputAcc <- testCor}
		# Saving Json
		myJson <- jsonlite::toJSON(finalDF)
		jsonlite::write_json(myJson, jsonFile)


		## Preparing Graphic dataset
		prepGraph <- as.data.frame(tapply(dat2$Yield, list(dat2$Gen, dat2$Env), mean))
		prepGraph <- tibble::rownames_to_column(prepGraph, var="Accession")
		meanGraph <- gather(prepGraph, key = "location", value = "mean", -Accession)
		prepGraph2 <- as.data.frame(tapply(dat2$Yield, list(dat2$Gen, dat2$Env), sd))
		prepGraph2 <- tibble::rownames_to_column(prepGraph2, var="Accession")
		sdGraph <- gather(prepGraph2, key = "location", value = "sd", -Accession)
		finalGraph <- left_join(meanGraph, sdGraph, by=c("Accession","location"))

		graphicJson <- jsonlite::toJSON(finalGraph)
		jsonlite::write_json(graphicJson, graphFile)

	}

if ( is.null(errorMessages) == F ) {
  print(sprintf("Writing Error Messages to file: %s", messageFile))
  print(errorMessages)
  write(errorMessages, messageFile)
}

 