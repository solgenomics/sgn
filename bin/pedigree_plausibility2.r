genotype_data <- read.table ("/home/klz26/host/test/red_genos.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
pedigree_data <- read.table ("/home/klz26/host/test/Pedigrees.txt", header = TRUE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)

colnames(pedigree_data)[1] <- 'child_name'
colnames(pedigree_data)[2] <- 'mother_name'
colnames(pedigree_data)[3] <- 'father_name'


length_g <- length(genotype_data[,1])
length_p <- length(pedigree_data[,1])
implausibility_count <- 0

for (x in 1:length_g)
{

row_vector <- as.vector(pedigree_data[x,])

test_child_name <- pedigree_data[x,1]

test_mother_name <- pedigree_data[x,2]

test_father_name <- pedigree_data[x,3]

if (test_father_name == "NULL" || test_child_name == "NULL" || test_mother_name == "NULL") 
  {print ("Genotypes not all present, skipping analysis")}

for (q in 1:length(genotype_data[,1]))
{
  genotype_data[q, test_child_name]
  child_score <- .Last.value
  
  genotype_data[q, test_mother_name]
  mother_score <- .Last.value

  genotype_data[q, test_father_name]
  father_score <- .Last.value

  parent_score <- mother_score + father_score

    if (child_score > parent_score) {
        implausibility_count <- implausibility_count + 1

    }  else if (mother_score == 2 & father_score == 2 & child_score != 2) {
       implausibility_count <- implausibility_count + 1

    }  else if (mother_score == 2 || father_score == 2 & child_score == 0) {
       implausibility_count <- implausibility_count + 1

    }  else if ((xor(mother_score == 2, father_score == 2)) & (xor(mother_score == 0, 
                father_score == 0)) & child_score == 2) {
       implausibility_count <- implausibility_count + 1
    }
}
}
print (implausibility_count)


