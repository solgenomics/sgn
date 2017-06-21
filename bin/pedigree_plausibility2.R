genotype_data <- read.table ("/home/klz26/host/test/267genotypes-p3.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
pedigree_data <- read.table ("/home/klz26/host/test/ped.txt", header = FALSE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)

colnames(pedigree_data)[1] <- "Name"
colnames(pedigree_data)[2] <- "Mother"
colnames(pedigree_data)[3] <- "Father"
colnames(genotype_data) <- gsub('\\|[^|]+$', '', colnames(genotype_data))
pedigree_data["Pedigree Conflict"] <- NA

length_g <- length(genotype_data[,1])
length_p <- length(pedigree_data[,1])
potential_conflicts <-0
bad_data <-0

for (x in 1:length_p)
{
  implausibility_count <- 0
  row_vector <- as.vector(pedigree_data[x,])

  test_child_name <- pedigree_data[x,1]
  test_mother_name <- pedigree_data[x,2]
  test_father_name <- pedigree_data[x,3]

  cat("Analyzing pedigree number", x, "...\n")

  if (test_father_name == "NULL" || test_child_name == "NULL" || test_mother_name == "NULL"){
  print ("Genotype information not all present, skipping analysis")
  break
  }

  for (q in 1:length_g)
  {
    child_score <- genotype_data[q, test_child_name]
    child_score <- round (child_score, digits = 0)

    mother_score <- genotype_data[q, test_mother_name]
    mother_score <- round(mother_score, digits = 0)

    father_score <- genotype_data[q, test_father_name]
    father_score <- round(father_score, digits = 0)

    parent_score <- mother_score + father_score
    SNP <- as.vector(genotype_data[q,1])

    if ((child_score == 1) || (mother_score == 1) || (father_score == 1)){
      bad_data <- bad_data + 1
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
  pedigree_data [x, 4] <- dosage_score
}

hist(pedigree_data$'Pedigree Conflict', main = "Distribution of Pedigree Conflict Scores", breaks = 20,
    xlab = "Pedigree  Conflict Scores", col = '#663300', labels = TRUE)

46 (38%), 76 (62%)
anomFilterBAF selects segments which are likely to be anomalous.

#pedigree_data$`Pedigree Conflict` <- sprintf("%.1f%%", pedigree_data$`Pedigree Conflict` * 100)
install.packages(GWAStools)
