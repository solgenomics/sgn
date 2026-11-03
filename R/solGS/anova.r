# Analytical replicate is the recorded design tag, never the field counter.
design_source <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) design_source <- frame$ofile
if (is.null(design_source)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    design_source <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) design_source <- invocation[file_index[1] + 1L]
  }
}
if (is.null(design_source) || is.na(design_source) || !nzchar(design_source)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(design_source)), "../design_replication.R"), local = TRUE)

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

traitsFile <- grep("traits", inputFiles, value = TRUE)

metadataFile <- grep("metadata", inputFiles, value = TRUE)

metaData <- scan(metadataFile, what="character")

designFactors <- c('germplasmName','studyYear', 'studyDesign', 'blockNumber', 'locationName', 'replicate')
dropCols <-  metaData[! metaData %in% designFactors]

phenoData <- read_analysis_phenotypes(phenoDataFile)
assert_genotype_name_identity(phenoData)
phenoData <- phenoData[,setdiff(names(phenoData),dropCols),drop=FALSE]


traits  <- scan(traitsFile,  what = "character")
traits  <- strsplit(traits, "\t")


#needs more work for multi traits anova
for (trait in traits) {
    
    message('trait: ', trait)
    anovaTableFiles     <- grep("anova_table",
                           outputFiles,
                           value = TRUE)

    anovaHtmlFile  <- grep("anova_table_html",
                           anovaTableFiles,
                           value = TRUE)

    anovaTxtFile   <- grep("anova_table_txt",
                           anovaTableFiles,
                           value = TRUE)

    modelSummFile <- grep("anova_model",
                          outputFiles,
                          value = TRUE)

    adjMeansFile  <- grep("adj_means",
                          outputFiles,
                          value = TRUE)

    diagnosticsFile  <- grep("anova_diagnostics",
                             outputFiles,
                             value = TRUE)

    errorFile  <- grep("anova_error",
                       outputFiles,
                       value = TRUE)

    anovaOut <- analysis_run_anova(phenoData, trait)
    if (is.character(anovaOut)) {
        cat(anovaOut, file=errorFile)
    } else if (is.null(anovaOut)) {
        
        cat('Error occurred fitting anova model to this trait data.
             Please check the trait data and design factors.',
            file=errorFile)
        
    } else if (class(anovaOut)[1] == 'lmerModLmerTest' ||
               class(anovaOut)[1] == 'merModLmerTest' || inherits(anovaOut,'lm')) {
    
        png(diagnosticsFile, 960, 480)
        par(mfrow=c(1,2))
        plot(fitted(anovaOut), resid(anovaOut),
             xlab="Fitted values",
             ylab="Residuals",
             main="Fitted values vs Residuals") 
        abline(0,0)
        qqnorm(resid(anovaOut))      
        dev.off()
 
        anovaHtmlTable <- analysis_anova_table(anovaOut,
                                    tableType="html",
                                    traitName=trait,
                                    out=anovaHtmlFile)

        anovaTxtTable <- analysis_anova_table(anovaOut,
                                    tableType="text",
                                    traitName=trait,
                                    out=anovaTxtFile)
        
  
        adjMeans   <- analysis_adjusted_means(traitName=trait, modelOut=anovaOut)
  
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
