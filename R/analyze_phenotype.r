
# R CMD BATCH --no-save --no-restore '--args phenotype_file="blabla.txt" output_file="blalba.png" ' analyze_phenotype.r output.txt
library(plyr)
library(tidyr)
library(ggplot2)

args=(commandArgs(TRUE))

if(length(args)==0){
   print("No arguments supplied.")
   ##supply default values
   phenotype_file = 'phenotypes.txt'
   output_file = paste0(phenotype_file, ".png", sep="")
} else {
   for(i in 1:length(args)){
       eval(parse(text=args[[i]]))
   }
}

write(paste("phenotype file: ", phenotype_file), stderr())
write(paste("output_file: ", output_file), stderr())

errorfile = paste(phenotype_file, ".err", sep="");

phenodata = read.csv(phenotype_file,fill=TRUE, sep=",", header = T, stringsAsFactors = T, na.strings="NA")

blocks = unique(phenodata$blockNumber)
print(paste("blocks: ", blocks));
studyNames = unique(phenodata$studyName)
accessions = unique(phenodata$germplasmName)
datamatrix <- c()
datasetnames <- c()
trial_accessions <- c()
all_accessions = unique(phenodata$germplasmName)

datamatrix = matrix(nrow = length(all_accessions), ncol=length(studyNames)) # * length(blocks))
alltrialsdata <- c()
for (i in 1:(length(studyNames))) {

  trialdata <- phenodata[phenodata[,"studyName"]==studyNames[i], ] # & phenodata[,"blockNumber"]==n, ]
  print(studyNames[i])
  print(dim(trialdata))
  
  metadata <- c('studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'plotNumber')
 
  trialdata <- trialdata[, !(names(trialdata) %in% metadata)]
 
  print(data.frame(trialdata[1:5, ]))

  trialdata <- trialdata[, !(names(trialdata) %in% c('replicate', 'blockNumber'))]

  trialdata <- ddply(trialdata,
                     "germplasmName",
                     colwise(mean, na.rm=TRUE)
                     )
  trialdata <- data.frame(trialdata)
  print(dim(trialdata))
  print(data.frame(trialdata[1:5, ]))
  trialdata <- trialdata[complete.cases(trialdata), ]
  print(dim(trialdata))
  print(data.frame(trialdata[1:5, ]))
  message('trial name: ',  make.names(studyNames[i]))
  colnames(trialdata)[2]<- make.names(studyNames[i])
  print(trialdata)

  if( i == 1) {
    alltrialsdata <- trialdata
  } else {
    alltrialsdata <- merge(alltrialsdata, trialdata, by="germplasmName")
  }
}

names(alltrialsdata) <- make.names(names(alltrialsdata))
trialNames <- names(alltrialsdata)

longAllTrialsData <- gather(alltrialsdata, Trials, Trait,
                            Kasese.solgs.trial:trial2.NaCRRI,
                            factor_key=TRUE)
print(longAllTrialsData)
datamatrix <- data.matrix(alltrialsdata)


if (nrow(datamatrix)==0) { 
   write("No data was retrieved from the database for this combination of trials: ", file = errorfile);
}
if (ncol(datamatrix) < 2) { 
   write("No data. Try again", file = errorfile);
}

# correlation
#
panel.cor <- function(x, y, digits=2, cex.cor)
{
   usr <- par("usr"); on.exit(par(usr))
   par(usr = c(0, 1, 0, 1))
   r <- abs(cor(x, y, use ="na.or.complete"))
   txt <- format(c(r, 0.123456789), digits=digits)[1]
   test <- cor.test(x,y,use ="na.or.complete")
   Signif <- ifelse(round(test$p.value,3)<0.001,"p<0.001",paste("p=",round(test$p.value,3)))  
   text(0.5, 0.25, paste("r=",txt))
   text(.5, .75, Signif)
}

#pairs(data_test,lower.panel=panel.smooth,upper.panel=panel.cor)

#smooth

panel.smooth<-function (x, y, col = "black", bg = NA, pch = 18, cex = 0.8, col.smooth = "red", span = 2/3, iter = 3, ...) 
{
    points(x, y, pch = pch, col = col, bg = bg, cex = cex)
    ok <- is.finite(x) & is.finite(y)
    if (any(ok)) 
    	lines(stats::lowess(x[ok], y[ok], f = span, iter = iter), 
       	col = col.smooth, ...)
    }


#pairs(data,lower.panel=panel.smooth,upper.panel=panel.smooth)

#histo
panel.hist <- function(x, ...)
{
    usr <- par("usr"); on.exit(par(usr))
    par(usr = c(usr[1:2], 0, 1.5) )
    h <- hist(x, plot = TRUE)
    breaks <- h$breaks; nB <- length(breaks)
    y <- h$counts; y <- y/max(y)
    rect(breaks[-nB], 0, breaks[-1], y, col="red", ...)
}


scatterPlot <- function () {
  scatter <- ggplot(alltrialsdata, aes(x=Kasese.solgs.trial, y=trial2.NaCRRI)) +
                ggtitle("Scatter plot of trait values") +
                theme(plot.title = element_text(size=18,  face="bold", color="olivedrab4", margin = margin(40, 40, 40, 40)),
                      axis.title.x = element_text(size=14, face="bold", color="olivedrab4"),
                      axis.title.y = element_text(size=14, face="bold", color="olivedrab4"),
                      axis.text.x  = element_text(angle=90, vjust=0.5, size=10, color="olivedrab4"),
                      axis.text.y  = element_text(size=10, color="olivedrab4")) +
                geom_point(shape=1, color='DodgerBlue') +
                scale_x_continuous(breaks = round(seq(min(longAllTrialsData$Trait), max(longAllTrialsData$Trait), by = 2),1)) +
                scale_y_continuous(breaks = round(seq(min(longAllTrialsData$Trait), max(longAllTrialsData$Trait), by = 2),1)) +
                geom_smooth(method=lm, se=FALSE) 

  return(scatter)
  
}


freqPlot <- function () {

  averages <- ddply(longAllTrialsData,  "Trials", summarise, traitAverage = mean(Trait))
  
  freq <- ggplot(longAllTrialsData, aes(x=Trait, fill=Trials)) +
  xlab("Trait values") +
  ylab("Frequency") +
  ggtitle("Frequency Distribution") +
  theme(plot.title = element_text(size=18, face="bold", color="olivedrab4",  margin = margin(40, 40, 40, 40)),
        axis.title.x = element_text(size=14, face="bold", color="olivedrab4"),
        axis.title.y = element_text(size=14, face="bold", color="olivedrab4"),
        axis.text.x  = element_text(angle=90, size=10, color="olivedrab4"),
        axis.text.y  = element_text(size=10, color="olivedrab4"),
        legend.title=element_blank(),
        legend.text=element_text(size=12, color="olivedrab4"),
        legend.position="bottom") +         
  geom_histogram(binwidth=2, alpha=.5, position="identity") +
  scale_x_continuous(breaks = round(seq(min(longAllTrialsData$Trait), max(longAllTrialsData$Trait), by = 2),1)) +
  scale_fill_manual(values=c("ForestGreen", "DodgerBlue")) +
  geom_vline(data=averages,
             aes(xintercept=traitAverage,  colour=Trials),
             linetype="dashed", size=2)

  return(freq)
}



# Multiple plot function
#
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
# http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_(ggplot2)/

multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)

  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)

  numPlots = length(plots)

  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                    ncol = cols, nrow = ceiling(numPlots/cols))
  }

 if (numPlots==1) {
    print(plots[[1]])

  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

png(output_file, height=400, width=800)

scatter <- scatterPlot()
freq    <- freqPlot()

multiplot(scatter, freq, cols=2)

dev.off()


