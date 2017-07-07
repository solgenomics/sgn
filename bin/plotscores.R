originalscores <- read.table("/home/klz26/sgn/bin/OriginalScores.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
newscores <- read.table("/home/klz26/sgn/bin/sinkonlyscores.txt", header= FALSE, check.names = FALSE, stringsAsFactors = FALSE)
newscores["100"] <- (1 - newscores)

OGvector <- as.vector(originalscores[,5])
newvector <- as.vector(newscores[,2])


# create plot!

x= OGvector #og
y= newvector [1:122] #new all same length and sorted
labels =originalscores [,2] 
ggplot()+ggtitle("Comparison of R vs Perl Script")+labs(x="Original Scores",
                                               y="New Scores")+geom_text(aes(x=x,y=y,label =labels), size = 2.5)
