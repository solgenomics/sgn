


##SNOPSIS

##A banch of r and r/qtl commands for reading input data,
##running qtl analysis, and writing output data. Input data are feed to R
##from and output data from R feed to a perl script called
##cgi-bin/phenome/population_indls.
##QTL mapping visualization is done by the perl script mentioned above.
## r/qtl has functions for data visualization but the perl script
## allows more control for publishing on the browser,
##cross-referencing to other SGN datasets and CONSISTENT formatting/appearance


##AUTHOR
## Isaak Y Tecle (iyt2@cornell.edu)



options(echo = FALSE)

library(qtl)

allargs<-commandArgs()

#wd<-setwd("/data/prod/tmp/r_qtl/cache") #sets the working directory
#wd<-setwd("/data/local/cxgn/core/sgn/documents/tempfiles/temp_images") #sets the working directory


print(allargs)
#files<-grep("/data/", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)
#print(files)
#infile<-unlist(strsplit(infile, "="))
#print(infile)
infile <- grep("infile_list", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)
print(infile)
#outfile<-grep("-outfile", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)
#print(outfile)
#outfile<-unlist(strsplit(outfile, "="))
#print(outfile)
outfile<-grep("outfile_list", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)
print(outfile)

## #setting the current working directory
## cwdarg<-grep("-dir", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)
##   print(cwdarg)
## cwd<-unlist(strsplit(cwdarg, "="))
## cwd<-cwd[2]
## print(cwd)
## cwd<-setwd(cwd)
## print(cwd)

###outout files to be cached
## cachedfiles<-grep("-cached_output_files", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)
##   print(cachedfiles)
## print("cached qtl file..")
## cachedqtl<-cachedfiles[1]
## cachedqtl<-unlist(strsplit(cachedqtl, "="))
## cachedqtl<-cachedqtl[2]
## print(cachedqtl)

## print("cached markers file...")
## cachedmarkers<-cachedfiles[1]
## cachedmarkers<-unlist(strsplit(cachedmarkers, "="))
## cachedmarkers<-cachedmarkers[2]
## print(cachedmarkers)


#########
infile<-scan(file=infile,  what="character")#container for the ff

cvtermfile<-infile[1]#file that contains the cvtername
print(cvtermfile)
popdata<-infile[2]#population dataset identifier
#cvtermdata<-infile[3]#variable to store qtl data for a cvterm in pop
genodata<-infile[3] #file name for genotype dataset
phenodata<-infile[4] #file name for phenotype dataset
permufile<-infile[5]
print("printing permu filename")
print(permufile)
print(popdata)
popid<-popdata
print(popid)
#print(cvtermdata)



popdata<- read.cross("csvs", genfile=genodata, phefile=phenodata, na.strings=c("NA"), genotypes=c("1", "2", "3", "4", "5"), estimate.map=TRUE, convertXdata=TRUE)
#popdata<-jittermap(popdata, amount=10e-6)
popdata<-calc.genoprob(popdata, step=10, error.prob=0.05)#calculates the genotype probablity at every 5 cM
print(cvtermfile)
cvterm<-scan(file=cvtermfile, what="character") #reads the cvterm
print(cvterm)
cv<-find.pheno(popdata, cvterm)#returns the col no. of the cvterm
print(cv)

print("printing permu file")
permuvalues<-scan(file=permufile, what="character")
print("printing permu values")
print(permuvalues)
print("done printing permu values")

#if (permuvalues == " ") {
  #do nothing
#}
print("permu values 1 and 2")
permuvalue1<-permuvalues[1]
permuvalue2<-permuvalues[2]
print(permuvalue1)
print(permuvalue2)
if ((is.logical(permuvalue1) == FALSE)) {
  popdataperm<-scanone(popdata, pheno.col=cv, n.perm=1000, method="em")
  permu<-summary(popdataperm, alpha=c(0.05))
  print(permu)  #do nothing
}


#else {
#  popdataperm<-scanone(popdata, pheno.col=cv, n.perm=1000, method="em")
#  permu<-summary(popdataperm, alpha=c(0.05))
#  print(permu) 
#}
#
chrlist<-c("chr1")

for (no in 2:12) {
  chr<-paste("chr", no, sep="")
  chrlist<-append(chrlist, chr)
}

chrdata<-paste(cvterm, popid, "chr1", sep="_")
#print(chrdata)
chrtest<-c("chr1")
for (ch in chrlist) {
  if (ch=="chr1"){
    chrdata<-paste(cvterm, popid, ch, sep="_");
  }
  
  else {
    n<-paste(cvterm, popid, ch, sep="_");
    chrdata<-append(chrdata, n)
    
  }
} 
#chrfile<-scan(file="../../documents/tempfiles/temp_images/file_chr_in.txt",  what="character")#container for the ff
#chrfile
print(chrdata)
chrno<-1

datasummary<-c()
peakmarkers<-c()

for (i in chrdata){
 # print(chrno)
 # print(i);
  
  filedata<-paste(cvterm, popid, chrno, sep="_");
   # print(filedata)
   filedata<-paste(filedata,"txt", sep=".");
    #print(filedata)
  
  i<-scanone(popdata, chr=chrno, pheno.col=cv)
  #print(i)
  position<-max(i, chr=chrno)
  print(position)
  
  #marpos<-find.markerpos(popdata, "TG59")
  #print(marpos)
  p<-position[2]
  p<-p[1, ]
  peakmarker<-find.flanking(popdata, chr=chrno, pos=p)
  
  if (chrno==1) { 
  datasummary<-i
  peakmarkers<-peakmarker
 
  #print(datasummary)
}
#  print(i)
  if (chrno > 1 ) {
    datasummary<-rbind(datasummary, i)
    peakmarkers<-rbind(peakmarkers, peakmarker)
    #print(datasummary)
    
  }

chrno<-chrno + 1;
 # print(chrno)

}

outfiles<-scan(file=outfile,  what="character")
qtlfile<-outfiles[1]
peakfile<-outfiles[2]

## cachedqtlfile<-outfiles[3]
## print("cached qtl file...")
## print(cachedqtlfile)
## cachedmarkersfile<-outfiles[4]
## print("cached markers file...")
## print(cachedmarkersfile)

print(qtlfile)
print(datasummary)
print(peakfile)
print(peakmarkers)

write.table(datasummary, file=qtlfile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)
#write.table(datasummary, file=cachedqtlfile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)
write.table(peakmarkers, file=peakfile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)
#write.table(peakmarkers, file=cachedmarkersfile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)

if ((is.logical(permuvalue1) == FALSE)) {
   write.table(permu, file=permufile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)#do nothing
}
#else   {
#    write.table(permu, file=permufile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)
#  } 
#figure<-paste(qtlfile, "png", sep=".")
#figure
#plot_file<-paste("../../documents/tempfiles/temp_images/", figure, sep="")
#plot_file

#png(file=figure, width = 520, height = 520, pointsize = 12, bg="white")
#mplots<-par(mfrow=c(4,3))
#for (i in chrfile) {
#plot(datasummary)
#plot(cvtermdata1); plot(cvtermdata2); plot(cvtermdata3); plot(cvtermdata4); plot(cvtermdata5); plot(cvtermdata6); plot(cvtermdata7); plot(cvtermdata8); plot(cvtermdata9); plot(cvtermdata10); plot(cvtermdata11); plot(cvtermdata12);

#par(mplots)
#dev.off()
#}

q(runLast = FALSE)
