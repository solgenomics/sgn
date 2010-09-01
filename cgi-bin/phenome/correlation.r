                                        #SNOPSIS

                                        #commands for running correlation analyis,
                                        #and generating heatmap and the correlation
                                        #coefficients and their p-values


                                        #AUTHOR
                                        # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(gplots)
library(RColorBrewer)
library(ltm)
                                        #library(reshape)

allargs<-commandArgs()
warning()
print(allargs)


phenodata<-grep("phenodata",
               allargs,
               ignore.case=TRUE,
               perl=TRUE,
               value=TRUE
               )
cortable<-grep("corre_table",
               allargs,
               ignore.case=TRUE,
               perl=TRUE,
               value=TRUE
               )
heatmap<-grep("heatmap",
               allargs,
               ignore.case=TRUE,
               perl=TRUE,
               value=TRUE
               )
print(phenodata)
print(cortable)
print(heatmap)

                                        #reading phenotype data into an R object

phenodata<-read.csv(phenodata,
                    header=TRUE,
                    dec=".",
                    sep=",",
                    na.strings=c("NA", "-")
                    )

phenodata$ID=NULL


                                     #running Pearson correlation analysis
coefpvalues<-rcor.test(phenodata,
                       method="pearson",
                       use="pairwise"
                       )

coefficients<-coefpvalues$cor.mat
allcordata<-coefpvalues$cor.mat
allcordata[lower.tri(allcordata)]<-coefpvalues$p.values[, 3]
diag(allcordata)<-1.00

#print(coefficients)

pvalues<-as.matrix(allcordata)

## pvalues<-pvalues[-which(apply(pvalues,
##                                    1,
##                                    function(x)all(is.na(x)))
##                              )

##                      ]
pvalues<-round(pvalues,
               digits=2
               )

print(pvalues)
pvalues[upper.tri(pvalues)]<-NA
print(pvalues)
                                        #rounding correlation coeficients into 2 decimal places


coefficients<-round(coefficients,
                    digits=2
                   )

allcordata<-round(allcordata,
                  digits=2
                  )
                                        #remove rows and columns that are all "NA"
coefficients<-coefficients[-which(apply(coefficients,
                                   1,
                                   function(x)all(is.na(x)))
                             ),
                           -which(apply(coefficients,
                                   2,
                                   function(x)all(is.na(x)))
                             )
                     ]


coefficients[upper.tri(coefficients)]<-NA
#print(coefficients)

png(file=heatmap,
    height=800,
    width=800,
    bg="transparent"
    )

heatmap.2(coefficients,
          Rowv=NA,
          Colv=NA,
          na.rm=TRUE,
          col =  rev(colorRampPalette(brewer.pal(10,"RdBu"))(128)),
          trace="none",
          #cellnote=coefficients,
          #notecol="cyan",
          margins = c(7, 7),
          ColSideColors,
          RowSideColors,
          keysize = 1,
          density.info=c("none"),
          lmat=rbind(c(0, 3), c(2,1), c(0,4)),
          lhei=c(1.5, 8, 2 )         
          )

dev.off()

write.table(allcordata,
      file=cortable,
      col.names=TRUE,
      row.names=TRUE,
      dec="."
      )



q(runLast = FALSE)
