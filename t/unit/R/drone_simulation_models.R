# Qualify the actual Simulation Perl command builders with small field inputs.
# This runs one fit per distinct Sommer template/design, not full simulations.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
root<-normalizePath(args[1]);output<-normalizePath(args[2]);library(sommer)
source(file.path(root,"R/drone_sommer_compat.R"))
checks<-0L
check<-function(value,label){if(!isTRUE(value))stop(label);checks<<-checks+1L;cat("PASS:",label,"\n")}
same<-function(a,b)isTRUE(all.equal(a,b,tolerance=1e-5,check.attributes=FALSE))
fixture<-function(design,family="multi_spatial"){
 if(design%in%c("Alpha","Lattice")){
  trt<-paste0("G",seq_len(if(design=="Alpha")24L else 25L))
  book<-if(design=="Alpha")agricolae::design.alpha(trt,k=4,r=3,seed=20261103)$book else agricolae::design.lattice(trt,r=3,seed=20261103)$book
  repcol<-if(design=="Alpha")"replication"else"r"
  d<-data.frame(id=paste0("S",book$trt),replicate=as.character(book[[repcol]]),block=as.character(book$block))
 }else{
  d<-expand.grid(id=paste0("SG",1:8),replicate=as.character(1:9),stringsAsFactors=FALSE)
  d$block<-if(design=="CRD")"0"else d$replicate
 }
 r<-as.integer(d$replicate);d$replicate<-c('Rep "01"','Rep 1','NA',paste0('Rep ',4:9))[r]
 if(design=="CRD")d$replicate<-paste0("unused-",seq_len(nrow(d)))
 if(Sys.getenv("SGN_SIMULATION_FIXED_TYPE")=="fixed_effect_trait")d$replicate<-rep(c(0,1,3),length.out=nrow(d))
 d$block<-paste0('Block "',d$block,'"');d$plot_id<-paste0("P",seq_len(nrow(d)))
 d$rowNumber<-rep(1:6,length.out=nrow(d));d$colNumber<-rep(seq_len(ceiling(nrow(d)/6)),each=6,length.out=nrow(d));d$rowNumberFactor<-d$rowNumber;d$colNumberFactor<-d$colNumber
 set.seed(20261103+match(design,c("CRD","RCBD","Alpha","Lattice")))
 # Independent review qualified unique physical coordinates and this exact
 # positive covariance recipe. Kernel B is the supplied public basis unchanged;
 # its scale sets a variance parameter, not a replacement spatial kernel.
 stopifnot(!anyDuplicated(paste(d$rowNumber,d$colNumber)))
 G<-matrix(c(36,12,12,49),2);R<-matrix(c(64,8,8,64),2)
 genotype<-matrix(rnorm(length(unique(d$id))*2),ncol=2)%*%chol(G)
 B<-as.matrix(with(d,sommer::spl2Dc(rowNumber,colNumber))$Z[[1]])
 spatial_variance<-9/mean(rowSums(B^2))
 spatial<-B%*%matrix(rnorm(ncol(B)*2,sd=sqrt(spatial_variance)),ncol=2)
 row<-matrix(0,nrow=length(unique(d$rowNumber)),ncol=2);column<-matrix(0,nrow=length(unique(d$colNumber)),ncol=2)
 if(!endsWith(family,"pure")){
  row<-matrix(rnorm(nrow(row)*2,sd=4),ncol=2)
  column<-matrix(rnorm(nrow(column)*2,sd=4),ncol=2)
 }
 residual<-matrix(rnorm(nrow(d)*2),ncol=2)%*%chol(R)
 block_effect<-matrix(0,nrow=nrow(d),ncol=2)
 if(design!="CRD"){
  group<-if(design=="RCBD")factor(d$block)else interaction(d$replicate,d$block,drop=TRUE)
  fixed<-matrix(rnorm(nlevels(group)*2,sd=2),ncol=2);block_effect<-fixed[as.integer(group),,drop=FALSE]
 }
 response<-genotype[as.integer(factor(d$id)),,drop=FALSE]+row[d$rowNumber,,drop=FALSE]+column[d$colNumber,,drop=FALSE]+spatial+residual+block_effect
 if(Sys.getenv("SGN_SIMULATION_FIXED_TYPE")=="fixed_effect_trait"){
  response[,1]<-response[,1]+7*d$replicate;response[,2]<-response[,2]-4*d$replicate
 }
 d$t1<-50+response[,1];d$t2<-30+response[,2]
 d
}
families<-strsplit(Sys.getenv("SGN_SIMULATION_FAMILIES","multi_spatial,multi_pure,uni_spatial,uni_pure"),",",fixed=TRUE)[[1]]
designs<-strsplit(Sys.getenv("SGN_SIMULATION_DESIGNS","CRD,RCBD,Alpha,Lattice"),",",fixed=TRUE)[[1]]
for(design in designs){
 d<-fixture(design);ids<-unique(d$id);grm<-expand.grid(V1=ids,V2=ids,stringsAsFactors=FALSE);grm$V3<-as.integer(grm$V1==grm$V2);genome<-as.matrix(xtabs(V3~V1+V2,grm))
 for(family in families){
  d<-fixture(design,family)
  dir<-file.path(output,paste(design,family,sep="_"));dir.create(dir,recursive=TRUE,showWarnings=FALSE)
  write.csv(d,file.path(dir,"input.csv"),row.names=FALSE);write.table(grm,file.path(dir,"grm.tsv"),row.names=FALSE,col.names=FALSE,quote=FALSE,sep="\t")
  quantitative<-Sys.getenv("SGN_SIMULATION_FIXED_TYPE")=="fixed_effect_trait"
  data<-drone_read_model_csv(file.path(dir,"input.csv"),quantitative_replicate=quantitative);multi<-startsWith(family,"multi");pure<-endsWith(family,"pure")
  fixed<-if(multi)switch(design,CRD=cbind(t1,t2)~1,RCBD=cbind(t1,t2)~block,cbind(t1,t2)~replicate/block)else switch(design,CRD=t1~1,RCBD=t1~block,t1~replicate/block)
  if(quantitative){
   fixed<-if(multi)cbind(t1,t2)~replicate else t1~replicate
   check(is.numeric(data$replicate)&&0%in%data$replicate,"explicit selected trait covariate stays numeric including zero")
   check(ncol(model.matrix(~replicate,data))!=ncol(model.matrix(if(design=="CRD")~1 else~block,data)),"selected covariate differs from the design intercept/block counterfactual")
  }
  supplied<-with(data,sommer::spl2Dc(rowNumber,colNumber));basis<-as.matrix(supplied$Z[[1]]);attr(basis,"variables")<-c("rowNumber","colNumber")
  random<-if(multi){if(pure)~vs(id,Gu=genome,Gtc=unsm(2))+vs(basis,Gtc=diag(2))else~vs(id,Gu=genome,Gtc=unsm(2))+vs(rowNumberFactor,Gtc=diag(2))+vs(colNumberFactor,Gtc=diag(2))+vs(basis,Gtc=diag(2))}else{if(pure)~vs(id,Gu=genome)+vs(basis)else~vs(id,Gu=genome)+vs(rowNumberFactor)+vs(colNumberFactor)+vs(basis)}
  residual<-if(multi)~vs(units,Gtc=unsm(2))else~vs(units)
  reference<-mmer(fixed,random=random,rcov=residual,data=data,tolParInv=if(multi)1e-6 else 1e-5,verbose=FALSE,dateWarning=FALSE)
  status<-system2("perl",shQuote(c(file.path(root,"t/unit/R/drone_simulation_models.pl"),root,dir,family,design)),stdout=file.path(dir,"execution.log"),stderr=file.path(dir,"execution.log"))
  if(status!=0L){cat(readLines(file.path(dir,"execution.log")),sep="\n");cat(readLines(file.path(dir,"actual-command.log")),sep="\n");stop("Actual Simulation template failed: ",family," / ",design)}
  actual<-read.delim(file.path(dir,"genotype.tsv"),row.names=1,check.names=FALSE);expected<-as.data.frame(reference$U$`u:id`)
  check(setequal(rownames(actual),rownames(expected)),paste("actual",family,design,"keeps genotype identities"))
  check(all(is.finite(as.matrix(actual))),paste("actual",family,design,"returns finite genetic effects"))
  check(same(as.matrix(actual[rownames(expected),,drop=FALSE]),as.matrix(expected)),paste("actual",family,design,"matches independent declared-design covariance reference"))
  spatial<-read.delim(file.path(dir,"spatial.tsv"),check.names=FALSE);check(identical(as.character(spatial$plot_id),data$plot_id),paste("actual",family,design,"keeps spatial effects attached to physical plot IDs"))
  term<-intersect(c("u:basis","u:rowNumber:colNumber","u:rowNumber"),names(reference$U));stopifnot(length(term)==1L)
  for(trait in if(multi)c("t1","t2")else"t1")check(same(spatial[[trait]],as.vector(basis%*%reference$U[[term]][[trait]])),paste("actual",family,design,trait,"spline effect matches supplied public basis reference"))
 }
}
cat("TOTAL PASS:",checks,"\n")
