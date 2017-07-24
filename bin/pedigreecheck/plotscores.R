library(ggplot2)
library(sqldf)
newscores <- read.table("/home/klz26/sgn/bin/scoreswithstrictestfilter.txt", header = FALSE, check.names = FALSE, stringsAsFactors = FALSE)
potentialconflicts <- read.table("/home/klz26/potentialconflicts.txt", header= TRUE, check.names = FALSE, stringsAsFactors = FALSE, fill = TRUE)


newscores[8:12]<- NULL
colnames(newscores) [1] <- "Child"
colnames(newscores) [2] <- "Child ID"
colnames(newscores) [3] <- "Mother"
colnames(newscores)[4] <- "Mother ID"
colnames(newscores) [5] <- "Father"
colnames(newscores)[6] <-"Father ID"
colnames(newscores) [7] <- "Pedigree Conflict Score"
newscores[,4] <- (1 - newscores[,4])
newscores <- newscores[ , c("Accession", "Mother", "Father", "Conflict Score")]
newscores <- newscores[-c(1:5), ]

originalscores <- originalscores[order(originalscores[,'Accession']), ]
newscores <- newscores[order(newscores[,'Accession']),]

x= originalscores [,4]
y= newscores [,4]
labels =originalscores [,1] 
ggplot()+ggtitle("Comparison of R vs Perl Script")+labs(x="R Scores", y="Perl Scores")+ geom_text(aes(x=x,y=y,label =labels), size = 2.5)


hist(newscores$'Pedigree Conflict Score', main = "Distribution of Pedigree Conflict Scores", breaks = 20, 
     xlab = "Pedigree  Conflict Scores", col = '#663300', labels = TRUE)

