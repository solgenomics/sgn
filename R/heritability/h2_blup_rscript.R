

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
errorFile <- args[6]
errorMessages <- c()

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

#Removing non numeric data
error1.occured <- TRUE
if (error1.occured == "TRUE"){
  error1.occured <- FALSE
  z=0
  tryCatch({for (i in 40:ncol(pheno)){
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
  }, error = function(e) {
    error1.occured <<- TRUE
    errorMessages <<- c(errorMessages, as.character(e))
  })
}

ncol(pheno)
#removing categorical
rmtraits <- c()
for (i in 40:ncol(pheno)){
  categ <- unique(pheno[,i])
  if (length(categ)/nrow(pheno) < 0.15){
    cat("removing ",colnames(pheno[i]),"\n")
    rmtraits[[i]] <- colnames(pheno[i])
  }
}
rmtraits<-rmtraits[!is.na(rmtraits)]
rmtraits
ncol(pheno)


if (length(rmtraits)>0){
  for (i in 1:length(rmtraits)){
    z <- ncol(pheno)
    j = 40
    while (j < z){
      if (rmtraits[i] == colnames(pheno[j])){
        pheno[[j]] <- NULL
        z = ncol(pheno)
      } else{
        j = j+1
      }
    }
  }
}

colnames(pheno)
traits <- colnames(pheno)[40:ncol(pheno)]
names <- colnames(pheno)
cbPalette <- c("blue","red","orange","green","yellow")


# if (length(traits)>9){
#   data <- data.frame(
#     name = c(study_trait),
#     value = pheno[,study_trait]
#   )
#   bplt<- ggplot(data, aes(x=name, y=value)) +
#     geom_boxplot(fill=cbPalette[1], alpha=0.4) +
#     scale_fill_viridis(discrete = TRUE, alpha=0.6) +
#     geom_jitter(color="black", size=0.4, alpha=0.9) +
#     theme_ipsum() +
#     theme(
#       legend.position="none",
#       plot.title = element_text(size=11)
#     ) +
#     ggtitle("") +
#     xlab("")
#   hstg<- ggplot(data, aes(value, fill = cut(value, 100))) +
#     geom_histogram(show.legend = FALSE) +
#     scale_fill_viridis(discrete = TRUE, alpha=0.6) +
#     theme_minimal() +
#     labs(x = names[i], y = "") +
#     ggtitle("")
  
#   myPlots<- list(bplt,hstg)
#   ml1<-marrangeGrob(grobs= myPlots, nrow = 1, ncol=2, pdf(file=NULL))
#   ggsave(figure3_file_name, ml1, width=8, height = 3, dpi=80,limitsize=FALSE, units = "in", pdf(NULL))
  
# }else{
#   z=1
#   s=1
#   pl = list()
#   hl = list()
#   for (i in 40:ncol(pheno)){
#     data1 = c()
#     data1 <- pheno[,i]
#     data <- data.frame(
#       name=c( names[i]),
#       value=c( data1 )
#     )
#     print(cbPalette[z])
    
#     pl[[s]]<- ggplot(data, aes(x=name, y=value)) +
#       geom_boxplot(fill=cbPalette[z], alpha=0.4) +
#       scale_fill_viridis(discrete = TRUE, alpha=0.6) +
#       geom_jitter(color="black", size=0.4, alpha=0.9) +
#       theme_ipsum() +
#       theme(
#         legend.position="none",
#         plot.title = element_text(size=11)
#       ) +
#       ggtitle("") +
#       xlab("")
#     hl[[s]]<- ggplot(data, aes(value, fill = cut(value, 100))) +
#       geom_histogram(show.legend = FALSE) +
#       scale_fill_viridis(discrete = TRUE, alpha=0.6) +
#       theme_minimal() +
#       labs(x = names[i], y = "") +
#       ggtitle("")
    
#     z=z+1
#     if (z>5) {
#       z=1
#     }
#     s=s+1
#   }
#   int <- length(traits)
#   cat("The int is: ", int,"\n")
#   ml<-marrangeGrob(grobs=c(pl,hl), nrow = int, ncol=2, pdf(file=NULL))
#   if (int<8){
#     int=8
#   }
#   ggsave(figure3_file_name, ml, width=8, height = int*2, dpi=80,limitsize=FALSE, units = "in", pdf(NULL))
# }

#Calculating components of variance and heritability
her = rep(NA,(ncol(pheno)-39))
Vg = rep(NA,(ncol(pheno)-39))
Ve = rep(NA,(ncol(pheno)-39))
Vres = rep(NA, (ncol(pheno)-39))
resp_var = rep(NA,(ncol(pheno)-39))


#checkning number of locations
locs <- unique(pheno$locationDbId)
reps <- unique(pheno$replicate)
years <- unique(pheno$studyYear)
szloc <- length(locs)
szreps <- length(reps)
szyr <- length(years)


#removing categorical
rmtraits <- c()
for (i in 40:ncol(pheno)){
  categ <- unique(pheno[,i])
  if (length(categ)/nrow(pheno) < 0.15){
    cat("removing ",colnames(pheno[i]),"\n")
    rmtraits[[i]] <- colnames(pheno[i])
  }
}
rmtraits<-rmtraits[!is.na(rmtraits)]
rmtraits
ncol(pheno)
if (length(rmtraits)>0){
	for (i in 1:length(rmtraits)){
	  z <- ncol(pheno)
	  j = 40
	  while (j < z){
	    if (rmtraits[i] == colnames(pheno[j])){
	      pheno[[j]] <- NULL
	      z = ncol(pheno)
	    } else{
	      j = j+1
	    }
	  }
	}
  }

ncol(pheno)


numb = 1
library(lmerTest)
# Still need check temp data to ensure wright dimension
an.error.occured <- FALSE
tryCatch({ for (i in 40:(ncol(pheno))) {
  outcome = colnames(pheno)[i]    
  print(paste0('outcome ', outcome))
  if (szreps > 1){
    if (szloc == 1){
      if (szyr == 1){
        model <- lmer(get(outcome)~(1|germplasmName)+replicate,
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = 0
        resvar = variance [2, "vcov"]
      }else{
        model <- lmer(get(outcome) ~ (1|germplasmName) + replicate + studyYear,
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = 0
        resvar = variance [2, "vcov"]
      }
    }else if (szloc > 1) {
      if (szyr == 1){
        model <- lmer(get(outcome) ~ (1|germplasmName) + replicate + (1|locationDbId),
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = variance [2, "vcov"]
        resvar = variance [3, "vcov"]
      }else{
        model <- lmer(get(outcome) ~ (1|germplasmName) + replicate + (1|locationDbId) + studyYear,
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = variance [2, "vcov"]
        resvar = variance [3, "vcov"]
      }
    }
  }else if (szreps == 1){
    if (szloc ==1){
      if (szyr == 1){
        model <- lmer(get(outcome)~(1|germplasmName) + blockNumber,
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = 0
        resvar = variance [2, "vcov"]
      }else{
        model <- lmer(get(outcome) ~ (1|germplasmName) + studyYear + blockNumber,
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = 0
        resvar = variance [2, "vcov"]
      }
    }else if (szloc > 1){
      if (szyr ==1){
        model <- lmer(get(outcome)~(1|germplasmName)+ (1|locationDbId) +  blockNumber,
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = variance [2, "vcov"]
        resvar = variance [3, "vcov"]
      }else{
        model <- lmer(get(outcome) ~ (1|germplasmName) + studyYear + (1|locationDbId) + blockNumber,
                      na.action = na.exclude,
                      data=pheno)
        variance = as.data.frame(VarCorr(model))
        gvar = variance [1,"vcov"]
        envar = variance [2, "vcov"]
        resvar = variance [3, "vcov"]
      }
    }
  }
  
  H2 = gvar/ (gvar + (envar) + (resvar))
  #H2 = gvar/(gvar + (envar))
  H2nw = format(round(H2, 4), nsmall = 4)
  her[numb] = round(as.numeric(H2nw), digits =3)
  Vg[numb] = round(as.numeric(gvar), digits = 3)
  Ve[numb] = round(as.numeric(envar), digits = 2)
  Vres[numb] = round(as.numeric(resvar), digits = 3)
  resp_var[numb] = colnames(pheno)[i]
  
  numb = numb + 1
  
}
}, error = function(e) {
  an.error.occured <<- TRUE
  errorMessages <<- c(errorMessages, as.character(e))
})

tryCatch({
if (numb == 1){
  for (i in 40:(ncol(pheno))) {
    outcome = colnames(pheno)[i]    
    print(paste0('outcome ', outcome))
    #model <- runAnova(phenoData, outcome, genotypeEffectType = 'random')
    model <- lmer(get(outcome)~(1|germplasmName) + (1|blockNumber),
                 na.action = na.exclude,
                 data=pheno)
    variance = VarCorr(model)
    gvar = variance [[1]][1]
    envar = variance [[2]][1]
    resvar = attr(variance,"sc")^2
    H2 = gvar/ (gvar + (envar) + (resvar))
    #H2 = gvar/(gvar + (envar))
    H2nw = format(round(H2, 4), nsmall = 4)
    her[numb] = round(as.numeric(H2nw), digits =3)
    Vg[numb] = round(as.numeric(gvar), digits = 3)
    Ve[numb] = round(as.numeric(envar), digits = 2)
    Vres[numb] = round(as.numeric(resvar), digits = 3)
    resp_var[numb] = colnames(pheno)[i]
    
    numb = numb + 1
  }  
}
}, error = function(e) {
  an.error.occured <<- TRUE
  errorMessages <<- c(errorMessages, as.character(e))
})


#Prepare information to export data
tryCatch({
  library(tidyverse)
  Heritability = data.frame(resp_var,Vg, Ve, Vres, her)
  Heritability = Heritability %>% 
    rename(
      trait = resp_var,
      Hert = her,
      Vg = Vg,
      Ve = Ve,
      Vres = Vres
    )
  Heritability = na.omit(Heritability)

  # pdf(NULL)
  # library(gridExtra)
  # png(h2File, height=(25*numb), width=800)
  # par(mar=c(4,4,2,2))
  # p<-tableGrob(Heritability)
  # grid.arrange(p)
  # dev.off()
h2_json <- jsonlite::toJSON(Heritability)
jsonlite::write_json(h2_json, h2File)
write.table(Heritability, paste0(h2File,".table"), row.names=FALSE, col.names=FALSE)
# print(h2File)


}, error = function(e) {
  an.error.occured <<- TRUE
  errorMessages <<- c(errorMessages, as.character(e))
})

cat("Was there an error? ", an.error.occured,"\n")
if ( length(errorMessages) > 0 ) {
  print(sprintf("Writing Error Messages to file: %s", errorFile))
  print(errorMessages)
  write(errorMessages, errorFile)
}


#-------------------------------------------------------------------------
