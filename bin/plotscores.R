library(ggplot2)
originalscores <- read.table("/home/klz26/sgn/bin/OriginalScores.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
newscores <- read.table("/home/klz26/sgn/bin/sinkwithupdate.txt", header= FALSE, check.names = FALSE, stringsAsFactors = FALSE)

originalscores [1] <- NULL
colnames(originalscores) [1] <- "Accession"
colnames(originalscores) [2] <- "Mother"
colnames(originalscores) [3] <- "Father"
colnames(originalscores) [4] <- "Conflict Score"
originalscores <- originalscores[ , c("Accession", "Mother", "Father", "Conflict Score")]
originalscores <- originalscores[-c(104), ] 

colnames(newscores) [1] <- "Accession"
newscores [2] <- NULL
colnames(newscores) [2] <- "Father"
newscores [3] <- NULL
colnames(newscores) [3] <- "Mother"
newscores [4] <- NULL
colnames(newscores) [4] <- "Conflict Score"
newscores[,4] <- (1 - newscores[,4])
newscores <- newscores[ , c("Accession", "Mother", "Father", "Conflict Score")]
newscores <- newscores[-c(1:5), ]

originalscores <- originalscores[order(originalscores[,'Accession']), ]
newscores <- newscores[order(newscores[,'Accession']),]

x= originalscores [,4]
y= newscores [,4]
labels =originalscores [,1] 
ggplot()+ggtitle("Comparison of R vs Perl Script")+labs(x="R Scores", y="Perl Scores")+ geom_text(aes(x=x,y=y,label =labels), size = 2.5)
