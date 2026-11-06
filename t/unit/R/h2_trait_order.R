# Two real solGS entrypoint executions with distinct per-trait missing patterns.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
root<-normalizePath(args[1]);dir.create(args[2],recursive=TRUE,showWarnings=FALSE);out<-normalizePath(args[2])
d<-expand.grid(germplasmName=paste0("G",1:8),replicate=1:3,stringsAsFactors=FALSE)
d$studyDesign<-"CRD";d$studyName<-"Trial1";d$locationName<-"E1";d$studyYear<-2026;d$blockNumber<-1
d$FirstTrait<-50+2*as.integer(sub("G","",d$germplasmName))+sin(seq_len(nrow(d))*1.8)
d$SecondTrait<-d$FirstTrait*.6+cos(seq_len(nrow(d))*1.3)
d$FirstTrait[d$germplasmName=="G1" & d$replicate!=1]<-NA
d$SecondTrait[d$germplasmName=="G2" & d$replicate!=2]<-NA
run<-function(data,case){
  wd<-file.path(out,case);dir.create(wd,showWarnings=FALSE)
  pheno<-file.path(wd,"phenotype_data.tsv");write.table(data,pheno,sep="\t",quote=FALSE,row.names=FALSE,na="NA")
  metadata<-file.path(wd,"metadata");writeLines(paste(setdiff(names(data),c("FirstTrait","SecondTrait")),collapse="\t"),metadata)
  ins<-file.path(wd,"input_files");writeLines(paste(pheno,metadata,"/heritability/example",sep="\t"),ins)
  tab<-file.path(wd,"h2_coefficients_table.tsv");outs<-file.path(wd,"output_files");writeLines(paste(tab,file.path(wd,"h2_coefficients_json.json"),sep="\t"),outs)
  status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(root,"R/heritability/h2_rscript.R"),ins,outs)),stdout=file.path(wd,"execution.log"),stderr=file.path(wd,"execution.log"))
  if(status!=0){cat(readLines(file.path(wd,"execution.log")),sep="\n");stop("Owning solGS H2 trait-order case failed")}
  result<-read.delim(tab);result[order(result$trait),]
}
forward<-run(d,"forward")
reverse<-run(d[c(setdiff(names(d),c("FirstTrait","SecondTrait")),"SecondTrait","FirstTrait")],"reverse")
stopifnot(nrow(forward)==2L,isTRUE(all.equal(forward,reverse,tolerance=1e-7,check.attributes=FALSE)))
cat("PASS: distinct per-trait missingness does not make H2 depend on trait-column order\n")
