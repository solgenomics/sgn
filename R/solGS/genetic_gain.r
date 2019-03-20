 #SNOPSIS

 #visualizes genetic gain using boxplot.

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(data.table)
#library(phenoAnalysis)
library(dplyr)
library(methods)
library(ggplot2)
#library(plotly)



allArgs <- commandArgs()

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                   what = "character")

trGebvFiles <- grep("training", inputFiles, value = TRUE)

message('training file: ', trGebvFiles)

slGebvFiles <- grep("selection", inputFiles, value = TRUE)

message('selection file: ', slGebvFiles)

boxplotFile <-  grep("genetic_gain_plot", outputFiles, value = TRUE)
message('boxplot file: ', boxplotFile)

plotDataFile <-  grep("genetic_gain_data", outputFiles, value = TRUE)
message('boxplot file: ', plotDataFile)

trGebv   <- c()
gebvsCol <- 'GEBVs'

for (trGebvFile in trGebvFiles) {
    gebv <- data.frame(fread(trGebvFile))
    trait <- names(gebv)[2]
    colnames(gebv)[2] <- gebvsCol
    gebv$trait <- trait
    trGebv <- bind_rows(trGebv, gebv)   
}

trGebv$pop <- 'training'
slGebv <- c()

for (slGebvFile in slGebvFiles) { 
    gebv <- data.frame(fread(slGebvFile))
    trait <- names(gebv)[2]
    colnames(gebv)[2] <- gebvsCol
    gebv$trait <- trait
    slGebv <- bind_rows(slGebv, gebv)   
}

slGebv$pop <- 'selection'

boxplotData <- bind_rows(trGebv, slGebv)
boxplotData$pop <- as.factor(boxplotData$pop)
boxplotData$trait <- as.factor(boxplotData$trait)

boxplotData$pop <- with(boxplotData, relevel(pop, "training"))

## pop       <- 'pop'
## training  <- 'training'
## selection <- 'selection'
## trait     <- 'trait'
## Gebvs     <- 'GEBVs'

bp <- ggplot(boxplotData,
             aes(y=GEBVs, x=pop, fill=pop)) +
             geom_boxplot(width=0.4) +
             stat_summary(geom="text", fun.y=quantile, size=5,
             aes(label=sprintf("%1.3f", ..y..), color=pop),
             position=position_nudge(x=0.35)) +
             theme_bw() +
             facet_wrap(~trait, ncol=2, scales="free") +
             theme(legend.position="none",
               axis.text=element_text(color='blue', size=12,  face='bold'),
               axis.title.y=element_text(color='blue'),
               axis.title.x=element_blank(),
               strip.text.x=element_text(color='blue', face='bold'))

wid <- 480 * if(length(trGebvFiles) > 1) 2 else 1;

png(boxplotFile, width=wid)
bp
dev.off()

if (length(plotDataFile) != 0 ) {
    fwrite(boxplotData,
       file      = plotDataFile,
       sep       = "\t",
       row.names = FALSE,
       quote     = FALSE,
       )

}

q(save = "no", runLast = FALSE)
