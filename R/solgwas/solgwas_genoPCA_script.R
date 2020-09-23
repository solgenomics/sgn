#install.packages("rrBLUP")
#install.packages("corrplot")
#install.packages("dplyr")
library("methods")
library("dplyr")

########################################
##### Read data from temp files #####
########################################
args = commandArgs(trailingOnly = TRUE)


geno <- read.table(args[1], sep="\t", row.names = 1, header = TRUE)
figure2_file_name <- args[2]


geno[1:5,1:5] ### View genotypic data.
geno$row.names[1:5]
# retain only a single row of genotyped values per each genotype
# (this is necessary because the input genotype table may contain duplicate stock ids - aka germplasmDbIds)
geno_trim <- geno[!duplicated(row.names(geno)),]

dim(geno)
dim(geno_trim)
geno_trim[1:5,1:5]
dim(geno_trim)
dim(geno_trim)
geno_trim[1:5,1:5]
# genotype data is coded as 0,1,2 - convert this to -1,0,1
geno_trim <- geno_trim - 1

##### Get marker data from marker names in geno file:
#coordinate_matrix <- matrix(nrow = length(colnames(geno_trim)), ncol = 3)
#for (marker in 1:length(colnames(geno_trim))) {
#  current_string = strsplit(colnames(geno_trim)[marker], split='_', fixed=TRUE)
#  coordinate_matrix[marker,1] = colnames(geno_trim)[marker]
#  coordinate_matrix[marker,2] = current_string[[1]][1]
#  coordinate_matrix[marker,3] = current_string[[1]][2]
#}

geno.filtered <- geno_trim
dim(geno.filtered)

##### The data in the database has already been imputed, but we use the A.mat function here for MAF filtering and to generate the kinship matrix #####
library(rrBLUP)
Imputation <- A.mat(t(geno.filtered),impute.method="EM",return.imputed=T,min.MAF=0.05)

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
plot(PCA[,1],PCA[,2],xlab=paste("PC1: ",PCA1,"%",sep=""),ylab=paste("PC2: ",PCA2,"%",sep=""),pch=20,cex=0.7,main="PCA Plot")
dev.off()
