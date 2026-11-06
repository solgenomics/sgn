
library("methods")
library("agricolae")
library("dplyr")
library("tidyr")


set.seed(54326)

##### Getting data #####
args = commandArgs(trailingOnly = TRUE)

design_source <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) design_source <- frame$ofile
if (is.null(design_source)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    design_source <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) design_source <- invocation[file_index[1] + 1L]
  }
}
if (is.null(design_source) || is.na(design_source) || !nzchar(design_source)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(design_source)), "../design_replication.R"))
source(file.path(dirname(normalizePath(design_source)), "stability_data.R"))
pheno <- read_analysis_phenotypes(args[1])
study_trait <- args[2]
imputPheno <- args[3]
stability_method <- args[4]
jsonFile <- args[5]
graphFile <- args[6]
messageFile <- args[7]
jsonSummary <- args[8]

# The request historically supplies syntactic trait names. Match the existing
# display-name convention without changing design tags or environment names.
study_trait <- gsub("\\.", " ", study_trait)
colnames(pheno) <- gsub("\\.", " ", gsub(".CO.*", "", colnames(pheno)))
prepared <- tryCatch(prepare_stability_data(pheno, study_trait, stability_method,
                                           imputPheno == "imput_yes"), error = function(e) {
  write(conditionMessage(e), messageFile)
  stop(e)
})
dat1 <- prepared$observations
dat2 <- prepared$model_data
testCor <- prepared$imputation_accuracy
summaryData <- prepared$summary
errorMessages <- character()
jsonlite::write_json(jsonlite::toJSON(summaryData), jsonSummary)

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
	  write(paste0("AMMI analysis failed: ", conditionMessage(e)), messageFile)
	  stop(e)
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

	}else if(stability_method == "gge") {
  # GGE ranks genotype-by-environment means. No cross-environment pairing of
  # plots, replicate tags or accession occurrence counters is required.
  library(stability)
  means <- dat2[,c("Gen","Env","Yield")]
  original_genotypes <- unique(as.character(means$Gen))
  original_environments <- unique(as.character(means$Env))
  safe_genotypes <- paste0("G",seq_along(original_genotypes))
  safe_environments <- paste0("E",seq_along(original_environments))
  means$Gen <- safe_genotypes[match(means$Gen,original_genotypes)]
  means$Env <- safe_environments[match(means$Env,original_environments)]
  effectsDF <- stability::ge_means(.data=means,.y=Yield,.gen=Gen,.env=Env)
  ranks <- as.data.frame(effectsDF$ge_ranks,check.names=FALSE)
  ranks$Env <- rownames(ranks)
  ranks <- tidyr::pivot_longer(ranks,cols=-Env,names_to="rank",values_to="Gen")
  ranks$locationRank <- as.numeric(gsub("^X","",ranks$rank))
  values <- tidyr::pivot_longer(as.data.frame(effectsDF$ge_means,check.names=FALSE),cols=-Gen,names_to="Env",values_to="Yield")
  finalDF <- merge(ranks[,c("Gen","Env","locationRank")],values,by=c("Gen","Env"),sort=FALSE)
  rank_sum <- aggregate(locationRank ~ Gen,finalDF,sum)
  rank_sum$genotypeRank <- rank(rank_sum$locationRank,ties.method="min")
  finalDF <- merge(finalDF,rank_sum[,c("Gen","genotypeRank")],by="Gen",sort=FALSE)
  finalDF$Gen <- original_genotypes[match(finalDF$Gen,safe_genotypes)]
  finalDF$Env <- original_environments[match(finalDF$Env,safe_environments)]
  names(finalDF)[match(c("Gen","Env","Yield"),names(finalDF))] <- c("Accession","location","means")
  finalDF$means <- sprintf("%.2f",finalDF$means)
  finalDF <- finalDF[,c("Accession","location","means","locationRank","genotypeRank")]
  if(imputPheno == "imput_yes") finalDF$imputAcc <- testCor
  jsonlite::write_json(jsonlite::toJSON(finalDF), jsonFile)
  sd_data <- aggregate(Yield ~ Gen + Env, dat1, function(x) sd(x, na.rm=TRUE), na.action=na.pass)
  names(sd_data)[3] <- "sd"
  finalGraph <- merge(dat2[,c("Gen","Env","Yield")],sd_data,by=c("Gen","Env"),all.x=TRUE,sort=FALSE)
  names(finalGraph)[1:3] <- c("Accession","location","mean")
  jsonlite::write_json(jsonlite::toJSON(finalGraph), graphFile)
}

if ( is.null(errorMessages) == F ) {
  print(sprintf("Writing Error Messages to file: %s", messageFile))
  print(errorMessages)
  write(errorMessages, messageFile)
}

 