#install.packages("rrBLUP")
#install.packages("corrplot")
#install.packages("dplyr")
library("methods")
library("dplyr")


########################################
##### Read data from temp files #####
########################################
args = commandArgs(trailingOnly = TRUE)

pheno <- read.table(args[1], sep = "\t", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE, comment.char = "", quote = "")
colnames(pheno)

#### Current script accepts genotype data with markers as rows and accessions as columns
#### But rest of code operates on previous format which had genotype data with markers as columns and accessions as rows
#### therefore the geno table is transposed when the A.mat function is called
geno <- read.table(args[2], sep="\t", row.names = 1, header = TRUE, check.names = FALSE)
study_trait <- args[3]
study_trait
figure3_file_name <- args[4]
figure4_file_name <- args[5]
pc_check <- args[6]
kinship_check <- args[7]
gwasresultsPhenoCsv <- args[8]



print("pc_check:")
pc_check
print("kinship_check:")
kinship_check

# pheno[1:5,1:21]
# Note: still need to test how well this pmatch deals with other trickier cases
pheno_names <- names(pheno)
pheno_names <- gsub(" ", ".", pheno_names)
pheno_names <- gsub("/", ".", pheno_names)
pheno_names <- gsub("[|]", ".", pheno_names)
pheno_names <- gsub("[%()]", ".", pheno_names)

pheno_vector <- pheno[,pmatch(study_trait, pheno_names)]
pheno_vector[1:5]
# Make a new phenotype table, including only the phenotype selected:
pheno_mod <- cbind(pheno, pheno_vector)
#pheno_vector[1:10]
#pheno_mod[1:5,1:18]
#pheno[1:5,1:21]
colnames(pheno_mod)

### only the data for the trait selected....
# write.table(pheno_mod, "pheno_mod_temp_file.csv", sep = ",", col.names = TRUE)
# Shapiro-Wilk test for normality
#shapiro.test(pheno[,18])

# retain only a single column of genotyped values per each genotype
# (this is necessary because the input genotype table may contain duplicate stock ids - aka germplasmName is used yet - germplasmDbIds)
mrkData <- geno[,-(1:2)]
geno_trim <- mrkData[,!duplicated(colnames(mrkData))]
# genotype data is coded as 0,1,2 - convert this to -1,0,1
geno_trim <- geno_trim - 1
geno_trim[1:5,1:5]
##### Get marker data from marker names in geno file:
coordinate_matrix <- matrix(nrow = length(row.names(geno_trim)), ncol = 3)
for (marker in 1:length(row.names(geno_trim))) {
  current_string = strsplit(row.names(geno_trim)[marker], split='_', fixed=TRUE)
  coordinate_matrix[marker,1] = row.names(geno_trim)[marker]
  coordinate_matrix[marker,2] = current_string[[1]][1]
  coordinate_matrix[marker,3] = current_string[[1]][2]
}

# filter markers that have more than 20% missing because EM imputation will fail
minAccn <- ncol(geno_trim) * (1/5)
geno.filtered <- geno_trim[rowSums(is.na(geno_trim)) <= minAccn,]
dim(geno.filtered)
#geno.filtered[1:5,1:5]


##### The data in the database has already been imputed, but we use the A.mat function here for MAF filtering and to generate the kinship matrix #####
library(rrBLUP)
##### transposition of geno.filtered because that is what A.mat expects accessions as rows and markers as columns
mrkRelMat <- A.mat(t(geno.filtered),return.imputed=FALSE)
Imputation <- A.mat(t(geno.filtered),impute.method="EM",return.imputed=T,min.MAF=0.05)

K.mat <- Imputation$A ### KINSHIP matrix
geno.gwas <- Imputation$imputed #NEW geno data.
dim(geno.gwas)

##### Work to match phenotyes and genotypes #####
pheno_mod[1:5,1:18]
# NOTA BENE: Currently extracting unique phenotype values, also need to exclude NAs, I think...
# Ultimately, it may be better to take an average? TBD...
dim(pheno_mod)
pheno_mod=pheno_mod[which(pheno_mod$pheno_vector != "NA"),]
print("Filtering out NAs...")
dim(pheno_mod)
#pheno_mod <- pheno_mod[!duplicated(pheno_mod$germplasmName),]
pheno_mod <- distinct(pheno_mod, germplasmName, .keep_all = TRUE)
print("Filtering out duplicated stock IDs, keeping only single row for each stock ID...")
dim(pheno_mod)
rownames(geno.gwas)
colnames(pheno_mod)
colnames(pheno)
pheno_mod=pheno_mod[pheno_mod$germplasmName%in%rownames(geno.gwas),]
print("Filtering out stock IDs not in geno matrix...")
dim(pheno_mod)
pheno_mod$germplasmName<-factor(as.character(pheno_mod$germplasmName), levels=rownames(geno.gwas)) #to ensure same levels on both files
pheno_mod <- pheno_mod[order(pheno_mod$germplasmName),]

####
###Creating file for GWAS function from rrBLUP package
#pheno_mod$locationDbId<- as.factor(pheno_mod$locationDbId)
## Check the number of levels in the pheno_mod$locationDbId
#location_levels <- nlevels(pheno_mod$locationDbId)
#print("Number of Levels:")
#location_levels
## Check model.matrix
## Set model.matrix to include locationDbId in the model, but not if this factor has only one level...
#if (nlevels(pheno_mod$locationDbId) > 1) {
#X<-model.matrix(~-1+locationDbId, data=pheno_mod)
#} else {
X<-model.matrix(~-1, data=pheno_mod)
#}
pheno.gwas <- data.frame(GID=pheno_mod$germplasmName,X,PHENO=pheno_mod$pheno_vector)
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
#coordinate_matrix <- coordinate_matrix[coordinate_matrix[,1]%in%colnames(geno.gwas),]
coordinate_matrix <- geno[rownames(geno)%in%colnames(geno.gwas),]
dim(coordinate_matrix)
geno.gwas2<- data.frame(mark=colnames(geno.gwas),chr=coordinate_matrix[,1],loc=coordinate_matrix[,2],t(geno.gwas))
print("Done up to here")
dim(geno.gwas2)
colnames(geno.gwas2)[4:ncol(geno.gwas2)] <- rownames(geno.gwas)
head(pheno.gwas)
geno.gwas2[1:6,1:6]
K.mat[1:5,1:5]

##### Run the rrblup GWAS #####
# Set plotting to false, do our own plotting
# Choose which GWAS analysis to run based on the K-matrix flag and the PC flag:
if (kinship_check == 0) {
   if (pc_check == 0) {
      gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=NULL, plot=F, n.PC=0, min.MAF=0.05)
      print("Run model with no kinship, no pcs")
   } else {
      gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=NULL, plot=F, n.PC=6, min.MAF=0.05)
      print("Run model with no kinship, yes pcs")
   }
} else {
  if (pc_check == 0) {
     gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=K.mat, plot=F, n.PC=0, min.MAF=0.05)
     print("Run model with yes kinship, no pcs")
  } else {
    gwasresults<-GWAS(pheno.gwas, geno.gwas2, fixed=NULL, K=K.mat, plot=F, n.PC = 6, min.MAF=0.05)
    print("Run model with yes kinship, yes pcs")
  }

}

##### Manhanttan and QQ plots #####
# Structure of results:
# Fourth column contains the -log10(p-values)
str(gwasresults)
alpha_bonferroni=-log10(0.05/length(gwasresults$PHENO))

length(gwasresults$PHENO)
head(gwasresults)
alpha_bonferroni
#chromosome_color_vector <- c("forestgreen","darkblue")[gwasresults$chr]
chromosome_ids <- as.factor(gwasresults$chr)
marker_indicator <- match(unique(gwasresults$chr), gwasresults$chr)
png(figure3_file_name)
plot(gwasresults$PHENO,col=chromosome_ids,ylab="-log10(pvalue)",
     main="Manhattan Plot",xaxt="n",xlab="Position",ylim=c(0,14))
axis(1,at=marker_indicator,labels=gwasresults$chr[marker_indicator], cex.axis=0.8, las=2)
#axis(1,at=c(1:length(unique(gwasresults$chr))),labels=unique(gwasresults$chr))
abline(a=NULL,b=NULL,h=alpha_bonferroni,col="red",lwd=2)
#abline(a=NULL,b=NULL,h=alpha_FDR_Yield,col="red",lwd=2,lty=2)
legend(1,13.5, c("Bonferroni") ,
       lty=1, col=c('red', 'blue'), bty='n', cex=1,lwd=2)
dev.off()

# write results to csv file only for testing purpose - not for client use
write.csv(gwasresults$PHENO, file = gwasresultsPhenoCsv)

N <- length(gwasresults$PHENO)
expected.logvalues <- sort( -log10( c(1:N) * (1/N) ) )
observed.logvalues <- sort( gwasresults$PHENO)

png(figure4_file_name)
plot(expected.logvalues , observed.logvalues, main="QQ Plot",
     xlab="Expected -log p-values ",
     ylab="Observed -log p-values",col.main="black",col="coral1",pch=20)
abline(0,1,lwd=3,col="black")
dev.off()




##### Identify the markers that are above the bonferroni cutoff #####

which(gwasresults$PHENO>alpha_bonferroni)
#which(gwasresults2$PHENO>alpha_bonferroni)
#which(gwasresults3$PHENO>alpha_bonferroni)
#which(gwasresults4$PHENO>alpha_bonferroni)
