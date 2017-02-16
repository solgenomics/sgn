
# R CMD BATCH --no-save --no-restore '--args phenotype_file="blabla.txt" output_file="blalba.png" ' analyze_phenotype.r output.txt

args=(commandArgs(TRUE))

if(length(args)==0){
   print("No arguments supplied.")
   ##supply default values
   phenotype_file = 'phenotypes.txt'
   output_file = paste0(phenotype_file, ".png", sep="")
} else {
   for(i in 1:length(args)){
       eval(parse(text=args[[i]]))
   }
}

write(paste("phenotype file: ", phenotype_file), stderr())
write(paste("output_file: ", output_file), stderr())

errorfile = paste(phenotype_file, ".err", sep="");

phenodata = read.csv(phenotype_file,fill=TRUE, sep=",", header = T, stringsAsFactors = T, na.strings="NA")

blocks = unique(phenodata$blockNumber)
print(paste("blocks: ", blocks));
studyNames = unique(phenodata$studyName)
accessions = unique(phenodata$germplasmName)
datamatrix <- c()
datasetnames <- c()
trial_accessions <- c()
all_accessions = unique(phenodata$germplasmName)

datamatrix = matrix(nrow = length(all_accessions), ncol=length(studyNames)) # * length(blocks))

for (i in 1:(length(studyNames))) {
   trialdata = phenodata[phenodata[,"studyName"]==studyNames[i], ] # & phenodata[,"blockNumber"]==n, ]

   for (m in 1:length(all_accessions)) { 
	
      acc_slice = trialdata[trialdata[,"germplasmName"] ==  as.character(all_accessions[m] ), 16 ]
	    
      acc_avg  = mean(as.numeric(acc_slice))
      col = i;
      datamatrix[m, col] = acc_avg
   }
}

colnames(datamatrix) <- studyNames
rownames(datamatrix) <- all_accessions

# remove columns containing only NULL values
#
dims = dim(datamatrix)

empty_cols <- c()
for (i in 1:dims[2]) { 
    legal_values = datamatrix[ is.finite(datamatrix[,i]), i ]

    if (length(legal_values) == 0) { 
       print(paste("empty values", length(legal_values), "dims", dims[1]))
       print(paste("found empty col ", i))
       empty_cols <- c(empty_cols, i)
    }
}

#for (i in 1:length(empty_cols)) { 
#   datamatrix <- datamatrix[,-empty_cols[i]]
#}


# remove empty rows
#
empty_rows <- c()

legal_values_in_cols_count = datamatrix[ i, is.finite(datamatrix[i,]) ]
show(legal_values_in_cols_count)
if (length(legal_values_in_cols_count) == 0) { 
   print(paste("empty values", length(legal_values_in_cols_count), "dims", dims[1]))
   print(paste("found empty row ", i))
   empty_rows <- c(empty_rows, i)
}

#for (i in 1:length(empty_rows)) { 
#    datamatrix <- datamatrix[-empty_rows[i],]
#}


if (nrow(datamatrix)==0) { 
   write("No data was retrieved from the database for this combination of trials: ", file = errorfile);
}
if (ncol(datamatrix) < 2) { 
   write("No data. Try again", file = errorfile);
}

# correlation
#
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

