


library("methods")
library("dplyr")

##### Get data #####
args = commandArgs(trailingOnly = TRUE)

pheno <- read.table(args[1], sep = "\t", header = TRUE)
study_trait <- args[2]
study_trait

figure3_file_name <- args[3]
figure4_file_name <- args[4]


pheno_vector <- pheno[,pmatch(study_trait, names(pheno))]
pheno_vector[1:5]
# Make a new phenotype table, including only the phenotype selected:
pheno_mod <- cbind(pheno, pheno_vector)

colnames(pheno_mod)

dim(pheno_mod)
pheno_mod=pheno_mod[which(pheno_mod$pheno_vector != "NA"),]
print("Filtering out NAs...")
dim(pheno_mod)
#pheno_mod <- pheno_mod[!duplicated(pheno_mod$germplasmDbId),]
# pheno_mod <- distinct(pheno_mod, germplasmDbId, .keep_all = TRUE)
# print("Filtering out duplicated stock IDs, keeping only single row for each stock ID...")
# dim(pheno_mod)

# pheno_mod$germplasmDbId<-factor(as.character(pheno_mod$germplasmDbId), levels=rownames(geno.gwas)) #to ensure same levels on both files
# pheno_mod <- pheno_mod[order(pheno_mod$germplasmDbId),]
##Creating file for GWAS function from rrBLUP package
# pheno_mod$locationDbId<- as.factor(pheno_mod$locationDbId)
# Check the number of levels in the pheno_mod$locationDbId
location_levels <- nlevels(pheno_mod$locationDbId)
print("Number of Levels:")
location_levels


env <-as.factor(pheno_mod$locationDbId)
gen <-as.factor(pheno_mod$germplasmDbId)
rep <-as.factor(pheno_mod$blockNumber)
# trait <-as.numeric(pheno[,52])

# drymater = pheno[,52]

# write.table(drymater, file="drymater.txt", sep="\t")

# print(pheno[,52])

library(agricolae)

cat("Starting AMMI...","\n")

# sink("resultAMMI.txt")
# pdf(file='AMMI_test.pdf')

model<- with(pheno_mod,AMMI(env, gen, rep, study_trait, console=FALSE))
# cat("------------------------------------------------------------  ", "\n")
# cat("Análise de Variância  ", "\n")
# cat("------------------------------------------------------------  ", "\n")
# cat("", "\n")
# model$ANOVA

# cat("------------------------------------------------------------  ", "\n")
# cat("Variação explicada por componentes principais  ", "\n")
# cat("------------------------------------------------------------  ", "\n")
# model$analysis
# cat("  ", "\n")

cat("------------------------------------------------------------  ", "\n")
cat("Médias dos Genótipos e Ambientes  ", "\n")
cat("------------------------------------------------------------  ", "\n")
cat("", "\n")
model$means
# cat("", "\n")
# cat("------------------------------------------------------------  ", "\n")
# cat("Dados para análise gráfica  ", "\n")
# cat("------------------------------------------------------------  ", "\n")
# cat("", "\n")
# model$biplot
# cat("  ", "\n")
# cat("  ", "\n")


# # *******************************************************************
# # 5. Saída gráfica
# # *******************************************************************
# # see help(plot.AMMI)
# # biplot

plot(model)


# # triplot PC 1,2,3 
png(figure3_file_name)
plot(model, type=2, number=TRUE)
dev.off()
# biplot PC1 vs Yield 
png(figure4_file_name)
plot(model, first=0,second=1, number=TRUE)
dev.off()

# sink()
# dev.off()
