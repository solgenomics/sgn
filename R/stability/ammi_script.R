


library("methods")
library("dplyr")

##### Get data #####
args = commandArgs(trailingOnly = TRUE)



pheno <- read.table(args[1], sep = "\t", header = TRUE)
study_trait <- args[2]
cat("Study trait is ", study_trait)
figure3_file_name <- args[3]
figure4_file_name <- args[4]
h2File <- args[5]

names <- colnames(pheno)
new_names <- gsub(".CO.*","", names)
colnames(pheno) <- new_names
colnames(pheno)

for (i in 1:ncol(pheno)){
	a = noquote(colnames(pheno[i]))
	b = study_trait
	if (a==b){
		print(a)
		col = i
		i = ncol(pheno)
	}else{
		cat("working ",i,"\n")
		i=i+1
	}
}


env <-as.factor(pheno$locationName)
gen <-as.factor(pheno$germplasmName)
rep <-as.factor(pheno$replicate)
# trait <-as.numeric(pheno[,col])

library(agricolae)

cat("Starting AMMI...","\n")

model<- with(pheno,AMMI(env, gen, rep, pheno[,col], console=FALSE))

anova <-format(round(model$ANOVA, 3))
anova

library(gridExtra)
png(h2File, height=130, width=800)
p<-tableGrob(anova)
grid.arrange(p)
dev.off()

# Biplot and Triplot 
png(figure3_file_name)
par(mfrow=c(2,2))
plot(model, first=0,second=1, number=TRUE, xlab = study_trait)
plot(model, type=2, number=TRUE, xlab = study_trait)
dev.off()

#Preparing Germplasm name to be printed

acc <- data.frame(unique(pheno$germplasmName))
colnames(acc)="Germplasm Name"
print(acc)

png(figure4_file_name)
q<-tableGrob(acc)
grid.arrange(q)
dev.off()


# model$analysis
# cat("  ", "\n")
#Averages
#model$means
#data for graphical analysis
# model$biplot
# sink()
# dev.off()
