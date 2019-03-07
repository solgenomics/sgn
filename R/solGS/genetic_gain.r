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
library(plotly)



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

print(head(trGebv))
print(head(slGebv))

boxplotData <- bind_rows(trGebv, slGebv)
boxplotData$pop <- as.factor(boxplotData$pop)
boxplotData$pop <- with(boxplotData, relevel(pop, "training"))

trMed <- median(trGebv[, 2])
slMed <- median(slGebv[, 2])
trMax <- max(trGebv[, 2])
slMax <- max(slGebv[, 2])
trMin <- min(trGebv[, 2])
slMin <- min(slGebv[, 2])

pop       <- 'pop'
training  <- 'training'
selection <- 'selection'

bp <- ggplot(boxplotData, aes_string(y=trait, x=pop, fill=pop)) +
    geom_boxplot(width=0.5) +
    geom_label(aes_string(x=training, y=trMed, label=trMed),
               fill='white', label.size=NA) +
    geom_label(aes_string(x=selection, y=slMed, label=slMed),
               fill='white', label.size=NA) +
    geom_label(aes_string(x=training, y=trMax, label=trMax),
               fill='white', label.size=NA) +
    geom_label(aes_string(x=selection, y=slMax, label=slMax),
               fill='white', label.size=NA) +
    geom_label(aes_string(x=training, y=trMin, label=trMin),
               fill='white', label.size=NA) +
    geom_label(aes_string(x=selection, y=slMin, label=slMin),
               fill='white', label.size=NA)



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
