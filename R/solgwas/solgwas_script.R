#install.packages("rrBLUP")
#install.packages("corrplot")
setwd("/home/vagrant/cxgn/sgn/")

########################################
##### Read data from temp files #####
########################################
args = commandArgs(trailingOnly = TRUE)

# temporarily hard-coding the PC and Kinship flags
include_kinship = 0
include_pc = 0


pheno <- read.table(args[1], sep = "\t", header = TRUE)
colnames(pheno)

geno <- read.table(args[2], sep="\t", row.names = NULL, header = TRUE)
study_trait <- args[3]
study_trait
figure1_file_name <- args[4]
figure2_file_name <- args[5]
figure3_file_name <- args[6]
figure4_file_name <- args[7]
print("temp file name:")
figure1_file_name

pheno[1:5,1:21]
# Note: still need to test how well this pmatch deals with other trickier cases
pheno_vector <- pheno[,pmatch(study_trait, names(pheno))]
pheno_vector[1:5]
# Make a new phenotype table, including only the phenotype selected:
pheno_mod <- pheno[,1:17]
pheno_mod <- cbind(pheno_mod, pheno_vector)
pheno_vector[1:10]
pheno_mod[1:5,1:18]
pheno[1:5,1:21]


### Note this is currently set for column 18, because the above code makes a new table including
### only the data for the trait selected....
setwd("/home/vagrant/cxgn/sgn/")
png(figure1_file_name)
study_trait_read <- gsub(".", " ", study_trait, fixed=TRUE)
hist(pheno_mod[,18], col="black",xlab=study_trait_read,ylab="Frequency",
     border="white",breaks=10,main="Phenotype Histogram (Unfiltered)")
dev.off()
write.table(pheno_mod, "pheno_mod_temp_file.csv", sep = ",", col.names = TRUE)
# Shapiro-Wilk test for normality
shapiro.test(pheno[,18])

geno[1:5,1:5] ### View genotypic data.
geno$row.names[1:5]
row.names(geno)
# retain only a single row of genotyped values per each genotype
# (this is necessary because the input genotype table may contain duplicate stock ids - aka germplasmDbIds)
geno_trim <- geno[!duplicated(geno$row.names),]
#map <- read.csv("./map.csv", header = TRUE, row.names = 1)
#map[1:5,1:3] ### View Map data.
dim(geno)
dim(geno_trim)
geno_trim[1:5,1:5]
row.names(geno_trim) <- geno_trim$row.names
geno_trim[1:5,1:5]
dim(geno_trim)
geno_trim <- geno_trim[,-1]
dim(geno_trim)
geno_trim[1:5,1:5]
# genotype data is coded as 0,1,2 - convert this to -1,0,1
geno_trim <- geno_trim - 1

##### Get marker data from marker names in geno file:
coordinate_matrix <- matrix(nrow = length(colnames(geno_trim)), ncol = 3)
for (marker in 1:length(colnames(geno_trim))) {
  current_string = strsplit(colnames(geno_trim)[marker], split='_', fixed=TRUE)
  coordinate_matrix[marker,1] = colnames(geno_trim)[marker]
  coordinate_matrix[marker,2] = current_string[[1]][1]
  coordinate_matrix[marker,3] = current_string[[1]][2]
}
coordinate_matrix[1:5,1:3]

geno_trim[1:10,1:10]
# Need to revisit filtering... for now, skip....
#geno.filtered <- filtering.function(geno,0.4,0.60,0.05)
geno.filtered <- geno_trim
#dim(geno_trim)
dim(geno.filtered)
#geno.filtered[1:5,1:5]



##### The data in the database has already been imputed, but we use the A.mat function here for MAF filtering and to generate the kinship matrix #####
library(rrBLUP)
Imputation <- A.mat(geno.filtered,impute.method="EM",return.imputed=T,min.MAF=0.05)

K.mat <- Imputation$A ### KINSHIP matrix
geno.gwas <- Imputation$imputed #NEW geno data.
dim(geno.gwas)

##### PCA/Population Structure #####
# Centering the data
geno.scale <- scale(geno.gwas,center=T,scale=F)
svdgeno <- svd(geno.scale)
PCA <- geno.scale%*%svdgeno$v #Principal components
PCA[1:5,1:5]
## Screeplot to visualize the proportion of variance explained by PCA
#
#plot(round((svdgeno$d)^2/sum((svdgeno$d)^2),d=7)[1:10],type="o",main="Screeplot",xlab="PCAs",ylab="% variance")
#
##Proportion of variance explained by PCA1 and PCA2
PCA1 <- 100*round((svdgeno$d[1])^2/sum((svdgeno$d)^2),d=3); PCA1
PCA2 <- 100*round((svdgeno$d[2])^2/sum((svdgeno$d)^2),d=3); PCA2
### Plotting Principal components.
png(figure2_file_name)
plot(PCA[,1],PCA[,2],xlab=paste("PC1: ",PCA1,"%",sep=""),ylab=paste("PC2: ",PCA2,"%",sep=""),pch=20,cex=0.7)
dev.off()


##### Work to match phenotyes and genotypes #####
pheno_mod[1:5,1:18]
# NOTA BENE: Still need to extract only unique phenotype values (as I did above with genotype...), also need to exclude NAs, I think...
# Ultimately, it may be better to take an average? TBD...
# Maybe RRblup can handle multiple phenotypes per genotype? I doubt this, don't see how it would work...
dim(pheno_mod)
pheno_mod=pheno_mod[which(pheno_mod$pheno_vector != "NA"),]
print("Filtering out NAs...")
dim(pheno_mod)
pheno_mod <- pheno_mod[!duplicated(pheno_mod$germplasmDbId),]
print("Filtering out duplicated stock IDs...")
dim(pheno_mod)
pheno_mod=pheno_mod[pheno_mod$germplasmDbId%in%rownames(geno.gwas),]
print("Filtering out stock IDs not in geno matrix...")
dim(pheno_mod)
pheno_mod$germplasmDbId<-factor(as.character(pheno_mod$germplasmDbId), levels=rownames(geno.gwas)) #to ensure same levels on both files
pheno_mod <- pheno_mod[order(pheno_mod$germplasmDbId),]
##Creating file for GWAS function from rrBLUP package
pheno_mod$locationDbId<- as.factor(pheno_mod$locationDbId)
# Check the number of levels in the pheno_mod$locationDbId
location_levels <- nlevels(pheno_mod$locationDbId)
print("Number of Levels:")
location_levels
# Check model.matrix
# Set model.matrix to include locationDbId in the model, but not if this factor has only one level...
if (nlevels(pheno_mod$locationDbId) > 1) {
X<-model.matrix(~-1+locationDbId, data=pheno_mod)
} else {
X<-model.matrix(~-1, data=pheno_mod)
}
pheno.gwas <- data.frame(GID=pheno_mod$germplasmDbId,X,PHENO=pheno_mod$pheno_vector)
pheno.gwas[1:5,1:2]
geno.gwas <- geno.gwas[rownames(geno.gwas)%in%pheno.gwas$GID,]
pheno.gwas <- pheno.gwas[pheno.gwas$GID%in%rownames(geno.gwas),]
geno.gwas <- geno.gwas[rownames(geno.gwas)%in%rownames(K.mat),]
K.mat <- K.mat[rownames(K.mat)%in%rownames(geno.gwas),colnames(K.mat)%in%rownames(geno.gwas)]
pheno.gwas <- pheno.gwas[pheno.gwas$GID%in%rownames(K.mat),]
pheno.gwas[1:5,1:2]
geno.gwas[1:5,1:5]

##### Match Genotype to the Scaffold & positions extracted above #####
# Not necessary (my map is derived directly from geno...):
# geno.gwas<-geno.gwas[,match(map$Markers,colnames(geno.gwas))]
# head(map)
# geno.gwas <- geno.gwas[,colnames(geno.gwas)%in%map$Markers]
coordinate_matrix[1:5,1:3]
dim(coordinate_matrix)
coordinate_matrix <- coordinate_matrix[coordinate_matrix[,1]%in%colnames(geno.gwas),]
dim(coordinate_matrix)
geno.gwas2<- data.frame(mark=colnames(geno.gwas),chr=coordinate_matrix[,2],loc=coordinate_matrix[,3],t(geno.gwas))
print("Done up to here")
dim(geno.gwas2)
colnames(geno.gwas2)[4:ncol(geno.gwas2)] <- rownames(geno.gwas)
head(pheno.gwas)
geno.gwas2[1:6,1:6]
K.mat[1:5,1:5]

##### Run the rrblup GWAS #####
# Set plotting to false, do our own plotting
# Choose which GWAS analysis to run based on the K-matrix flag and the PC flag:
if (include_kinship == 0) {
   if (include_pc == 0) {
      gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=NULL, plot=F, n.PC=0, min.MAF=0.05)
   } else {
     gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=NULL, plot=F, n.PC=6, min.MAF=0.05)
   }
} else {
  if (include_pc == 0) {
     gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=K.mat, plot=F, n.PC=0, min.MAF=0.05)
  } else {
    gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=K.mat, plot=F, n.PC = 6, min.MAF=0.05)
  }

}

##### Manhanttan and QQ plots #####
# Structure of results:
# Fourth column contains the -log10(p-values)
str(gwasresults)
alpha_bonferroni=-log10(0.05/length(gwasresults$PHENO))

length(gwasresults$PHENO)
alpha_bonferroni
chromosome_color_vector <- c("forestgreen","darkblue")

png(figure3_file_name)
plot(gwasresults$PHENO,col=chromosome_color_vector,ylab="-log10(pvalue)",
     main="Manhattan Plot",xaxt="n",xlab="Position",ylim=c(0,14))
#axis(1,at=c(1:length(unique(gwasresults$chr))),labels=unique(gwasresults$chr))
axis(1,at=c(0,100,200,300,400,500))
abline(a=NULL,b=NULL,h=alpha_bonferroni,col="red",lwd=2)
#abline(a=NULL,b=NULL,h=alpha_FDR_Yield,col="red",lwd=2,lty=2)
legend(1,13.5, c("Bonferroni") ,
       lty=1, col=c('red', 'blue'), bty='n', cex=1,lwd=2)
dev.off()


N <- length(gwasresults$PHENO)
expected.logvalues <- sort( -log10( c(1:N) * (1/N) ) )
observed.logvalues <- sort( gwasresults$PHENO)

png(figure4_file_name)
plot(expected.logvalues , observed.logvalues, main="QQ Plot",
     xlab="expected -log p-values ",
     ylab="observed -log p-values",col.main="blue",col="coral1",pch=20)
abline(0,1,lwd=3,col="black")
dev.off()


#alpha_bonferroni2=-log10(0.05/length(gwasresults2$PHENO))
#length(gwasresults2$PHENO)
#alpha_bonferroni2

#png("SolGWAS_Figure7.png")
#plot(gwasresults2$PHENO,col=chromosome_color_vector,ylab="-log10(pvalue)",
#     main="Q model (K=NULL,n.PC=6)",xaxt="n",xlab="Position",ylim=c(0,14))
#axis(1,at=c(0,100,200,300,400,500))
#abline(a=NULL,b=NULL,h=alpha_bonferroni2,col="red",lwd=2)
#legend(1,13.5, c("Bonferroni") ,
#       lty=1, col=c('red'), bty='n', cex=1,lwd=2)
#dev.off()


#N <- length(gwasresults2$PHENO)
#expected.logvalues2 <- sort( -log10( c(1:N) * (1/N) ) )
#observed.logvalues2 <- sort( gwasresults2$PHENO)

#png("SolGWAS_Figure8.png")
#plot(expected.logvalues2 , observed.logvalues2, main="Q model (K=NULL,n.PC=6)",
#     xlab="expected -log p-values ",
#     ylab="observed -log p-values",col.main="blue",col="coral1",pch=20)
#abline(0,1,lwd=3,col="black")
#dev.off()


#alpha_bonferroni3=-log10(0.05/length(gwasresults3$PHENO))
#length(gwasresults3$PHENO)
#alpha_bonferroni3

#png("SolGWAS_Figure9.png")
#plot(gwasresults3$PHENO,col=chromosome_color_vector,ylab="-log10(pvalue)",
#     main="K model (K=K.mat,n.PC=0)",xaxt="n",xlab="Position",ylim=c(0,14))
#axis(1,at=c(1:length(unique(gwasresults3$chr))),labels=unique(gwasresults3$chr))
#axis(1,at=c(0,100,200,300,400,500))
#abline(a=NULL,b=NULL,h=alpha_bonferroni3,col="red",lwd=2)
#abline(a=NULL,b=NULL,h=alpha_FDR_Yield,col="red",lwd=2,lty=2)
#legend(1,13.5, c("Bonferroni") ,
#       lty=1, col=c('red'), bty='n', cex=1,lwd=2)
#dev.off()


#N <- length(gwasresults3$PHENO)
#expected.logvalues3 <- sort( -log10( c(1:N) * (1/N) ) )
#observed.logvalues3 <- sort( gwasresults3$PHENO)

#png("SolGWAS_Figure10.png")
#plot(expected.logvalues3, observed.logvalues3, main="K model (K=K.mat,n.PC=0)",
#     xlab="expected -log p-values ",
#     ylab="observed -log p-values",col.main="blue",col="coral1",pch=20)
#abline(0,1,lwd=3,col="black")
#dev.off()

#alpha_bonferroni4=-log10(0.05/length(gwasresults4$PHENO))
#length(gwasresults4$PHENO)
#alpha_bonferroni4

#png("SolGWAS_Figure11.png")
#plot(gwasresults4$PHENO,col=chromosome_color_vector,ylab="-log10(pvalue)",
#     main="Q+K model (K=K.mat,n.PC=6)",xaxt="n",xlab="Position",ylim=c(0,14))
#axis(1,at=c(1:length(unique(gwasresults4$chr))),labels=unique(gwasresults4$chr))
#axis(1,at=c(0,100,200,300,400,500))
#abline(a=NULL,b=NULL,h=alpha_bonferroni,col="red",lwd=2)
#abline(a=NULL,b=NULL,h=alpha_FDR_Yield,col="red",lwd=2,lty=2)
#legend(1,13.5, c("Bonferroni") ,
#       lty=1, col=c('red'), bty='n', cex=1,lwd=2)
#dev.off()


#N <- length(gwasresults4$PHENO)
#expected.logvalues4 <- sort( -log10( c(1:N) * (1/N) ) )
#observed.logvalues4 <- sort( gwasresults4$PHENO)

#png("SolGWAS_Figure12.png")
#plot(expected.logvalues4, observed.logvalues4, main="Q+K model (K=K.mat,n.PC=6)",
#     xlab="expected -log p-values ",
#     ylab="observed -log p-values",col.main="blue",col="coral1",pch=20)
#abline(0,1,lwd=3,col="black")
#dev.off()


##### Identify the markes that are above the bonferroni cutoff #####

which(gwasresults$PHENO>alpha_bonferroni)
#which(gwasresults2$PHENO>alpha_bonferroni)
#which(gwasresults3$PHENO>alpha_bonferroni)
#which(gwasresults4$PHENO>alpha_bonferroni)
