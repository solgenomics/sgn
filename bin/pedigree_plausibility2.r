genotype_data <- read.table ("/home/klz26/host/test/red_genos.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
pedigree_data <- read.table ("/home/klz26/host/test/Pedigrees.txt", header = TRUE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)

colnames(pedigree_data)[1] <- "Name"
colnames(pedigree_data)[2] <- "Mother"
colnames(pedigree_data)[3] <- "Father"
pedigree_data["Pedigree Conflict"] <- NA

length_g <- length(genotype_data[,1])
length_p <- length(pedigree_data[,1])
implausibility_count <- 0

for (x in 1:length_p)
{
  row_vector <- as.vector(pedigree_data[x,])

  test_child_name <- pedigree_data[x,1]
  test_mother_name <- pedigree_data[x,2]
  test_father_name <- pedigree_data[x,3]

  if (test_father_name == "NULL" || test_child_name == "NULL" || test_mother_name == "NULL"){
  print ("Genotypes not all present, skipping analysis")
  }

  for (q in 1:length_g)
  {
    genotype_data[q, test_child_name]
    child_score <- .Last.value
    child_score <- round (child_score, digits = 0)
    
    genotype_data[q, test_mother_name]
    mother_score <- .Last.value
    mother_score <- round(father_score, digits = 0)
    
    genotype_data[q, test_father_name]
    father_score <- .Last.value
    father_score <- round(father_score, digits = 0)

    parent_score <- mother_score + father_score
    SNP <- row_vector <- as.vector(genotype_data[q,1])
    if (child_score > parent_score) {
        implausibility_count <- implausibility_count + 1
        print (SNP + "of line" + test_child_name + "shows a potential pedigree conflict")
      } else if (mother_score == 2 & father_score == 2 & child_score != 2) {
       implausibility_count <- implausibility_count + 1
       print (SNP + "of line" + test_child_name + "shows a potential pedigree conflict")
      } else if (mother_score == 2 || father_score == 2 & child_score == 0) {
       implausibility_count <- implausibility_count + 1
       print (SNP + "of line" + test_child_name + "shows a potential pedigree conflict")
      } else if ((xor(mother_score == 2, father_score == 2)) & (xor(mother_score == 0, 
       father_score == 0)) & child_score == 2) {
       implausibility_count <- implausibility_count + 1
       print (SNP + "of line" + test_child_name + "shows a potential pedigree conflict")
      }
    dosage_score <- implausibility_count / length_g
    dosage_score <- round(dosage_score, digits = 1)
    if (dosage_score > 5) {
      potential_conflicts <- potential_conflicts + 1
    }
    dosage_score<- sprintf("%.1f%%", dosage_score)
    pedigree_data [x, 4] <- dosage_score
    implausibility_count <- 0
  }
}
if (potential_conflicts == 1) {
  print (potential_conflicts + "line shows a potential pedigree conflict")
} else {
  print (potential_conflicts + "lines show potential pedigree conflicts")
}