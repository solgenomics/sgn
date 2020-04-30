

library(ltm)
library(rjson)
library(data.table)
library(phenoAnalysis)
library(dplyr)
#library(rbenchmark)
library(methods)
library(tidyverse)
library(hrbrthemes)
library(viridis)
library(grid)
library(gridExtra)
library(ggplot2)


##### Get data #####
args = commandArgs(trailingOnly = TRUE)

pheno <- read.table(args[1], sep = "\t", header = TRUE)

study_trait <- args[2]
figure3_file_name <- args[3]
figure4_file_name <- args[4]
h2File <- args[5]

cat("study trait is ", study_trait,"\n")

names <- colnames(pheno)
new_names <- gsub(".CO.*","",names)
colnames(pheno) <- new_names


#Calculating missing data
missingData <- apply(pheno, 2, function(x) sum(is.na(x)))
md = data.frame(missingData)

#Removing traits with more than 60% of missing data
z=0
for (i in 40:ncol(pheno)){
  if (md[i,1]/nrow(pheno)>0.6){
    pheno[[i-z]] <- NULL
    z = z+1
  }
}

colnames(pheno)
traits <- colnames(pheno)[40:ncol(pheno)]

#Removing non numeric data
z=0
for (i in 40:ncol(pheno)){
  test = is.numeric(pheno[,i])
  print(paste0('test', test))
  if (test == 'FALSE'){
    pheno[,i] <- NULL
  }
}


n=0
for (i in 40:ncol(pheno)){
	test = is.numeric(pheno[,i])
	if (test == "TRUE"){
		n = n +1
	}
}


names <- colnames(pheno)
cbPalette <- c("blue","red","orange","green","yellow")

z=1
s=1
pl = list()
hl = list()
for (i in 40:ncol(pheno)){
  data1 = c()
  data1 <- pheno[,i]
  data <- data.frame(
    name=c( names[i]),
    value=c( data1 )
  )
  print(cbPalette[z])
  
 pl[[s]]<- ggplot(data, aes(x=name, y=value)) +
                     geom_boxplot(fill=cbPalette[z], alpha=0.4) +
                     scale_fill_viridis(discrete = TRUE, alpha=0.6) +
                     geom_jitter(color="black", size=0.4, alpha=0.9) +
                     theme_ipsum() +
                     theme(
                       legend.position="none",
                       plot.title = element_text(size=11)
                     ) +
                     ggtitle("") +
                     xlab("")
 hl[[s]]<- ggplot(data, aes(value, fill = cut(value, 100))) +
                   geom_histogram(show.legend = FALSE) +
                   scale_fill_viridis(discrete = TRUE, alpha=0.6) +
                   theme_minimal() +
                   labs(x = names[i], y = "") +
                   ggtitle("")
 
 z=z+1
  if (z>5) {
    z=1
  }
  s=s+1
}
int <- length(40:ncol(pheno))
cat("The int is: ", int,"\n")
ml<-marrangeGrob(grobs=c(pl,hl), nrow = int, ncol=2, pdf(file=NULL))
if (int<8){
	int=8
}

pdf(NULL)
ggsave(figure3_file_name, ml, width=8, height = int*2, dpi=80,limitsize=FALSE, units = "in", pdf(NULL))

#Calculating components of variance and heritability
her = rep(NA,(ncol(pheno)-39))
Vg = rep(NA,(ncol(pheno)-39))
Ve = rep(NA,(ncol(pheno)-39))
Vres = rep(NA, (ncol(pheno)-39))
resp_var = rep(NA,(ncol(pheno)-39))


#checkning number of locations
locs <- unique(pheno$locationDbId)
reps <- unique(pheno$replicate)
szloc <- length(locs)
szreps <- length(reps)

numb = 1
library(lmerTest)
# Still need check temp data to ensure wright dimension
for (i in 40:(ncol(pheno))) {
  outcome = colnames(pheno)[i]    
  print(paste0('outcome ', outcome))
  if (szreps > 1){
    if (szloc == 1){
      model <- lmer(get(outcome)~(1|germplasmName)+(1|replicate)+ blockNumber,
                    na.action = na.exclude,
                    data=pheno)
    }else if (szyr ==1) {
      model <- lmer(get(outcome) ~ (1|germplasmName) + (1|replicate) + (1|locationDbId) + (1|germplasmName:locationDbId),
                    na.action = na.exclude,
                    data=pheno)
      }else{
        model <- lmer(get(outcome) ~ (1|germplasmName) + (1|replicate) + (1|locationDbId) + (1|germplasmName:locationDbId)+
                        (1|studyYear) + (1|germplasmName%in%locationDbId:studyYear),
                      na.action = na.exclude,
                      data=pheno) 
        }
    }else if (szreps == 1){
      if (szloc ==1){
      model <- lmer(get(outcome)~(1|germplasmName)+blockNumber,
                    na.action = na.exclude,
                    data=pheno)
      }else if (szyr == 1){
        model <- lmer(get(outcome)~(1|germplasmName)+(1|locationDbId) + (1|germplasmName:locationDbId),
               na.action = na.exclude,
               data=pheno)
      }else{
      model <- lmer(get(outcome) ~ (1|germplasmName) + (1|studyYear) + (1|locationDbId) +
                      (1|germplasmName:locationDbId)+(1|germplasmName:studyYear),
                    na.action = na.exclude,
                    data=pheno)
      }
    }

  
  # variance = as.data.frame(VarCorr(model))
  variance = VarCorr(model)
  gvar = variance [[1]][1]
  envar = variance [[2]][1]
  resvar = attr(variance,"sc")^2
  
  H2 = gvar/ (gvar + (envar) + (resvar))
  #H2 = gvar/(gvar + (envar))
  H2nw = format(round(H2, 4), nsmall = 4)
  her[numb] = round(as.numeric(H2nw), digits =3)
  Vg[numb] = round(as.numeric(gvar), digits = 3)
  Ve[numb] = round(as.numeric(envar), digits = 3)
  Vres[numb] = round(as.numeric(resvar), digits = 3)
  resp_var[numb] = colnames(pheno)[i]
  
  numb = numb + 1
  
}

#Prepare information to export data
Heritability = data.frame(resp_var,Vg, Ve, Vres, her)

library(tidyverse)
Heritability = Heritability %>% 
  rename(
    trait = resp_var,
    Hert = her,
    Vg = Vg,
    Ve = Ve,
    Vres = Vres
  )

print(Heritability)

pdf(NULL)
library(gridExtra)
png(h2File, height=(25*numb), width=800)
par(mar=c(4,4,2,2))
p<-tableGrob(Heritability)
grid.arrange(p)
dev.off()


#-------------------------------------------------------------------------
