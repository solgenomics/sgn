# Known genotype IDs must not silently merge/split in name-keyed analyses.
# This checks identity contracts, not field estimates or cross-species inference.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
root<-normalizePath(args[1]);output<-normalizePath(args[2])
source(file.path(root,"R/design_replication.R"))
source(file.path(root,"R/heritability/design_factors.R"))
library(lmerTest)
checks<-0L
check<-function(value,label){if(!isTRUE(value))stop(label);checks<<-checks+1L;cat("PASS:",label,"\n")}
execute<-function(script,arguments,dir,success=FALSE){
 log<-file.path(dir,"execution.log")
 status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(root,script),arguments)),stdout=log,stderr=log)
 if((status==0L)!=success){cat(readLines(log),sep="\n");stop("Unexpected owning identity status for ",script)}
 check(TRUE,paste("actual",script,if(success)"accepts consistent genotype identity"else"refuses ambiguous genotype identity"))
}
fixture<-function(){d<-expand.grid(germplasmDbId=c("101","102","103"),replicate=c("01","1","0"),stringsAsFactors=FALSE);i<-match(d$germplasmDbId,c("101","102","103"));d$germplasmName<-paste0("G",i);d$Yield<-c(20,80,50)[i]+sin(seq_len(nrow(d))*1.8)*.5;d$studyDesign<-"CRD";d$studyYear<-2026;d$studyName<-"Identity trial";d$locationName<-"E1";d$locationDbId<-1;d$blockNumber<-"0";d$rowNumber<-rep(1:3,3);d$colNumber<-rep(1:3,each=3);d$observationUnitName<-paste0("P",seq_len(nrow(d)));d}
base<-fixture()
check(isTRUE(assert_genotype_name_identity(base)),"repeated observations of a consistent known genotype remain valid")
legacy<-base;legacy$germplasmDbId<-NULL
check(isTRUE(assert_genotype_name_identity(legacy)),"legacy name-only inputs retain their existing contract")
for(direction in c("shared_name","conflicting_names")) {
 d<-base
 if(direction=="shared_name")d$germplasmName[d$germplasmDbId%in%c("101","102")]<-"Shared label"else d$germplasmDbId[d$germplasmDbId=="102"]<-"101"
 pattern<-if(direction=="shared_name")"name maps to multiple known germplasm IDs"else"ID maps to multiple genotype names"
 failure<-tryCatch(assert_genotype_name_identity(d),error=function(e)conditionMessage(e))
 check(is.character(failure)&&grepl(pattern,failure),paste(direction,"has a named bidirectional identity refusal"))
 failure<-tryCatch(analysis_adjusted_means(d,"Yield",calcAverages=TRUE),error=function(e)conditionMessage(e))
 check(is.character(failure)&&grepl(pattern,failure),paste(direction,"cannot escape into an arithmetic name-merging fallback"))
 failure<-tryCatch(prepare_heritability_design(d),error=function(e)conditionMessage(e))
 check(is.character(failure)&&grepl(pattern,failure),paste(direction,"is refused before heritability genotype factor construction"))
 for(engine in c("lmer","sommer","spl2D")) {
  dir<-file.path(output,paste(direction,engine,sep="_"));dir.create(dir)
  p<-file.path(dir,"phenotype.tsv");write.table(d,p,sep="\t",quote=FALSE,row.names=FALSE,na="")
  params<-file.path(dir,"params.R")
  common<-c('dependent_variables<-"Yield"','fixed_factors<-"germplasmName"','random_factors<-character()')
  if(engine=="lmer")writeLines(c(common,'model<-"germplasmName"'),params)else writeLines(c(common,'fixed_model<-"Yield ~ germplasmName"','random_model<-"~ vsr(designReplicate)"'),params)
  script<-switch(engine,lmer="R/mixed_models.R",sommer="R/mixed_models_sommer.R",spl2D="R/mixed_models_spl2D.R")
  execute(script,c(paste0('datafile="',p,'"'),paste0('paramfile="',params,'"')),dir)
  error<-paste(readLines(paste0(p,".model_error")),collapse=" ")
  check(grepl(pattern,error),paste(direction,engine,"passes the named cause to its owning job/controller error contract"))
  check(!any(file.exists(paste0(p,c(".BLUEs",".BLUPs",".adjustedBLUEs",".adjustedBLUPs")))),paste(direction,engine,"leaves no bogus successful genotype result"))
 }
 dir<-file.path(output,paste0(direction,"_h2"));dir.create(dir);p<-file.path(dir,"phenotype.tsv");h<-d;names(h)[names(h)=="Yield"]<-"Yield|CO_343:0000001";write.table(h,p,sep="\t",quote=FALSE,row.names=FALSE,na="")
 outputs<-file.path(dir,c("h2.json","h2.csv","error.txt"));execute("R/heritability/h2_blup_rscript.R",c(p,"Yield",outputs),dir)
 check(grepl(pattern,paste(readLines(outputs[3]),collapse=" "))&&nrow(read.csv(outputs[2]))==0L,paste(direction,"H2 exposes the identity cause and no partial successful estimate"))
 dir<-file.path(output,paste0(direction,"_solgs_anova"));dir.create(dir);p<-file.path(dir,"phenotype_data.tsv");write.table(d,p,sep="\t",quote=FALSE,row.names=FALSE,na="")
 metadata<-file.path(dir,"metadata");writeLines(paste(setdiff(names(d),"Yield"),collapse="\t"),metadata);traits<-file.path(dir,"traits");writeLines("Yield",traits)
 ins<-file.path(dir,"input_files");outs<-file.path(dir,"output_files");writeLines(c(p,metadata,traits),ins);result<-file.path(dir,c("anova_table_html.html","anova_table_txt.txt","anova_model.txt","adj_means.tsv","anova_diagnostics.png","anova_error.txt"));writeLines(result,outs)
 execute("R/solGS/anova.r",c(ins,outs),dir)
 check(grepl(pattern,paste(readLines(file.path(dir,"execution.log")),collapse=" "))&&!file.exists(result[4]),paste(direction,"actual solGS caller refuses before dropping its explicit-ID metadata"))
}
# Actual supported positive path with explicit IDs and unchanged public schema.
dir<-file.path(output,"consistent_lmer");dir.create(dir);p<-file.path(dir,"phenotype.tsv");write.table(base,p,sep="\t",quote=FALSE,row.names=FALSE);params<-file.path(dir,"params.R");writeLines(c('dependent_variables<-"Yield"','fixed_factors<-"germplasmName"','random_factors<-character()','model<-"germplasmName"'),params)
execute("R/mixed_models.R",c(paste0('datafile="',p,'"'),paste0('paramfile="',params,'"')),dir,TRUE)
actual<-read.delim(paste0(p,".adjustedBLUEs"));reference<-aggregate(Yield~germplasmName,base,mean)
check(nrow(actual)==3L&&isTRUE(all.equal(actual$Yield,reference$Yield,tolerance=1e-8)),"consistent explicit-ID genotypes preserve valid numerical means and name-keyed output schema")
cat("TOTAL PASS:",checks,"\n")
