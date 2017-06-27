#R --vanilla '--args 267genotypes-p3.txt ped.txt sink.txt' <pedigreeplausibilitycommandline.R
#ssh klz26@login.sgn.cornell.edu
#rail -f -n 100 log.txt

library(pedigreemm)
library(proxy)
library(doParallel)
library(foreach)

cores <- (detectCores() -1)
cl <- makeCluster(cores)
registerDoParallel(cl)

myarg <- (commandArgs(TRUE))
geno_in <-(myarg[1:1])
genotype_data <- read.table(geno_in, header = TRUE, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "na")
ped_in <- (myarg[2:2])
pedigree_data <- read.table (ped_in, header = FALSE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)

f_out <- (myarg[3:3])
cat(myarg,"\n")
m=length(myarg)
cat(m,"\n")

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
  individual.missing <- apply(geno,1,function(x){
    return(length(which(is.na(x)))/ncol(geno))
  })
  marker.missing <- apply(geno,2,function(x)
  {return(length(which(is.na(x)))/nrow(geno))
    
  })
  length(which(marker.missing>0.6))
  heteroz <- apply(geno,1,function(x){
    return(length(which(x==0))/length(!is.na(x)))
  })
  
  filter1 <- geno[which(individual.missing<IM),which(marker.missing<MM)]
  return(filter1)
}

geno.bad <- filter.fun(genotype_data[2:359792,],0.1,0.1,0.2)
exclude_list <- geno.bad
subset_matrix <- genotype_data[!(rownames(genotype_data) %in% rownames(exclude_list)),] 

foreach (z = 1:length_p, .combine = rbind) %dopar%
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
    
    mother_score <- subset_matrix[q, test_mother_name]
    
    father_score <- subset_matrix[q, test_father_name]
    
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
  #pedigree_data [z, 4] <- dosage_score
  #pedigree_data [z, 5] <- bad_data
  informative <- length_g - bad_data
  #pedigree_data [z,6] <- informative
  cat(pedigree_data$Name,pedigree_data$Mother,pedigree_data$Father,pedigree_data$`Pedigree Conflict`, pedigree_data$`Markers Skipped`,
      pedigree_data$`Informative Markers`,file=f_out,sep=" ",append=TRUE);
  return_vector <- pedigree_data [z,] 
  return_vector [6] <- informative
  return_vector [5] <- bad_data
  return_vector[4] <- dosage_score
  return_vector
}  
