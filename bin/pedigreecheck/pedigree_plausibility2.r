library(pedigreemm)
library(proxy)
library(dplyr)
library(foreach)
library(doMC)

cores <- (detectCores() -1)
cl <- makeCluster(cores)
registerDoMC(3)
getDoParWorkers()

genotype_data <- read.table ("/home/klz26/host/test/6genotypes-p3.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "na")
pedigree_data <- read.table ("/home/klz26/host/test/poscontrol.txt", header = FALSE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)

colnames(pedigree_data)[1] <- "Name"
colnames(pedigree_data)[2] <- "Mother"
colnames(pedigree_data)[3] <- "Father"
colnames(genotype_data) <- gsub('\\|[^|]+$', '', colnames(genotype_data))
pedigree_data["Pedigree Conflict"] <- NA
pedigree_data["Markers Skipped"] <- NA
pedigree_data["Informative Markers"] <- NA

length_p <- length(pedigree_data[,1])
potential_conflicts <-0
bad_data <-0
length_g <- length(genotype_data[,1])
z <- 1
q <- 1
geno.bad <- 0
exclude_list <- 0
rownames(genotype_data) <- as.character(unlist(genotype_data[,1]))
genotype_data = genotype_data[,-1]

filter.fun <- function(geno,IM,MM,H){
  #Remove individuals with more than a % missing data
  individual.missing <- apply(geno,1,function(x){
    return(length(which(is.na(x)))/ncol(geno))
  })
  #length(which(individual.missing>0.40)) #will tell you how many
  #individulas needs to be removed with 20% missing.
  #Remove markers with % missing data
  marker.missing <- apply(geno,2,function(x)
  {return(length(which(is.na(x)))/nrow(geno))
    
  })
  length(which(marker.missing>0.6))
  #Remove markers herteozygous calls more than %.
  heteroz <- apply(geno,1,function(x){
    return(length(which(x==0))/length(!is.na(x)))
  })
  
  filter1 <- geno[which(individual.missing<IM),which(marker.missing<MM)]
  #filter2 <- filter1[,(heteroz<H)]
  return(filter1)
}

geno.bad <- filter.fun(genotype_data[2:359792,],0.1,0.1,0.2)
exclude_list <- geno.bad
subset_matrix <- genotype_data[!(rownames(genotype_data) %in% rownames(exclude_list)),] 

results <- foreach (z = 1:5, .combine = rbind) %dopar%
{
  implausibility_count <- 0
  bad_data <- 0
  row_vector <- as.vector(pedigree_data[z,])

  test_child_name <- pedigree_data[z,1]
  test_mother_name <- pedigree_data[z,2]
  test_father_name <- pedigree_data[z,3]

  cat("Analyzing pedigree number", z, "...\n")
  
  #if (test_father_name == "NULL" || test_child_name == "NULL" || test_mother_name == "NULL"){
  #  print ("Genotype information not all present, skipping analysis")
  #  break
  #}
  
  for (q in 1:length_g)
  {
    child_score <- subset_matrix[q, test_child_name]
    #child_score <- round (child_score, digits = 0)
    
    mother_score <- subset_matrix[q, test_mother_name]
    #mother_score <- round(mother_score, digits = 0)
    
    father_score <- subset_matrix[q, test_father_name]
    #father_score <- round(father_score, digits = 0)
    
    parent_score <- mother_score + father_score
    SNP <- as.vector(subset_matrix[q,1])
    if ((is.na(child_score)) || (is.na(mother_score)) || (is.na(father_score))){
      bad_data <- bad_data + 1
      next  
    }
    if ((child_score == 1) || (mother_score == 1) || (father_score == 1)){
      bad_data <- bad_data + 1
      next  
    }
    if ((child_score != 0 && child_score != 2) || (mother_score != 0 && mother_score != 2) ||
        (father_score != 0 && father_score != 2)){
      bad_data <- bad_data +1
      next
    }
    
    if (child_score > parent_score) {
      implausibility_count <- implausibility_count + 1
    } else if ((mother_score == 2 && father_score == 2) && child_score != 2) {
      implausibility_count <- implausibility_count + 1
    } else if ((mother_score == 2 || father_score == 2) && child_score == 0) {
      implausibility_count <- implausibility_count + 1
    } else if ((xor(mother_score == 2, father_score == 2)) && (xor(mother_score == 0, 
                                                                   father_score == 0)) && child_score == 2) {
      implausibility_count <- implausibility_count + 1
    }
  }
  dosage_score <- implausibility_count / length_g
  #dosage_score<- sprintf("%.1f%%", dosage_score * 100)
  #pedigree_data [z, 4] <- dosage_score
  #pedigree_data [z, 5] <- bad_data
  informative <- length_g - bad_data
  #pedigree_data [z,6] <- informative
  #cat(pedigree_data$Name,pedigree_data$Mother,pedigree_data$Father,pedigree_data$`Pedigree Conflict`, pedigree_data$`Markers Skipped`,
  #    pedigree_data$`Informative Markers`,file=f_out,sep=" ",append=TRUE);
  return_vector <- pedigree_data [z,] 
  return_vector [6] <- informative
  return_vector [5] <- bad_data
  return_vector[4] <- dosage_score
  return_vector
}



pedigree_data$`Percent Removed` <- (pedigree_data$`Markers Skipped` / length_g ) * 100

hist(pedigree_data$'Pedigree Conflict', main = "Distribution of Pedigree Conflict Scores", breaks = 20, 
     xlab = "Pedigree  Conflict Scores", col = '#663300', labels = TRUE)

pedigreedata2 <- editPed(dam=pedigree_data$Mother, sire=pedigree_data$Father, label=pedigree_data$Name)
#pedigreeNoNAS <- pedigreedata2 [,complete.cases(pedigreedata2) ]
pedigreedata3 <- pedigree(pedigreedata2$sire, pedigreedata2$dam, pedigreedata2$label)
cassavaAmat <- getA(pedigreedata3)
# example: cassavaAmat[,"NR110122"]

#46 (38%), 76 (62%)
#anomFilterBAF selects segments which are likely to be anomalous.

#pedigree_data$`Pedigree Conflict` <- sprintf("%.1f%%", pedigree_data$`Pedigree Conflict` * 100)
#install.packages(GWAStools)

#column_vector <- as.vector(pedigree_data[x,])


