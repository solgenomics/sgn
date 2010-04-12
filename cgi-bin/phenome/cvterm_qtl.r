
##SNOPSIS

##A banch of r and r/qtl commands for reading input data,
##running qtl analysis, and writing output data. Input data are feed to R
##from and output data from R feed to a perl script called
##../phenome/population_indls.
##QTL mapping visualization is done by the perl script mentioned above.
## r/qtl has functions for data visualization but the perl script
## allows more control for publishing on the browser,
##cross-referencing to other SGN datasets and CONSISTENT formatting/appearance


##AUTHOR
## Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(qtl)

allargs<-commandArgs()
warning()

infile <- grep("infile_list", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)

outfile<-grep("outfile_list", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)

statfile<-grep("stat", allargs, ignore.case=TRUE, perl=TRUE, value=TRUE)


##### stat files
statfiles<-scan(statfile, what="character")
#print(statfiles)

###### QTL mapping method ############
qtlmethodfile<-grep("stat_qtl_method", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE)
qtlmethod<-scan(qtlmethodfile, what="character", sep="\n")
#print(qtlmethod)
if (qtlmethod == "Maximum Likelihood") {
  qtlmethod<-c("em")
  #print(qtlmethod)

} else

if (qtlmethod == "Haley-knott Regression") {
  qtlmethod<-c("hk")

} else

if (qtlmethod == "Multiple Imputation") {
  qtlmethod<-c("imp")

}

###### QTL model ############
qtlmodelfile<-grep("stat_qtl_model", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE)
#print(qtlmodelfile)
qtlmodel<-scan(qtlmodelfile, what="character", sep="\n")
#print(qtlmodel)
if (qtlmodel == "Single-QTL Scan") {
  qtlmodel<-c("scanone")

} else
if  (qtlmodel == "Two-QTL Scan") {
  qtlmodel<-c("scantwo")
}

###### permutation############
userpermufile<-grep("stat_permu_test", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE)
#print(userpermufile)
userpermuvalue<-scan(userpermufile, what="numeric", dec = ".", sep="\n")
#print(userpermuvalue)
if (userpermuvalue == "None") {
  userpermuvalue<-c(0)
}
userpermuvalue<-as.numeric(userpermuvalue)

#####for test only
#userpermuvalue<-c(0)

######genome step size############
stepsizefile<-grep("stat_step_size", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE)
stepsize<-scan(stepsizefile, what="numeric", dec = ".", sep="\n")
stepsize<-as.numeric(stepsize)


######genotype calculation method############
genoprobmethodfile<-grep("stat_prob_method", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE)
genoprobmethod<-scan(genoprobmethodfile, what="character", dec = ".", sep="\n")


########No. of draws for sim.geno method###########
drawsnofile<-c()
if (is.logical(grep("stat_no_draws", statfiles))==TRUE) {
  drawsnofile<-(grep("stat_no_drwas", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE))
}
    
if (is.logical(drawsnofile) ==TRUE) {
  drawsno<-scan(drawsnofile, what="numeric", dec = ".", sep="\n")
  drawsno<-as.numeric(drawsno)
}
########significance level for genotype probablity calculation###########
genoproblevelfile<-grep("stat_prob_level", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE)
genoproblevel<-scan(genoproblevelfile, what="numeric", dec = ".", sep="\n")
genoproblevel<-as.numeric(genoproblevel)


########significance level for permutation test###########
permuproblevelfile<-grep("stat_permu_level", statfiles, ignore.case=TRUE, fixed = FALSE, value=TRUE)
permuproblevel<-scan(permuproblevelfile, what="numeric", dec = ".", sep="\n")
permuproblevel<-as.numeric(permuproblevel)


#########
infile<-scan(file=infile,  what="character")#container for the ff

cvtermfile<-infile[1]#file that contains the cvtername
popid<-infile[2]#population dataset identifier
genodata<-infile[3] #file name for genotype dataset
phenodata<-infile[4] #file name for phenotype dataset
permufile<-infile[5]
crossfile<-infile[6]

print(crossfile)
cross<-scan(crossfile, what="character", sep="\n")
#print(cross)

popdata<-c()
if (cross == "f2") {
  popdata<- read.cross("csvs", genfile=genodata, phefile=phenodata, na.strings=c("NA"), genotypes=c("1", "2", "3", "4", "5"), estimate.map=TRUE, convertXdata=TRUE)
  popdata<-jittermap(popdata)
} else
if (cross == "bc") {
  popdata<- read.cross("csvs", genfile=genodata, phefile=phenodata, na.strings=c("NA"), genotypes=c("1", "2"), estimate.map=TRUE, convertXdata=TRUE)
  popdata<-jittermap(popdata)
}  



if (genoprobmethod == "Calculate") {
  popdata<-calc.genoprob(popdata, step=stepsize, error.prob=genoproblevel)
  #calculates the qtl genotype probablity at the specififed step size and probability level
} else
if (genoprobmethod == "Simulate") {
  popdata<-sim.genoprob(popdata, n.draws= drawsno, step=stepsize, error.prob=genoproblevel, stepwidth="fixed")
  #calculates the qtl genotype probablity at the specififed step size
}



cvterm<-scan(file=cvtermfile, what="character") #reads the cvterm
cv<-find.pheno(popdata, cvterm)#returns the col no. of the cvterm


permuvalues<-scan(file=permufile, what="character")

permuvalue1<-permuvalues[1]
permuvalue2<-permuvalues[2]
if ((is.logical(permuvalue1) == FALSE)) {
  if (qtlmodel == "scanone") {
    if (userpermuvalue == 0 ) {
      popdataperm<-scanone(popdata, pheno.col=cv, model="normal",  method=qtlmethod)
      #permu<-summary(popdataperm, alpha=c(0.05))
    } else
    if (userpermuvalue != 0) {
      popdataperm<-scanone(popdata, pheno.col=cv, model="normal", n.perm = userpermuvalue, method=qtlmethod)
      permu<-summary(popdataperm, alpha=permuproblevel)
      #print(permu)
    }
  }else
  if (qtlmodel == "scantwo") {
    if (userpermuvalue == 0 ) {
      popdataperm<-scantwo(popdata, pheno.col=cv, model="normal", method=qtlmethod)
      #permu<-summary(popdataperm)
    } else
    if (userpermuvalue != 0) {
      popdataperm<-scantwo(popdata, pheno.col=cv, model="normal", n.perm = userpermuvalue, method=qtlmethod)
      permu<-summary(popdataperm, alpha=permuproblevel)
      #print(permu) 
    
    } 
  }
}


chrlist<-c("chr1")

for (no in 2:12) {
  chr<-paste("chr", no, sep="")
  chrlist<-append(chrlist, chr)
}

chrdata<-paste(cvterm, popid, "chr1", sep="_")
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

chrno<-1

datasummary<-c()
confidenceints<-c()


for (i in chrdata){
 
  
  filedata<-paste(cvterm, popid, chrno, sep="_");
  filedata<-paste(filedata,"txt", sep=".");
  
  i<-scanone(popdata, chr=chrno, pheno.col=cv)
  position<-max(i, chr=chrno)
  
  p<-position[2]
  p<-p[1, ]
  peakmarker<-find.marker(popdata, chr=chrno, pos=p)  
  confidenceint<-bayesint(i, chr=chrno, prob=0.95, expandtomarkers=TRUE)
  confidenceint<-rownames(confidenceint)
  confidenceint<-c(chrno, confidenceint)
  if (chrno==1) { 
    datasummary<-i
    confidenceints<-confidenceint
}
  if (chrno > 1 ) {
    datasummary<-rbind(datasummary, i)
    confidenceints<-rbind(confidenceints, confidenceint)   
  }

chrno<-chrno + 1;

}
#print("cis")
#print(confidenceints)
#print("data summary")
#print(datasummary)

outfiles<-scan(file=outfile,  what="character")
qtlfile<-outfiles[1]
confidenceintfile<-outfiles[2]

write.table(datasummary, file=qtlfile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)
write.table(confidenceints, file=confidenceintfile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)

if (userpermuvalue != 0) {
  if ((is.logical(permuvalue1) == FALSE)) {
    write.table(permu, file=permufile, sep="\t", col.names=NA, quote=FALSE, append=FALSE)
  }
}


q(runLast = FALSE)
