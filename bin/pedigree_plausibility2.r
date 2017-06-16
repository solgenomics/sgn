genotype_data <- read.table ("/home/klz26/host/test/genotypes.txt", header = TRUE)
pedigree_data <- read.table ("/home/klz26/host/test/Pedigrees.txt", header = TRUE, sep = "\t")

colnames(pedigree_data)[1] <- 'child_name'
colnames(pedigree_data)[2] <- 'mother_name'
colnames(pedigree_data)[3] <- 'father_name'

q <- 1
x <- 1
y <- 1
z <- 1

for(i in pedigree_data)
{
pedigree_data [x, "child_name"]
test_child_name <- .Last.value
x <- x+1

pedigree_data [x, "mother_name"]
test_mother_name <- .Last.value
y <- y+1

pedigree_data [x, "father_name"]
test_father_name <- .Last.value
z <- z+1


for (i in genotype_data)
{
  genotype_data [q, test_child_name]
  child_score <- .Last.value

  genotype_data [q, test_mother_name]
  mother_score <- .Last.value

  genotype_data [q, test_father_name]
  father_score <- .Last.value

  q <- q + 1
  data$parent_score <- data$mother_score + data$father_score

  if(
    if (child_score > parent_score)
    {implausibility_count <- implausibility_count + 1}

    else if (mother_score & father_score = 2) & (child_score != 2))
    {implausibility_count <- implausibility_count + 1}

    else if (mother_score | father_score = 2) & (child_score = 0))
    {implausibility_count <- implausibility_count + 1}

    else if (mother_score | father_score = 2) & (child_score = 2))
    {implausibility_count <- implausibility_count + 1}
    )
  else (
    {implausibility_count <- implausibility_count + 0}
       )
}
}
