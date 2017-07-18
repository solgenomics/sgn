scores <- read.table ("/home/vagrant/sink.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE, fill = TRUE)
fathers<- read.table ("/home/vagrant/cxgn/sgn/bin/sinkfather.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE, fill = TRUE)
colnames(scores)[1] <- "Child Name"
colnames(scores)[2] <- "Child ID"
colnames(scores)[3] <- "Mother Name"
colnames(scores)[4] <- "Mother ID"
colnames(scores)[5] <- "Father Name"
colnames(scores)[6] <- "Father ID"
colnames(scores)[7] <- "Pedigree Conflict Score"
colnames(fathers)[3] <- "Father ID"
scores[5] <- fathers[2]
scores[6] <- fathers[3]
fathers <- fathers[-c(1), ] 

fathers[4] <- NULL
scores[8:12] <- NULL

scores <- scores[order(scores[,'Child Name']), ]
fathers <- fathers[order(fathers[,'Child']),]

histogram <- hist(scores$'Pedigree Conflict Score', main = "Distribution of Pedigree Conflict Scores", breaks = 20, 
     xlab = "Pedigree  Conflict Scores", col = '#663300', labels = TRUE)
  