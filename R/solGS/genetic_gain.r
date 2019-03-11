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

trGebvFile <- grep("training", inputFiles, value = TRUE)
message('training file: ', trGebvFile)

slGebvFile <- grep("selection", inputFiles, value = TRUE)
message('selection file: ', slGebvFile)

boxplotFile <-  grep("genetic_gain_plot", outputFiles, value = TRUE)
message('boxplot file: ', boxplotFile)

plotDataFile <-  grep("genetic_gain_data", outputFiles, value = TRUE)
message('boxplot file: ', plotDataFile)

trGebv <- data.frame(fread(trGebvFile))
slGebv <- data.frame(fread(slGebvFile))

trait <- names(trGebv)[2]
message('trait gebv:  ', trait)

trGebv$pop <- 'training'
slGebv$pop <- 'selection'

boxplotData <- bind_rows(trGebv, slGebv)
boxplotData$pop <- as.factor(boxplotData$pop)
boxplotData$pop <- with(boxplotData, relevel(pop, "training"))

pop       <- 'pop'
training  <- 'training'
selection <- 'selection'

bp <- ggplot(boxplotData,
             aes_string(y=trait, x=pop, fill=pop)) +
     geom_boxplot(width=0.4) +
     stat_summary(geom="text", fun.y=quantile,
     aes(label=sprintf("%1.3f", ..y..), color=pop),
     position=position_nudge(x=0.35), size=5) +                      
     theme_bw()  +
         theme(legend.position="none",
               axis.text=element_text(color='blue', size=12),
               axis.title.y=element_text(color='blue'),
               axis.title.x=element_blank())

png(boxplotFile)
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
