# Execute the owning controller's generated model commands, not a mock model.
# Engine results below are bounded synthetic regressions, not field acceptance.
args<-commandArgs(TRUE);stopifnot(length(args)%in%c(2L,3L))
root<-normalizePath(args[1]);output<-normalizePath(args[2])
probe<-if(length(args)==3L)args[3]else file.path(root,"t/unit/R/drone_generated_models.pl")
library(lme4)
library(sommer)
inverse_tolerance<-as.numeric(Sys.getenv("SGN_DRONE_TOL_PAR_INV","1e-6"))
checks<-0L
check<-function(value,label){if(!isTRUE(value))stop(label);checks<<-checks+1L;cat("PASS:",label,"\n")}
same<-function(a,b,tol=1e-5)isTRUE(all.equal(a,b,tolerance=tol,check.attributes=FALSE))
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
source(file.path(root,"R/drone_sommer_compat.R"))
literal<-data.frame(replicate=c("01","1","0","NA",NA,'Повтор "01"\nряд 0'),block=c("01","1","0","NA",NA,'Block "A"'),id=paste0("G",1:6),plot_id=paste0("P",1:6),rowNumber=1:6,colNumber=1:6,rowNumberFactor=1:6,colNumberFactor=1:6,t1=c(1,2,3,NA,NA,6))
p<-file.path(output,"literal-model.csv");write.csv(literal,p,row.names=FALSE,na="")
decoded<-drone_read_model_csv(p)
check(identical(as.character(decoded$replicate),literal$replicate)&&identical(as.character(decoded$block),literal$block),"shared actual Drone CSV reader preserves quoted/zero/leading-zero/literal-NA/unknown categorical tags")
check(identical(decoded$id,literal$id)&&identical(decoded$plot_id,literal$plot_id),"shared Drone reader preserves physical/genotype identity strings")
check(is.numeric(decoded$t1)&&identical(is.na(decoded$t1),is.na(literal$t1)),"shared Drone reader converts numeric traits independently of categorical missing tags")
quantitative<-literal;quantitative$replicate<-c("0","01","1","2","NA","")
p<-file.path(output,"quantitative-model.csv");write.csv(quantitative,p,row.names=FALSE,na="")
decoded<-drone_read_model_csv(p,quantitative_replicate=TRUE)
check(is.numeric(decoded$replicate)&&identical(decoded$replicate,c(0,1,1,2,NA_real_,NA_real_)),"explicit fixed-trait workflow retains quantitative zero/bin values rather than factor codes")
families<-strsplit(Sys.getenv("SGN_DRONE_TEST_FAMILIES","lmer,grm,spatial,temporal,temporal_genetic"),",",fixed=TRUE)[[1]]
designs<-strsplit(Sys.getenv("SGN_DRONE_TEST_DESIGNS","CRD,RCBD,Alpha,Lattice"),",",fixed=TRUE)[[1]]
for(design in designs) {
  d<-fixture(design);data<-data.frame(replicate=d$replicate,block=paste0("Block ",d$blockNumber),id=paste0("S",d$germplasmName),plot_id=d$observationUnitName,rowNumber=d$rowNumber,colNumber=d$colNumber,rowNumberFactor=d$rowNumber,colNumberFactor=d$colNumber,t1=d$Yield)
  data$replicate<-c('Повтор "01"\nряд 0','Rep 1','NA')[match(data$replicate,c("01","1","0"))]
  data$replicate<-factor(data$replicate);data$block<-factor(data$block)
  # Independent positive residual variation is necessary for the small
  # four-component spatial fit. The earlier nearly deterministic fixture
  # drove residual/spatial variance to zero in the first legacy Newton step.
  set.seed(20261103+match(design,c("CRD","RCBD","Alpha","Lattice")))
  genotype_effect<-rnorm(length(unique(data$id)),sd=6)
  row_effect<-rnorm(length(unique(data$rowNumber)),sd=4)
  column_effect<-rnorm(length(unique(data$colNumber)),sd=4)
  data$t1<-50+genotype_effect[as.integer(factor(data$id))]+row_effect[as.integer(factor(data$rowNumber))]+column_effect[as.integer(factor(data$colNumber))]+sin(data$rowNumber/2)*cos(data$colNumber/3)*3+rnorm(nrow(data),sd=8)
  formula<-switch(design,CRD=t1~1+(1|id),RCBD=t1~block+(1|id),t1~replicate/block+(1|id))
  reference<-lmer(formula,data=data)
  expected<-ranef(reference)$id[,1];names(expected)<-rownames(ranef(reference)$id)
  for(family in families) {
    dir<-file.path(output,paste(design,family,sep="_"));dir.create(dir)
    model_data <- data
    if(grepl("temporal",family)) {
      model_data$t1 <- NULL
      for(time in c(10,20,30,40)) model_data[[as.character(time)]] <- data$t1 + (time-25)*as.numeric(factor(data$id))*.03 + rnorm(nrow(data),sd=4)
    }
    write.csv(model_data,file.path(dir,"input.csv"),row.names=FALSE)
    ids<-unique(data$id);grm<-expand.grid(ids,ids,stringsAsFactors=FALSE);grm$value<-as.integer(grm[[1]]==grm[[2]])
    write.table(grm,file.path(dir,"grm.tsv"),sep="\t",quote=FALSE,col.names=FALSE,row.names=FALSE)
    log<-file.path(dir,"execution.log")
    status<-system2("perl",shQuote(c(probe,root,dir,family,design)),stdout=log,stderr=log)
    if(status!=0L){cat(readLines(log),sep="\n");cat(readLines(file.path(dir,"actual-command.log")),sep="\n");stop("Actual generated model failed: ",family," / ",design)}
    if(family=="grm") {
      # Independent biological formula/kernel at the actual provided native
      # settings. Cross-engine optimizer precision is recorded separately.
      fixed<-switch(design,CRD=t1~1,RCBD=t1~block,t1~replicate/block)
      genome<-as.matrix(xtabs(value~Var1+Var2,grm))
      independent<-sommer::mmer(fixed,random=~vs(id,Gu=genome),rcov=~vs(units),data=data,tolParInv=inverse_tolerance,verbose=FALSE,dateWarning=FALSE)
      expected<-independent$U$`u:id`$t1
      if(is.null(names(expected)))names(expected)<-rownames(independent$U$`u:id`)
    }
    if(family=="spatial") {
      # This independent formula uses the installed public covariance basis,
      # not the application's adapter. Historical source parity is retained
      # separately with the exact source hashes and reordered-coordinate test.
      geometry <- with(data,sommer::spl2Dc(rowNumber,colNumber))
      spatial_basis <- as.matrix(geometry$Z[[1]])
      attr(spatial_basis,"variables") <- c("rowNumber","colNumber")
      spatial_data <- data
      spatial_data$rowNumberFactor <- factor(spatial_data$rowNumberFactor)
      spatial_data$colNumberFactor <- factor(spatial_data$colNumberFactor)
      fixed <- switch(design,CRD=t1~1,RCBD=t1~block,t1~replicate/block)
      genome <- as.matrix(xtabs(value~Var1+Var2,grm))
      independent <- sommer::mmer(fixed,random=~vs(id,Gu=genome)+vs(rowNumberFactor)+vs(colNumberFactor)+vs(spatial_basis),rcov=~vs(units),data=spatial_data,tolParInv=inverse_tolerance,verbose=FALSE,dateWarning=FALSE)
      expected <- independent$U$`u:id`$t1
      if(is.null(names(expected)))names(expected)<-rownames(independent$U$`u:id`)
      spatial_output <- read.delim(file.path(dir,"spatial.tsv"),check.names=FALSE)
      check(identical(as.character(spatial_output$plot_id),as.character(data$plot_id))&&all(is.finite(spatial_output$t1)),paste("actual generated spatial",design,"keeps spline predictions attached to physical plot IDs"))
    }
    if(grepl("temporal",family)) {
      long <- reshape2::melt(model_data,id.vars=setdiff(names(data),"t1"),variable.name="time",value.name="value")
      long$time <- as.numeric(as.character(long$time));long <- long[order(long$time),]
      fixed <- switch(design,CRD=value~1,RCBD=value~block,value~replicate/block)
      genome <- as.matrix(xtabs(value~Var1+Var2,grm))
      random <- if(family=="temporal") ~vs(id,Gu=genome)+vs(leg(time,1,intercept=TRUE),id)+vs(leg(time,1,intercept=TRUE),plot_id) else ~vs(id,Gu=genome)+vs(leg(time,1,intercept=TRUE),id)
      independent <- sommer::mmer(fixed,random=random,rcov=~vs(units),data=long,tolParInv=inverse_tolerance,verbose=FALSE,dateWarning=FALSE)
      expected <- independent$U$`u:id`$value
      if(is.null(names(expected)))names(expected)<-rownames(independent$U$`u:id`)
      residual <- read.delim(file.path(dir,"residual.tsv"),check.names=FALSE)
      check(setequal(paste(residual$plot_id,residual$time),paste(long$plot_id,long$time))&&all(is.finite(residual$fitted)),paste("actual generated",family,design,"retains each physical plot/time identity"))
      coefficients <- read.delim(file.path(dir,"genetic-coefficients.tsv"),check.names=FALSE)
      check(setequal(coefficients$id,names(expected))&&all(is.finite(as.matrix(coefficients[,-1,drop=FALSE]))),paste("actual generated",family,design,"retains finite genotype regression coefficients"))
    }
    actual<-read.delim(file.path(dir,"genotype.tsv"),row.names=1,check.names=FALSE)
    check(setequal(rownames(actual),names(expected))&&all(is.finite(actual[[1]])),paste("actual generated",family,design,"retains genotype IDs and trait-unit output"))
    # Compare each family with its independently specified biological model
    # at the same engine/default settings; cross-engine precision is separate.
    tolerance<-1e-6
    check(same(actual[names(expected),1],unname(expected),tolerance),paste("actual generated",family,design,"matches independent standard",if(family=="lmer")"lme4"else"Sommer covariance","BLUP reference"))
    command<-paste(readLines(file.path(dir,"command.txt")),collapse="\n")
    check(if(design=="CRD")!grepl("~replicate|~block",command)else TRUE,paste("actual generated",family,design,"uses design-dispatched fixed terms"))
  }
}

dir<-file.path(output,"f90-text-identity");dir.create(dir)
prep<-data.frame(accession_id=c("S1","S1","S1","S1"),accession_id_factor="",plot_id=c("P1","P2","P1","P2"),plot_id_factor="",replicate=c('Повтор "01"\nряд 0','Повтор "01"\nряд 0','Повтор "01"\nряд 0','Повтор "01"\nряд 0'),time=c(10,10,20,20),replicate_time=c("block-time10","block-time10","block-time20","block-time20"),ind_replicate=c("P1","P2","P1","P2"))
write.csv(prep,file.path(dir,"prep.csv"),row.names=FALSE)
status<-system2("perl",shQuote(c(probe,root,dir,"f90","CRD")),stdout=file.path(dir,"execution.log"),stderr=file.path(dir,"execution.log"))
check(status==0L,"actual generated F90 category preparation completes before the native fit")
actual<-read.delim(file.path(dir,"prep-factors.tsv"),check.names=FALSE,colClasses="character")
check(identical(actual$replicate,prep$replicate),"actual F90 factor preparation preserves quote-containing recorded tags")
check(length(unique(actual$ind_replicate))==2L&&length(unique(actual$plot_id_factor))==2L,"actual F90 preparation keeps separate physical plots sharing genotype and design tag")
cat("TOTAL PASS:",checks,"\n")
