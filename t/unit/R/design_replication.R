# Bounded synthetic integration regressions; not field/scientific acceptance.
args <- commandArgs(TRUE)
stopifnot(length(args)==2L)
root <- normalizePath(args[1]); output <- normalizePath(args[2])
source(file.path(root,"R/design_replication.R"))
source(file.path(root,"R/stability/stability_data.R"))
library(lmerTest)
checks <- 0L
check <- function(value,label) {if(!isTRUE(value))stop(label);checks <<- checks+1L;cat("PASS:",label,"\n")}
same <- function(a,b,tolerance=1e-6) isTRUE(all.equal(a,b,tolerance=tolerance,check.attributes=FALSE))
input <- function(d,p)write.table(d,p,sep="\t",quote=FALSE,row.names=FALSE,na="")
execute <- function(script,arguments,dir,success=TRUE) {
  log<-file.path(dir,"execution.log")
  status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(root,script),arguments)),stdout=log,stderr=log)
  if((status==0L)!=success){cat(readLines(log),sep="\n");stop("Owning entrypoint failed: ",script)}
  check(TRUE,paste("actual entrypoint",script,if(success)"completed"else"refused unsupported input"))
}
decode <- function(p){x<-jsonlite::fromJSON(p);if(is.character(x))jsonlite::fromJSON(x)else x}
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

codes<-data.frame(replicate=c("01","1","0","NA",NA_character_),blockNumber=c("01","1","0","NA",NA_character_),Yield=c(1,2,3,NA,5))
path<-file.path(output,"literal-tags.tsv");input(codes,path);read<-read_analysis_phenotypes(path)
check(identical(read$replicate,codes$replicate)&&identical(read$blockNumber,codes$blockNumber),"01, 1, 0, literal NA and recorded NULL remain distinct categorical metadata")
check(is.numeric(read$Yield)&&is.na(read$Yield[4]),"trait missingness and numeric values retain normal analytical parsing")
read$designReplicate<-rep(NA_character_,nrow(read))
check(all(is.na(recorded_design_replicates(read))),"explicit unknown design column never falls back to the legacy slot")
d<-with_design_replication(fixture())
f<-canonical_design_formula(Yield~replicate+(1|germplasmName),d)
check("designReplicate" %in% all.vars(f)&&!"replicate"%in%all.vars(f),"legacy analytical formula resolves to the canonical recorded-design variable")
crd<-fixture("CRD")
check(inherits(try(validate_design_group_terms(~designReplicate,with_design_replication(crd)),silent=TRUE),"try-error"),"CRD refuses a requested recorded-replication blocking term")
for(design in c("CRD","RCBD","Alpha","Lattice")) {
  d<-fixture(design)
  fit<-analysis_run_anova(d,"Yield")
  z<-d;z$replicate<-rev(z$replicate)
  # A different occurrence counter is not supplied as an analytical tag.
  z$accessionOccurrence<-seq_len(nrow(z))%%7L+1L
  if(design %in% c("CRD","RCBD"))check(same(fitted(fit),fitted(analysis_run_anova(z,"Yield"))),paste(design,"fit is independent of unused replication tags and operational occurrences"))
  data<-d;data$germplasmName<-factor(data$germplasmName);data$replicate<-factor(data$replicate);data$blockNumber<-factor(data$blockNumber);data$trait<-data$Yield
  reference<-if(design=="CRD")lm(trait~germplasmName,data)else if(design=="RCBD")lmer(trait~germplasmName+(1|blockNumber),data)else lmer(trait~germplasmName+(1|replicate/blockNumber),data)
  check(same(fitted(fit),fitted(reference),1e-5),paste(design,"adjustment matches independently specified standard design formula"))
  adjusted<-analysis_adjusted_means(d,"Yield")
  expected<-as.data.frame(emmeans::emmeans(reference,~germplasmName))
  check(same(adjusted[[2]],round(expected$emmean,2)),paste(design,"adjusted output matches standard marginal genotype means"))
}
bad<-fixture("Alpha");bad$replicate<-NA_character_
check(inherits(try(analysis_run_anova(bad,"Yield"),silent=TRUE),"try-error"),"incomplete-block adjustment refuses missing recorded groups")
fallback<-suppressWarnings(analysis_adjusted_means(bad,"Yield",calcAverages=TRUE,logReturn=TRUE))
check(grepl("Arithmetic_mean$",names(fallback$adjMeans)[2])&&grepl("not adjusted",fallback$log),"existing explicit arithmetic fallback labels its output and explains the missing design adjustment")

# Actual solGS ANOVA entrypoint, including output table/diagnostic files for lm.
dir<-file.path(output,"solgs-crd-anova");dir.create(dir)
d<-fixture("CRD");p<-file.path(dir,"phenotype_data.tsv");input(d,p)
metadata<-file.path(dir,"metadata");writeLines(paste(setdiff(names(d),"Yield"),collapse="\t"),metadata)
traits<-file.path(dir,"traits");writeLines("Yield",traits)
ins<-file.path(dir,"input_files");writeLines(c(p,metadata,traits),ins)
outs<-file.path(dir,"output_files");files<-file.path(dir,c("anova_table_html.html","anova_table_txt.txt","anova_model.txt","adj_means.tsv","anova_diagnostics.png","anova_error.txt"));writeLines(files,outs)
execute("R/solGS/anova.r",c(ins,outs),dir)
actual<-read.delim(files[4]);reference<-as.data.frame(emmeans::emmeans(lm(Yield~germplasmName,d),~germplasmName))
check(same(actual[[2]],round(reference$emmean,2)),"actual solGS CRD output matches the independent unblocked fit")
check(all(file.info(files[1:5])$size>0),"actual solGS CRD writes table, model, means and diagnostic outputs")

# The owning class uses .model_error to mark the job failed and return the
# actual metadata cause; a nonzero R exit alone is insufficient for that path.
for(design in c("CRD","Alpha")) {
  dir<-file.path(output,paste0("mixed-missing-design-",design));dir.create(dir)
  d<-fixture(design);d$designReplicate<-if(design=="Alpha")NA_character_ else d$replicate
  p<-file.path(dir,"phenotype.tsv");input(d,p)
  params<-file.path(dir,"params.R");writeLines(c('dependent_variables<-"Yield"','fixed_factors<-"designReplicate"','random_factors<-"germplasmName"','model<-"designReplicate + (1|germplasmName)"'),params)
  execute("R/mixed_models.R",c(paste0('datafile="',p,'"'),paste0('paramfile="',params,'"')),dir,FALSE)
  message<-if(file.exists(paste0(p,".model_error")))paste(readLines(paste0(p,".model_error")),collapse=" ")else""
  check(grepl(if(design=="CRD")"CRD has no experimental blocking"else"Recorded design metadata is missing",message),paste("actual",design,"design refusal reaches the owning class error-file contract"))
}

# GGE requires no artificial cross-environment pairing or blocking tag.
gge <- function(d,label,impute=FALSE,success=TRUE) {
  dir<-file.path(output,label);dir.create(dir);p<-file.path(dir,"phenotype.tsv");input(d,p)
  files<-file.path(dir,c("result.json","graph.json","message.txt","summary.json"))
  execute("R/stability/ammi_script.R",c(p,"Yield",if(impute)"imput_yes"else"imput_no","gge",files),dir,success)
  if(success)list(result=decode(files[1]),graph=decode(files[2]),summary=decode(files[4]))else readLines(files[3])
}
d<-fixture("CRD",3);d$replicate<-NULL;d$blockNumber<-NULL
base<-gge(d,"gge-crd-no-groups")
check(nrow(base$result)==length(unique(d$germplasmName))*3L,"actual GGE works for CRD without any replication metadata")
z<-d;z$replicate<-sample(seq_len(nrow(z)));z$designReplicate<-NA_character_
other<-gge(z,"gge-irrelevant-counters")
key<-function(x)x[order(x$Accession,x$location),]
check(same(key(base$result),key(other$result)),"actual GGE means/ranks ignore occurrence labels and missing design tags")
z<-d[!(d$germplasmName=="G1"&d$locationName=="Env.one"),]
imputed<-gge(z,"gge-missing-cell",TRUE)
check(imputed$summary$imputed_cells==1L&&imputed$summary$imputation_unit=="genotype_environment_mean","GGE imputation records genotype/environment mean provenance and one missing cell")
expected<-mean(tapply(z$Yield[z$locationName=="Env.one"],z$germplasmName[z$locationName=="Env.one"],mean))
actual<-imputed$result$means[imputed$result$Accession=="G1"&imputed$result$location=="Env.one"]
check(abs(as.numeric(actual)-expected)<.006,"GGE missing cell equals the supplied mice environment-mean algorithm")
z<-d;z$Yield[1]<-NA
partial<-gge(z,"gge-partial-observations",TRUE)
expected_sd<-round(sd(z$Yield[z$germplasmName=="G1"&z$locationName=="Env one"],na.rm=TRUE),4)
actual_sd<-partial$graph$sd[partial$graph$Accession=="G1"&partial$graph$location=="Env one"]
check(length(actual_sd)==1L&&is.finite(actual_sd)&&abs(actual_sd-expected_sd)<1e-8,"GGE graph SD uses the remaining real observations, with normal four-decimal JSON precision")

cat("TOTAL PASS:",checks,"\n")
