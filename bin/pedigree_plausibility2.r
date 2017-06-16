genotype_data <- read.table ("/home/klz26/host/test/red_genos.txt", header = TRUE)
pedigree_data <- read.table ("/home/klz26/host/test/Pedigrees.txt", header = TRUE, sep = "\t")

colnames(pedigree_data)[1] <- 'child_name'
colnames(pedigree_data)[2] <- 'mother_name'
colnames(pedigree_data)[3] <- 'father_name'

q <- 1
x <- 1

length_g <- length(genotype_data[,1])
length_p <- length(pedigree_data[,1])
implausibility_count <- 0

while (x <= length_g)
{

row_vector <- as.vector(pedigree_data[x,])

test_child_name <- row_vector[1]
colnames(test_child_name) <- c()
rownames(test_child_name) <- c()

test_mother_name <- row_vector[2]
colnames(test_mother_name) <- c()
rownames(test_mother_name) <- c()

test_father_name <- row_vector[3]
colnames(test_father_name) <- c()
rownames(test_father_name) <- c()

x <- x+1

while (q <= length(genotype_data[,1]))
{
  genotype_data[q, "test_child_name"]
  child_score <- .Last.value
  colnames(child_score) <- c()
  rownames(child_score) <- c()

  genotype_data[q, "test_mother_name"]
  mother_score <- .Last.value
  colnames(mother_score) <- c()
  rownames(mother_score) <- c()

  genotype_data[q, "test_father_name"]
  father_score <- .Last.value
  colnames(father_score) <- c()
  rownames(father_score) <- c()

  q <- q + 1
  parent_score <- mother_score + father_score

    if (child_score > parent_score) {
        implausibility_count <- implausibility_count + 1

    }  else if (mother_score == 2 & father_score == 2 & child_score != 2) {
       implausibility_count <- implausibility_count + 1

    }  else if (mother_score == 2 | father_score == 2 & child_score == 0) {
       implausibility_count <- implausibility_count + 1

    }  else if (mother_score == 2 | father_score == 2 & child_score == 2) {
       implausibility_count <- implausibility_count + 1
    }
}
}
print (implausibility_count)
