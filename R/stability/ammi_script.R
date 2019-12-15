


X<-read.table(file="trait_ccJgT_phenotype.txt", sep="\t",header=TRUE)



cat("Removing missing data...", "\n")
pheno= X[which(X[,52] != "NA"),]

z = 100
a = 1
b = 1
i = 0
for (i in 1:nrow(pheno)){
	pheno[i,16]=a
	pheno[i,18]=b
	i=i+1
	b=b+1
	if (b>5){
		b=1
	}
	if(i>z){
		a=a+1
		z=z+100
		cat("Preparing the data...","\n")
	}
}

pheno <- pheno[-c(701:736),]

# print(pheno[,16])

env <-as.factor(pheno$locationDbId)
gen <-as.factor(pheno$germplasmDbId)
rep <-as.factor(pheno$blockNumber)
trait <-as.numeric(pheno[,52])

drymater = pheno[,52]

write.table(drymater, file="drymater.txt", sep="\t")

# print(pheno[,52])

# library(agricolae)

# cat("Starting AMMI...","\n")

# sink("resultAMMI.txt")
# pdf(file='AMMI_test.pdf')

# model<- with(X,AMMI(env, gen, rep, trait, console=FALSE))
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

# cat("------------------------------------------------------------  ", "\n")
# cat("Médias dos Genótipos e Ambientes  ", "\n")
# cat("------------------------------------------------------------  ", "\n")
# cat("", "\n")
# model$means
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

# plot(model)


# # triplot PC 1,2,3 
# plot(model, type=2, number=TRUE)
# # biplot PC1 vs Yield 
# plot(model, first=0,second=1, number=TRUE)


# sink()
# dev.off()
