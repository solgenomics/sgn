# Bounded synthetic solGS preprocessing entrypoint regressions.
# These do not validate field predictions, VCF calling or genomic CV accuracy.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
root<-normalizePath(args[1]);output<-normalizePath(args[2])
library(lmerTest)
checks<-0L
check<-function(value,label){if(!isTRUE(value))stop(label);checks<<-checks+1L;cat("PASS:",label,"\n")}
same<-function(a,b)isTRUE(all.equal(a,b,tolerance=1e-6,check.attributes=FALSE))
fixture <- function(design="RCBD",envs=1L) {
  if(design %in% c("Alpha","Lattice")) {
    trt<-paste0("G",seq_len(if(design=="Alpha")12L else 16L))
    book<-if(design=="Alpha")agricolae::design.alpha(trt,k=3,r=3,seed=20261103)$book else agricolae::design.lattice(trt,r=3,seed=20261103)$book
    repcol<-if(design=="Alpha")"replication"else"r"
    d<-data.frame(germplasmName=as.character(book$trt),replicate=as.character(book[[repcol]]),blockNumber=as.character(book$block))
  } else {
    d<-expand.grid(germplasmName=paste0("G",1:8),replicate=as.character(1:3),stringsAsFactors=FALSE)
    d$blockNumber<-if(design=="CRD")"0"else d$replicate
  }
  r<-as.integer(d$replicate)
  d$Yield<-50+as.numeric(factor(d$germplasmName))*2+c(-6,8,-2)[r]+as.numeric(factor(d$blockNumber))*.7+sin(seq_len(nrow(d))*1.91)*2
  d$replicate<-c("01","1","0")[r]
  d$studyDesign<-design;d$studyName<-"Trial1";d$locationName<-"Env one";d$studyYear<-2026
  d$rowNumber<-rep(1:6,length.out=nrow(d));d$colNumber<-rep(1:8,each=6,length.out=nrow(d))
  d$entryType<-"test";d$observationUnitDbId<-seq_len(nrow(d));d$observationUnitName<-paste0("P",seq_len(nrow(d)))
  do.call(rbind,lapply(seq_len(envs),function(e){x<-d;x$locationName<-c("Env one","Env.one","Env_three")[e];x$studyName<-paste0("Trial",e);x$Yield<-x$Yield+e*2+cos(seq_len(nrow(x))*e);x$observationUnitDbId<-x$observationUnitDbId+e*1000;x$observationUnitName<-paste0("E",e,"_",x$observationUnitName);x}))
}
selected<-strsplit(Sys.getenv("SGN_SOLGS_CONSUMERS","histogram,combine_genotype_data,combine_populations"),",",fixed=TRUE)[[1]]
for(design in c("CRD","RCBD","Alpha","Lattice")) {
  dir<-file.path(output,design);dir.create(dir)
  one<-fixture(design);one$studyDbId<-1;one$locationDbId<-1
  two<-one;two$studyName<-"Trial2";two$studyDbId<-2;two$locationName<-"Env2";two$locationDbId<-2;two$observationUnitName<-paste0("T2_",two$observationUnitName);two$Yield<-two$Yield+4+cos(seq_len(nrow(two))*1.7)
  phenotype_files<-file.path(dir,paste0("phenotype_data_",1:2,".tsv"));write.table(one,phenotype_files[1],sep="\t",quote=FALSE,row.names=FALSE,na="");write.table(two,phenotype_files[2],sep="\t",quote=FALSE,row.names=FALSE,na="")
  genotype_files<-file.path(dir,paste0("genotype_data_",1:2,".tsv"));ids<-sort(unique(one$germplasmName));markers<-matrix(rep(0:2,length.out=length(ids)*12),nrow=length(ids));genotypes<-data.frame(ids,markers)
  for(file in genotype_files)write.table(genotypes,file,sep="\t",quote=FALSE,row.names=FALSE,col.names=FALSE)
  metadata<-file.path(dir,"metadata_file");writeLines(paste(setdiff(names(one),"Yield"),collapse="\t"),metadata)
  traits<-file.path(dir,"traits");writeLines("Yield",traits)
  trait_info<-file.path(dir,"trait_info");writeLines("1\tYield",trait_info)
  info<-file.path(dir,"model_info");write.table(data.frame(Name=c("trait_id","trait_abbr","model_id","protocol_id"),Value=c("1","Yield","1","1")),info,sep="\t",quote=FALSE,row.names=FALSE)
  reference<-function(d){d$germplasmName<-factor(d$germplasmName);d$replicate<-factor(d$replicate);d$blockNumber<-factor(d$blockNumber);model<-if(design=="CRD")lm(Yield~germplasmName,d)else if(design=="RCBD")lmer(Yield~germplasmName+(1|blockNumber),d)else lmer(Yield~germplasmName+(1|replicate/blockNumber),d);m<-as.data.frame(emmeans::emmeans(model,~germplasmName));setNames(round(m$emmean,2),m$germplasmName)}
  first<-reference(one);second<-reference(two);expected<-round((first+second)/2,2)
  for(consumer in selected) {
    # Native solGS selects files by basename fragments in the full path.
    # Avoid putting a reserved output fragment in the test directory name.
    case_name<-switch(consumer,combine_genotype_data="genotype-combination",combine_populations="population-combination",consumer)
    case<-file.path(dir,case_name);dir.create(case)
    if(consumer=="histogram") {
      inputs<-c(phenotype_files[1],metadata,traits)
      files<-file.path(case,c("phenotype_data_means.tsv","trait_raw_phenodata.tsv"))
    }else if(consumer=="combine_genotype_data") {
      inputs<-c(phenotype_files,genotype_files,trait_info)
      files<-file.path(case,c("phenotype_data_combined.tsv","genotype_data_combined.tsv"))
    }else{
      inputs<-c(phenotype_files,genotype_files,metadata,info)
      files<-file.path(case,c("model_phenodata.tsv","genotype_data_combined.tsv","trait_raw_phenodata.tsv","analysis_report_results.txt"))
      file.create(files[2]) # The native caller allocates its cache placeholder.
    }
    input_manifest<-file.path(case,"input_files");output_manifest<-file.path(case,"output_files");writeLines(inputs,input_manifest);writeLines(files,output_manifest)
    log<-file.path(case,"execution.log");status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(root,paste0("R/solGS/",consumer,".r")),input_manifest,output_manifest)),stdout=log,stderr=log)
    if(status!=0L){cat(readLines(log),sep="\n");stop("Actual solGS caller failed: ",consumer," / ",design)}
    check(TRUE,paste("actual solGS",consumer,design,"entrypoint completes"))
    actual<-read.delim(files[1],row.names=1,check.names=FALSE)
    if(consumer=="histogram")rownames(actual)<-actual$germplasmName
    check(setequal(rownames(actual),names(first)),paste("actual solGS",consumer,design,"preserves genotype identities"))
    values<-if(consumer=="histogram")actual[[2]][match(names(first),rownames(actual))]else actual$Average[match(names(expected),rownames(actual))]
    check(same(as.numeric(values),unname(if(consumer=="histogram")first else expected)),paste("actual solGS",consumer,design,"matches independent standard design-adjusted means"))
  }
}
cat("TOTAL PASS:",checks,"\n")
