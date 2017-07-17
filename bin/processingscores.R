scores <- read.table ("/home/vagrant/sink.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE, fill = TRUE)
colnames(scores)[1] <- "Child Name"
colnames(scores)[2] <- "Child ID"
colnames(scores)[3] <- "Mother Name"
colnames(scores)[4] <- "Mother ID"
colnames(scores)[5] <- "Father Name"
colnames(scores)[6] <- "Father ID"
colnames(scores)[7] <- "Pedigree Conflict Score"
scores[8:12] <- NULL
histogram <- hist(scores$'Pedigree Conflict Score', main = "Distribution of Pedigree Conflict Scores", breaks = 20, 
     xlab = "Pedigree  Conflict Scores", col = '#663300', labels = TRUE)
  