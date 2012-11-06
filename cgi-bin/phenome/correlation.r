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
                                        
allargs<-commandArgs()

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

print(c("correlation table file:", cortable))

heatmap<-grep("heatmap",
               allargs,
               ignore.case=TRUE,
               perl=TRUE,
               value=TRUE
               )

print(c("heatmap file:", heatmap))

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


pvalues<-as.matrix(allcordata)


pvalues<-round(pvalues,
               digits=2
               )


#rounding correlation coeficients into 2 decimal places
coefficients<-round(coefficients,
                    digits=2
                   )

allcordata<-round(allcordata,
                  digits=2
                  )

#remove rows and columns that are all "NA"
if ( apply(coefficients,
           1,
           function(x)any(is.na(x))
           )
    ||
    apply(coefficients,
          2,
          function(x)any(is.na(x))
          )
    )
  {
                                                            
    coefficients<-coefficients[-which(apply(coefficients,
                                            1,
                                            function(x)all(is.na(x)))
                                      ),
                               -which(apply(coefficients,
                                            2,
                                            function(x)all(is.na(x)))
                                      )
                               ]
  }

print("correlation coeffients:")
print(coefficients)

pvalues[upper.tri(pvalues)]<-NA
coefficients[upper.tri(coefficients)]<-NA

png(file=heatmap,
    height=600,
    width=600,
    bg="transparent"
    )


heatmap.2(coefficients,
          Rowv=FALSE,
          Colv=FALSE,
          dendrogram="none",
          na.rm=TRUE,
          col =  rev(colorRampPalette(brewer.pal(10,"Spectral"))(128)),
          trace="none",                  
          ColSideColors,
          RowSideColors,
          keysize = 1,
          density.info="none",
          lmat=rbind( c(0,3), c(2,1), c(0,4)),
          lhei=c(0.25, 4, 0.75),
          lwid=c(0.25, 4),
          cexRow = 1.25,
          cexCol = 1.25,
          margins = c(10, 6)
          )
 
dev.off()

write.table(coefficients,
      file=cortable,
      col.names=TRUE,
      row.names=TRUE,
      quote=FALSE,
      dec="."
      )

q(save = "no", runLast = FALSE)
