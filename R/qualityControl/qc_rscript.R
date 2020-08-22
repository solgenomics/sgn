#SNOPSIS

 #runs quality control analysis  using st4gi.
 
 #AUTHOR
 # Christiano Simoes (ccs263@cornell.edu)


options(echo = FALSE)

library(ltm)
library(rjson)
library(data.table)
library(phenoAnalysis)
library(dplyr)
library(methods)
library(na.tools)
library(st4gi)
library(stringr)
library(catchr)


allArgs <- commandArgs()


outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                    what = "character")


phenoDataFile      <- grep("\\/phenotype_data", inputFiles, value=TRUE)
formattedPhenoFile <- grep("formatted_phenotype_data", inputFiles, fixed = FALSE, value = TRUE)
metadataFile       <-  grep("metadata", inputFiles, value=TRUE)

qcMessagesFile     <- grep("qc_messages_table", outputFiles, value=TRUE)
qcMessagesJsonFile <- grep("qc_messages_json", outputFiles, value=TRUE)

formattedPhenoData <- c()
phenoData          <- c()

phenoData <- as.data.frame(fread(phenoDataFile, sep="\t",
                                   na.strings = c("NA", "", "--", "-", ".", "..")
                                   ))

metaData <- scan(metadataFile, what="character")

message('pheno file ', phenoDataFile)
if (colnames(phenoData[ncol(phenoData)]) =="notes"){
  mydata<-select(phenoData, -c("notes"))
}else{
  mydata <- phenoData
}

mycolnames = tolower(colnames(mydata))

myNewdata <- data.frame(mydata[,23],
                        mydata[,19],
                        mydata[,27],
                        mydata[,28],
                        mydata[,24])

for (i in 40:ncol(mydata)){
  myNewdata<-cbind(myNewdata, mydata[,i])
}


colnames(myNewdata) <- c("cipno","geno","row","col","rep")
traits = c(6:ncol(myNewdata))
j = 1
for(i in 6:ncol(myNewdata)){
  names(myNewdata)[i] <- mycolnames[i+34]
  traits[j] <- mycolnames[i+34]
  j=j+1
}


#This part I have to add to breedbase

testit <- suppressWarnings(catch_expr(check.data(myNewdata), warning = c(collect)))
message <-testit$warning
if (length(message)==0){
	message = "All good!"
	cat(message,"\n")
}else{
	message<-paste( unlist(testit$warning), collapse = '')
	cat(message,"\n")
}

#formating the result
result <- unlist(str_split(message,":"))
result <- result[2]
result <- str_replace_all(result, "[[:punct:]]", " ")
result <- unlist(str_split(result,"  "))
result <- gsub(" ","",result)

#preparing the black list of traits that not passed on the test
black_list <- c(1:length(traits))

for (i in 1:length(result)){
  if (result[i]=="c"){
    cat("removing ",result[i],"\n" )
  }else if (result[i] == ""){
    cat("removing empty spaces ",i,"\n")
      
  }else{
      black_list[i] = result[i]
    }
}

black_list<-black_list[!is.na(black_list)]

result_traits <- c(1:length(traits))

if (length(result)>1){
  for (i in 1:length(traits)){
    result_traits[i] = "Trait passed on QC"
    j=1
    for (j in 1:length(black_list)){
      if (traits[i] == black_list[j]){
        result_traits[i] = "Trait is not in the QC script"
        cat("Found the wrong trait!", "\n")
        j=length(black_list)
      }else{
        j=j+1
      }
    }
  }
}




Message = data.frame(traits,result_traits)
print(Message)

Message = Message %>% 
  dplyr::rename(
    trait = traits,
  	"QC - comments"  = result_traits,
  )




qualityControlList <- list(
                     "traits" = toJSON(traits),
                     "messages" = toJSON(result_traits)
                   )


qualityControlJson <- paste("{",paste("\"", names(qualityControlList), "\":", qualityControlList, collapse=","), "}")
qualityControlJson <- list(qualityControlJson)

fwrite(Message,
       file      = qcMessagesFile,
       row.names = FALSE,
       sep       = "\t",
       quote     = FALSE,
       )

fwrite(qualityControlJson,
       file      = qcMessagesJsonFile,
       col.names = FALSE,
       row.names = FALSE,
       qmethod   = "escape"
       )


# write.table(Message, file = qcMessagesFile, append = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)

q(save = "no", runLast = FALSE)