
# R CMD BATCH --no-save --no-restore '--args phenotype_file="blabla.txt" output_file="blalba.png" trait="CO:0029202" ' analyze_phenotype.r output.txt

args=(commandArgs(TRUE))

if(length(args)==0){
    print("No arguments supplied.")
    ##supply default values
    phenotype_file = 'phenotypes.txt'
    output_file = paste(phenotype_file, ".png")
    trait = ''
}else{
    for(i in 1:length(args)){
      eval(parse(text=args[[i]]))
    }
}

print(paste("phenotype file: ", phenotype_file))
print(paste("output_file: ", output_file))
print(paste("trait: ", trait))

phenodata = read.csv(phenotype_file, sep=",", header = T, stringsAsFactors = T, na.strings="NA")

blocks = unique(phenodata$blockNumber)
studyNames = unique(phenodata$studyName)

datamatrix <- c()
datasetnames <- c()

for (i in 1:(length(studyNames))) {
    for (n in 1:length(blocks)) { 
        print(paste("StudyName: ", studyNames[i], n))
        trialdata = phenodata[phenodata[,"studyName"]==studyNames[i] & phenodata[,"blockNumber"]==n, ]
        measurements = trialdata[,16]
	if (length(measurements)!=0) { 
	    name = paste(studyNames[i],"_B",blocks[n], sep="")
            print(paste("Name: ", name))
            datasetnames = c(datasetnames, name)
        }
        datamatrix = cbind(datamatrix, measurements)
        show(datamatrix)
        show(measurements)
    }		
}

show(datasetnames)
   colnames(datamatrix) <- datasetnames

show(datamatrix)


#correlation

panel.cor <- function(x, y, digits=2, cex.cor)
{
   usr <- par("usr"); on.exit(par(usr))
   par(usr = c(0, 1, 0, 1))
   r <- abs(cor(x, y, use ="na.or.complete"))
   txt <- format(c(r, 0.123456789), digits=digits)[1]
   test <- cor.test(x,y,use ="na.or.complete")
   Signif <- ifelse(round(test$p.value,3)<0.001,"p<0.001",paste("p=",round(test$p.value,3)))  
   text(0.5, 0.25, paste("r=",txt))
   text(.5, .75, Signif)
}

#pairs(data_test,lower.panel=panel.smooth,upper.panel=panel.cor)

#smooth

panel.smooth<-function (x, y, col = "black", bg = NA, pch = 18, cex = 0.8, col.smooth = "red", span = 2/3, iter = 3, ...) 
{
    points(x, y, pch = pch, col = col, bg = bg, cex = cex)
    ok <- is.finite(x) & is.finite(y)
    if (any(ok)) 
    	lines(stats::lowess(x[ok], y[ok], f = span, iter = iter), 
       	col = col.smooth, ...)
    }


#pairs(data,lower.panel=panel.smooth,upper.panel=panel.smooth)

#histo
panel.hist <- function(x, ...)
{
    usr <- par("usr"); on.exit(par(usr))
    par(usr = c(usr[1:2], 0, 1.5) )
    h <- hist(x, plot = FALSE)
    breaks <- h$breaks; nB <- length(breaks)
    y <- h$counts; y <- y/max(y)
    rect(breaks[-nB], 0, breaks[-1], y, col="grey", ...)
}

#pairs(data,lower.panel=panel.smooth,upper.panel=panel.hist)

png(output_file)

pairs(datamatrix,lower.panel=panel.smooth, upper.panel=panel.cor,diag.panel=panel.hist)		

dev.off()

