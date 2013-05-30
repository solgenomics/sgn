#a script for calculating weighted genomic
#estimated breeding values (GEBVs) mean, across
#selected traits, and ranking genotypes accordingly

options(echo = FALSE)

library(stats)

allArgs <- commandArgs()

inFile <- grep("input_rank_genotypes",
               allArgs,
               ignore.case = TRUE,
               perl = TRUE,
               value = TRUE
               )

inputFiles <- scan(inFile,
                   what = "character"
                   )

relWeightsFile <- grep("rel_weights",
                       inputFiles,
                       ignore.case = TRUE,
                       perl = TRUE,
                       value = TRUE
                       )

outFile <- grep("output_rank_genotypes",
                allArgs,
                ignore.case = TRUE,
                perl = TRUE,
                value = TRUE
                )

outputFiles <- scan(outFile,
                    what = "character"
                    )

traitsFiles <- grep("gebv_files_of_traits",
                    inputFiles,
                    ignore.case = TRUE,
                    perl = TRUE,
                    value = TRUE
                    )

rankedGenotypesFile <- grep("ranked_genotypes",
                            outputFiles,
                            ignore.case = TRUE,
                            perl = TRUE,
                            value = TRUE
                            )

genotypesMeanGebvFile <- grep("genotypes_mean_gebv",
                              outputFiles,
                              ignore.case = TRUE,
                              perl = TRUE,
                              value = TRUE
                              )

inTraitFiles <- scan(traitsFiles,
                     what = "character"
                     )

traitFilesList <- strsplit(inTraitFiles, "\t");
traitsTotal    <- length(traitFilesList)

if (traitsTotal == 0)
  stop("There are no traits with GEBV data.")
if (length(relWeightsFile) == 0)
  stop("There is no file with relative weights of traits.")


relWeights <- read.table(relWeightsFile,
                         header = TRUE,
                         row.names = 1,
                         sep = "\t",
                         dec = "."
                         )

combinedRelGebvs <- c()

for (i in 1:traitsTotal)
  {
    traitFile <- traitFilesList[[i]]
    traitGEBV <- read.table(traitFile,
                            header = TRUE,
                            row.names = 1,
                            sep = "\t",
                            dec = "."
                            )

  
    traitGEBV <- traitGEBV[order(rownames(traitGEBV)),,drop=FALSE]
   
    trait <- colnames(traitGEBV)
    relWeight <- relWeights[trait, ]

    if(relWeight != 0)
      {
        weightedTraitGEBV <- apply(traitGEBV, 1,
                                   function(x) x*relWeight
                                   )
        
        combinedRelGebvs  <- merge(combinedRelGebvs, weightedTraitGEBV,
                                   by = 0,
                                   all = TRUE                     
                                   )

        rownames(combinedRelGebvs) <- combinedRelGebvs[, 1]
        combinedRelGebvs[, 1] <- NULL
      }
  }

combinedRelGebvs$mean <- apply(combinedRelGebvs, 1, mean)
combinedRelGebvs <- combinedRelGebvs[ with(combinedRelGebvs,
                                           order(-combinedRelGebvs$mean)
                                           ),
                                     ]

combinedRelGebvs <- round(combinedRelGebvs,
                          digits = 2
                          )

genotypesMeanGebv <-c()
if (is.null(combinedRelGebvs) == FALSE)
  {
    genotypesMeanGebv <- subset(combinedRelGebvs,
                                select = 'mean'
                                )
  }

if (length(rankedGenotypesFile) != 0)
  {
    if(is.null(combinedRelGebvs) == FALSE)
      {
        write.table(combinedRelGebvs,
                    file = rankedGenotypesFile,
                    sep = "\t",
                    col.names = NA,
                    quote = FALSE,
                    append = FALSE
                    )
      }
  }

if (length(genotypesMeanGebvFile) != 0)
  {
    if(is.null(genotypesMeanGebv) == FALSE)
      {
        write.table(genotypesMeanGebv,
                    file = genotypesMeanGebvFile,
                    sep = "\t",
                    col.names = NA,
                    quote = FALSE,
                    append = FALSE
                    )
      }
  }

q(save = "no", runLast = FALSE)
