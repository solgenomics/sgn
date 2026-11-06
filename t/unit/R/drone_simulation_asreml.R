# Licensed-family construction contracts only. Never load or fit ASReml here.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
root<-normalizePath(args[1]);output<-normalizePath(args[2]);checks<-0L
check<-function(value,label){if(!isTRUE(value))stop(label);checks<<-checks+1L;cat("PASS CONSTRUCTION:",label,"\n")}
for(design in c("CRD","RCBD","Alpha","Lattice"))for(family in c("full","pure","multi")){
 dir<-file.path(output,paste(design,family,sep="_"));dir.create(dir,recursive=TRUE,showWarnings=FALSE)
 status<-system2("perl",shQuote(c(file.path(root,"t/unit/R/drone_simulation_asreml.pl"),root,dir,family,design)),stdout=file.path(dir,"construction.log"),stderr=file.path(dir,"construction.log"));if(status!=0L){cat(readLines(file.path(dir,"construction.log")),sep="\n");stop("Actual licensed constructor failed")}
 expressions<-as.list(parse(file.path(dir,"constructed.R")))
 assignment<-Filter(function(x)is.call(x)&&identical(x[[1]],as.name("<-"))&&length(x)>=3L&&identical(x[[2]],as.name("mix")),expressions)
 check(length(assignment)==1L,paste(family,design,"builds one actual model call"));call<-assignment[[1]][[3]];stopifnot(identical(call[[1]],as.name("asreml")))
 formula<-as.formula(call[[2]]);d<-expand.grid(plot=1:12,trait=c("t1","t2"));d$trait<-factor(d$trait);d$block<-factor(paste0('Block "',ceiling(d$plot/2),'"'));d$replicate<-factor(paste0("rep-",ceiling(d$plot/6)))
 if(design=="CRD")d$replicate<-factor(paste0("unused-",d$plot))
 actual<-model.matrix(delete.response(terms(formula)),d)
 expected<-if(family=="multi")switch(design,CRD=model.matrix(~trait,d),RCBD=model.matrix(~trait+block,d),model.matrix(~trait+replicate/block,d))else switch(design,CRD=model.matrix(~1,d),RCBD=model.matrix(~block,d),model.matrix(~replicate/block,d))
 check(isTRUE(all.equal(unname(actual),unname(expected),check.attributes=FALSE)),paste(family,design,"uses declared physical fixed effects and retains trait means"))
 check(all(c("random","residual","data","tol")%in%names(as.list(call))),paste(family,design,"retains existing covariance/data/tolerance call fields"))
 check(!"asreml"%in%loadedNamespaces(),paste(family,design,"does not load a licensed runtime or fabricate fit outputs"))
}
cat("TOTAL CONSTRUCTION PASS:",checks,"\n")
