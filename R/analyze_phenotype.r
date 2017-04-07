
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

phenodata = read.csv(phenotype_file,fill=TRUE, sep=",", header = TRUE, stringsAsFactors = T, na.strings="NA");

blocks = unique(phenodata$blockNumber)
print(paste("blocks: ", blocks));
studyNames = unique(phenodata$studyName)
accessions = unique(phenodata$germplasmName)
datamatrix <- c()
datasetnames <- c()
trial_accessions <- c()
all_accessions = unique(phenodata$germplasmName)

datamatrix = matrix(nrow = length(all_accessions), ncol=length(studyNames)) # * length(blocks))
wfAlltrialsdata <- c()
for (i in 1:(length(studyNames))) {

  trialdata <- phenodata[phenodata[,"studyName"]==studyNames[i], ] # & phenodata[,"blockNumber"]==n, ]
 
  metadata <- c('studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'plotNumber')
 
  trialdata <- trialdata[, !(names(trialdata) %in% metadata)]
 
  trialdata <- trialdata[, !(names(trialdata) %in% c('replicate', 'blockNumber'))]

  trialdata <- ddply(trialdata,
                     "germplasmName",
                     colwise(mean, na.rm=TRUE)
                     )
  
  trialdata <- data.frame(trialdata)

  trialdata <- trialdata[complete.cases(trialdata), ]

  colnames(trialdata)[2]<- make.names(studyNames[i])

  if( i == 1) {
    wfAllTrialsData <- trialdata
  } else {
    wfAllTrialsData <- merge(wfAllTrialsData, trialdata, by="germplasmName")
  }
}

#create a fake 4 trials dataset
#wfAllTrialsData <- merge(wfAllTrialsData, wfAllTrialsData, by="germplasmName")
 
names(wfAllTrialsData) <- make.names(names(wfAllTrialsData))

lfTrialsData <- function (wfTrialsData) {
 lfTrDa <- gather(wfTrialsData, Trials, Trait,
                        2:length(wfTrialsData),
                        factor_key=TRUE)
 
  return (lfTrDa)
}


datamatrix <- data.matrix(wfAllTrialsData)


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

scatterPlot <- function (wfTrialsData) {

  lfTrDa <-  lfTrialsData(wfTrialsData)

  scatter <- ggplot(wfTrialsData, aes_string(x=names(wfTrialsData)[2], y=names(wfTrialsData)[3])) +
                theme(plot.title = element_text(size=18,  face="bold", color="olivedrab4", margin = margin(40, 40, 40, 40)),
                      plot.margin = unit(c(0.75, 1, 0.75, 1), "cm"),
                      axis.title.x = element_text(size=14, face="bold", color="olivedrab4"),
                      axis.title.y = element_text(size=14, face="bold", color="olivedrab4"),
                      axis.text.x  = element_text(angle=90, vjust=0.5, size=10, color="olivedrab4"),
                      axis.text.y  = element_text(size=10, color="olivedrab4")) +
                geom_point(shape=1, color='DodgerBlue') +
                scale_x_continuous(breaks = round(seq(min(lfTrDa$Trait), max(lfTrDa$Trait), by = 2),1)) +
                scale_y_continuous(breaks = round(seq(min(lfTrDa$Trait), max(lfTrDa$Trait), by = 2),1)) +
                geom_smooth(method=lm, se=FALSE) 

 return(scatter)
  
}


freqPlot <- function (wfTrialsData) {
  
  lfTrDa <- lfTrialsData(wfTrialsData)

  averages <- ddply(lfTrDa,  "Trials", summarise, traitAverage = mean(Trait))
  
  freq <- ggplot(lfTrDa, aes(x=Trait, fill=Trials)) +
  xlab("Trait values") +
  ylab("Frequency") +
  theme(plot.title = element_text(size=18, face="bold", color="olivedrab4",  margin = margin(40, 40, 40, 40)),
        plot.margin = unit(c(0.75, 1, 0.75, 1), "cm"),
        axis.title.x = element_text(size=14, face="bold", color="olivedrab4"),
        axis.title.y = element_text(size=14, face="bold", color="olivedrab4"),
        axis.text.x  = element_text(angle=90, size=10, color="olivedrab4"),
        axis.text.y  = element_text(size=10, color="olivedrab4"),
        legend.title=element_blank(),
        legend.text=element_text(size=12, color="olivedrab4"),
        legend.position="bottom") +         
  geom_histogram(binwidth=2, alpha=.5, position="identity") +
  scale_x_continuous(breaks = round(seq(min(lfTrDa$Trait), max(lfTrDa$Trait), by = 2),1)) +
  scale_fill_manual(values=c("ForestGreen", "DodgerBlue")) +
  geom_vline(data=averages,
             aes(xintercept=traitAverage,  colour=Trials),
             linetype="dashed", size=2)

 return(freq)
}


# Multiple plot function: for how to use this function go here:
# http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_(ggplot2)/

multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)

  plots <- c(list(...), plotlist)

  numPlots = length(plots)

  if (is.null(layout)) {
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                    ncol = cols, nrow = ceiling(numPlots/cols))
  }

 if (numPlots==1) {
    print(plots[[1]])

  } else {
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    for (i in 1:numPlots) {
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}


getTrialsPairs <- function (wfAllTrialsData) {
  combiTrMx <- combn(names(wfAllTrialsData[, 2:length(names(wfAllTrialsData))]), 2)
  nPairs   <- dim(combiTrMx)[2]

  allPairs <- c()
  for (i in 1:nPairs) {
    pairs  <- combiTrMx[, i]
   message("pair  " , i, " ",  pairs )
    allPairs[i] <- list(i=pairs)
  }

 return (list("trialsPairs"= allPairs, "pairsCount"= nPairs))
}


prTr        <- getTrialsPairs(wfAllTrialsData)
trialsPairs <- prTr[["trialsPairs"]]
pairsCount  <- prTr[["pairsCount"]]

message("pairs count ", pairsCount)

createGraphNames <- function (pairsCount) {
  graphNames <- c()
  
  for (i in 1:pairsCount) {
    pf <- paste("freq", i, sep="")
    ps <- paste("scatter", i, sep="")
   
    graphNames[i] <- list(i=c(ps, pf))
  }

  return(graphNames)
}


png(output_file, height= pairsCount * 400, width=800)

graphNames <- createGraphNames(pairsCount)

for (i in 1:pairsCount) {
  pnames <- graphNames[[i]]
  message(pnames, "  ", pnames[1], " ", pnames[2])
  
  scatter <- scatterPlot(wfAllTrialsData[, c("germplasmName", trialsPairs[[i]])])
  freq <- freqPlot(wfAllTrialsData[, c("germplasmName", trialsPairs[[i]])])

  assign(pnames[1], scatter)
  assign(pnames[2], freq)

}

if (pairsCount == 1) {
  multiplot(scatter1, freq1, cols=2)  
} else if (pairsCount == 3) {
  multiplot(scatter1, freq1, scatter2, freq2, scatter3, freq3, cols=2)
} else if (pairsCount == 6) {  
  multiplot(scatter1, freq1, scatter2, freq2, scatter3, freq3, scatter4, freq4, scatter5, freq5, scatter6, freq6, cols=2)  
}

dev.off()


