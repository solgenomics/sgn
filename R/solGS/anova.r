 #SNOPSIS

 #runs ANOVA.
 
 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)


#library(dplyr)
library(data.table)
library(phenoAnalysis)
library(methods)


allArgs     <- commandArgs()

outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                   what = "character")

phenoDataFile <- grep("phenotype_data", inputFiles, value = TRUE)
message('pheno file: ', phenoDataFile)

traitsFile <- grep("traits", inputFiles, value = TRUE)
message('traits file: ', traitsFile)

metadataFile <- grep("metadata", inputFiles, value = TRUE)
message('metadata file: ', metadataFile)

metaData <- scan(metadataFile, what="character")

designFactors <- c('germplasmName','studyYear', 'studyDesign', 'blockNumber', 'locationName', 'replicate')
dropCols <-  metaData[! metaData %in% designFactors]

phenoData <- fread(phenoDataFile, sep="\t",
                   drop=dropCols,
                   na.strings=c("NA", "-", " ", ".", ".."))

phenoData <- data.frame(phenoData)

traits  <- scan(traitsFile,  what = "character")
traits  <- strsplit(traits, "\t")


#needs more work for multi traits anova
for (trait in traits) {
    
    message('trait: ', trait)
    anovaFiles     <- grep("anova_table",
                           outputFiles,
                           value = TRUE)

    message('anova file: ', anovaFiles)
    anovaHtmlFile  <- grep("html",
                           anovaFiles,
                           value = TRUE)

    message('anova html file: ', anovaHtmlFile)
    anovaTxtFile   <- grep("txt",
                           anovaFiles,
                           value = TRUE)

    message('anova txt file: ', anovaTxtFile)
    modelSummFile <- grep("anova_model",
                          outputFiles,
                          value = TRUE)

    message('model file: ', modelSummFile)
    adjMeansFile  <- grep("adj_means",
                          outputFiles,
                          value = TRUE)

    message('means file: ', adjMeansFile)


    diagnosticsFile  <- grep("anova_diagnostics",
                             outputFiles,
                             value = TRUE)

    errorFile  <- grep("anova_error",
                       outputFiles,
                       value = TRUE)

    anovaOut <- runAnova(phenoData, trait)
    
    if (class(anovaOut) == 'character') {
        cat(anovaOut, file=errorFile)
    } else if (is.null(anovaOut)) {
        
        cat('Error occured fitting anova model to this trait data.
             Please check the trait data and design factors.',
            file=errorFile)
        
    } else if (class(anovaOut)[1] == 'lmerModLmerTest' ||
               class(anovaOut)[1] == 'merModLmerTest') {
    
        png(diagnosticsFile, 960, 480)
        par(mfrow=c(1,2))
        plot(fitted(anovaOut), resid(anovaOut),
             xlab="Fitted values",
             ylab="Residuals",
             main="Fitted values vs Residuals") 
        abline(0,0)
        qqnorm(resid(anovaOut))      
        dev.off()
 
        anovaTable <- getAnovaTable(anovaOut,
                                    tableType="html",
                                    traitName=trait,
                                    out=anovaHtmlFile)
       
        anovaTable <- getAnovaTable(anovaOut,
                                    tableType="text",
                                    traitName=trait,
                                    out=anovaTxtFile)
        
  
        adjMeans   <- getAdjMeans(traitName=trait, modelOut=anovaOut)
  
        fwrite(adjMeans,
               file      = adjMeansFile,
               row.names = FALSE,
               sep       = "\t",
               quote     = FALSE,
               )

        sink(modelSummFile)
        print(anovaOut)
        sink()
    }
  
}


q(save = "no", runLast = FALSE)
