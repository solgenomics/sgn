# Execute original F90 builders and native research solvers on small fixtures.
# This proves software/data contracts; it is not scientific or field acceptance.
args<-commandArgs(TRUE);stopifnot(length(args)%in%c(2L,3L))
root<-normalizePath(args[1]);output<-normalizePath(args[2])
probe<-if(length(args)==3L)args[3]else file.path(root,"t/unit/R/drone_f90_models.pl")
checks<-0L
check<-function(value,label){if(!isTRUE(value))stop(label);checks<<-checks+1L;cat("PASS:",label,"\n")}
fixture <- function(design="RCBD",envs=1L,lattice_size=16L) {
  if(design %in% c("Alpha","Lattice")) {
    trt<-paste0("G",seq_len(if(design=="Alpha")12L else as.integer(Sys.getenv("SGN_F90_LATTICE_SIZE",as.character(lattice_size)))))
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
for(binary in c("blupf90","airemlf90")) {
  executable<-Sys.which(binary)
  if(!nzchar(executable))stop("Native research solver prerequisite missing: ",binary)
  cat("BINARY",binary,system2("sha256sum",shQuote(executable),stdout=TRUE),"\n")
}
cases<-rbind(expand.grid(design=c("CRD","RCBD","Alpha","Lattice"),backend=c("blupf90","airemlf90"),kernel="identity",stringsAsFactors=FALSE),data.frame(design="RCBD",backend=c("blupf90","airemlf90"),kernel="covariance"))
cases<-rbind(cases,data.frame(design="RCBD",backend="blupf90",kernel="zero_missing"))
selected_backends<-strsplit(Sys.getenv("SGN_F90_BACKENDS","blupf90,airemlf90"),",",fixed=TRUE)[[1]]
cases<-cases[cases$backend%in%selected_backends,,drop=FALSE]
selected_designs<-strsplit(Sys.getenv("SGN_F90_DESIGNS","CRD,RCBD,Alpha,Lattice"),",",fixed=TRUE)[[1]]
cases<-cases[cases$design%in%selected_designs,,drop=FALSE]
for(case_index in seq_len(nrow(cases))) {
  design<-cases$design[case_index];backend<-cases$backend[case_index];kernel_mode<-cases$kernel[case_index]
  dir<-file.path(output,paste(design,backend,kernel_mode,sep="_"));dir.create(dir)
  d<-fixture(design,lattice_size=if(backend=="airemlf90")25L else 16L);g<-as.integer(factor(d$germplasmName));plot<-seq_len(nrow(d))+1000L
  metadata<-data.frame(germplasm_stock_id=g+100L,observationunit_stock_id=plot,obsunit_rep=paste0('Повтор "',d$replicate,'"\nряд 0'),obsunit_block=paste0("Блок ",d$blockNumber),obsunit_accession_occurrence=seq_len(nrow(d))%%7L+1L)
  if(design=="CRD")metadata$obsunit_rep[seq(1,nrow(metadata),2)]<-NA_character_
  write.table(metadata,file.path(dir,"metadata.tsv"),sep="\t",quote=TRUE,qmethod="double",row.names=FALSE,na="")
  set.seed(20261103+match(design,c("CRD","RCBD","Alpha","Lattice")))
  response<-expand.grid(plot=plot,time=c(10,20,30,40))
  response$value<-50+g[match(response$plot,plot)]*2+(response$time-25)*g[match(response$plot,plot)]*.03+rnorm(nrow(response),sd=4)
  if(backend=="airemlf90"&&Sys.getenv("SGN_F90_POSITIVE_FIXTURE","1")=="1") {
    # Data generated from the actual supplied random-regression model:
    # positive-definite G and physical-plot PE, and positive heterogeneous R.
    # The earlier deterministic genotype trend had rank-one G and no PE.
    ng<-length(unique(g));np<-nrow(d)
    covariance<-if(kernel_mode=="covariance")outer(seq_len(ng),seq_len(ng),function(i,j).35^abs(i-j))else diag(ng)
    genotype_covariance<-matrix(c(4,.3,.3,2),2)
    permanent_covariance<-matrix(c(2,.2,.2,1),2)
    genotype<-t(chol(covariance))%*%matrix(rnorm(ng*2),ng,2)%*%chol(genotype_covariance)
    permanent<-matrix(rnorm(np*2),np,2)%*%chol(permanent_covariance)
    scaled<-c(0,1/3,2/3,1)
    P<-cbind(rep(1/sqrt(2),4),sqrt(3/2)*(2*scaled-1))
    log_residual<-as.numeric(P%*%c(.5,.1))
    residual<-sweep(matrix(rnorm(np*4),np,4),2,exp(log_residual/2),"*")
    block<-rnorm(length(unique(d$blockNumber)),sd=.5)[as.integer(factor(d$blockNumber))]
    fixed<-50+outer(block,rep(1,4))+matrix(rep(c(-.3,-.1,.1,.3),each=np),np,4)
    values<-fixed+(genotype[g,,drop=FALSE]+permanent)%*%t(P)+residual
    response$value<-as.vector(values)
    cat("MODEL_GENERATED",design,kernel_mode,"G_min_eigen",min(eigen(genotype_covariance,symmetric=TRUE)$values),"PE_min_eigen",min(eigen(permanent_covariance,symmetric=TRUE)$values),"true_R_range",range(exp(log_residual)),"\n")
  }
  if(kernel_mode=="zero_missing") {response$value[1]<-0;response$value[2]<-NA_real_}
  write.table(response,file.path(dir,"responses.tsv"),sep="\t",quote=FALSE,row.names=FALSE,na="")
  ids<-sort(unique(metadata$germplasm_stock_id))
  K<-if(kernel_mode=="covariance")outer(seq_along(ids),seq_along(ids),function(i,j).35^abs(i-j))else diag(length(ids))
  cat("KERNEL",design,backend,kernel_mode,"minimum_eigenvalue",min(eigen(K,symmetric=TRUE,only.values=TRUE)$values),"\n")
  grm<-expand.grid(ids,ids);grm$value<-K[cbind(match(grm[[1]],ids),match(grm[[2]],ids))]
  grm<-grm[grm[[1]]<=grm[[2]],,drop=FALSE]
  write.table(grm,file.path(dir,"grm.tsv"),sep="\t",quote=FALSE,col.names=FALSE,row.names=FALSE)
  status<-system2("perl",shQuote(c(probe,root,dir,backend,design)),stdout=file.path(dir,"execution.log"),stderr=file.path(dir,"execution.log"),env=paste0("SGN_F90_KERNEL_MODE=",kernel_mode))
  if(Sys.getenv("SGN_F90_EXPECT_REFUSAL","0")=="1") {
    message<-paste(readLines(file.path(dir,"execution.log")),collapse=" ")
    refused<-grepl("NATIVE_NAMED_REFUSAL:.*(failed numerically|did not report convergence)",message)||
      grepl("Native RR variance summary: The final native covariance has negative reported eigenvalues.",message,fixed=TRUE)
    check(status!=0L&&refused,paste("actual",backend,design,"preserved identifiable unusable-fit case has an exact named numerical/convergence/covariance refusal"))
    working<-readLines(file.path(dir,"working-directory.txt"))[1]
    check(!file.exists(file.path(working,"native-summary.json")),paste("actual",backend,design,"refused fit produces no successful variance summary or accepted readback"))
    next
  }
  if(status!=0L){cat(readLines(file.path(dir,"execution.log")),sep="\n");stop("Actual native solver failed: ",backend," / ",design)}
  working_directory<-readLines(file.path(dir,"working-directory.txt"))[1]
  check(dirname(working_directory)==dir&&working_directory!=dir,paste("actual",backend,design,kernel_mode,"uses an isolated request cwd for fixed solver outputs"))
  dir<-working_directory
  numeric_kernel<-as.matrix(read.table(file.path(dir,"grm-numeric.txt")))
  restored<-matrix(0,length(ids),length(ids));restored[numeric_kernel[,1:2,drop=FALSE]]<-numeric_kernel[,3]
  restored[lower.tri(restored)]<-t(restored)[lower.tri(restored)]
  check(nrow(numeric_kernel)==length(ids)*(length(ids)+1)/2&&all(numeric_kernel[,1]<=numeric_kernel[,2])&&max(abs(restored-K))<6e-9,paste("actual",backend,design,kernel_mode,"file mapping preserves the supplied covariance and scalar genotype IDs"))
  resource<-jsonlite::fromJSON(file.path(dir,"resources.json"));cat("RESOURCE",design,backend,kernel_mode,"seconds",resource$elapsed_seconds,"maximum_rss_kb",resource$maximum_rss_kb,"exit",resource$exit_code,"\n")
  data<-as.matrix(read.table(file.path(dir,"training.dat")))
  observed<-data[,ncol(data)] != -999
  if(kernel_mode=="zero_missing")check(sum(data[,ncol(data)]==0)==1L&&sum(!observed)==1L,"actual native writer preserves measured zero and gives only the missing observation its declared sentinel")
  check(ncol(data)==9L&&nrow(data)==nrow(d)*4L&&all(is.finite(data)),paste("actual",backend,design,"consumes complete numeric rows without text-tag column shifts"))
  expected_groups<-if(design=="CRD")4L else length(unique(paste(d$replicate,d$blockNumber)))*4L
  if(design=="RCBD")expected_groups<-length(unique(d$blockNumber))*4L
  check(length(unique(data[,5]))==expected_groups,paste("actual",backend,design,"uses declared design/time groups rather than occurrences"))
  solutions<-read.table(file.path(dir,"solutions"),header=FALSE,skip=1,row.names=NULL)
  names(solutions)[1:4]<-c("trait","effect","level","estimate")
  check(all(is.finite(solutions$estimate)),paste("actual",backend,design,"returns finite fixed/genotype/physical-plot coefficients"))
  n_fixed<-max(data[,5]);n_gen<-max(data[,1]);n_plot<-max(data[,6])
  X<-model.matrix(~0+factor(data[,5],levels=seq_len(n_fixed)))
  Zg<-cbind(diag(n_gen)[data[,1],,drop=FALSE]*data[,7],diag(n_gen)[data[,1],,drop=FALSE]*data[,8])
  Zp<-cbind(diag(n_plot)[data[,6],,drop=FALSE]*data[,7],diag(n_plot)[data[,6],,drop=FALSE]*data[,8])
  Z<-cbind(Zg,Zp)
  coefficient<-function(effect,n){s<-solutions[solutions$effect==effect,,drop=FALSE];stopifnot(setequal(s$level,seq_len(n)));s$estimate[match(seq_len(n),s$level)]}
  b<-coefficient(1,n_fixed);u<-c(coefficient(2,n_gen),coefficient(3,n_gen),coefficient(4,n_plot),coefficient(5,n_plot))
  coefficients<-c(u[1],u[n_gen+1])
  P<-as.matrix(read.delim(file.path(dir,"polynomial.tsv")))
  summary<-jsonlite::fromJSON(file.path(dir,"native-summary.json"),simplifyVector=FALSE)
  check(summary$version==2L&&summary$time_scale=="DAP"&&summary$covariance_source==if(backend=="airemlf90")"estimated"else"supplied",paste("actual",backend,design,"archives the versioned native variance definition and covariance source"))
  check(setequal(vapply(summary$reference_units,function(x)as.character(x$plot_id),character(1)),as.character(plot))&&all(vapply(summary$reference_units,function(x)abs(x$weight-1/nrow(d))<1e-12,logical(1))),paste("actual",backend,design,"variance reference preserves all physical plot IDs and fixed equal weights"))
  if(backend=="airemlf90") {
    final<-readLines(file.path(dir,"polynomial.tsv.log"));final<-final[tail(grep("^Final Estimates",final),1):length(final)]
    # Independent parser of the original solver text, not the shared helper.
    matrix_at<-function(effect){i<-grep(paste0("Genetic variance\\(s\\) for effect +",effect," *$"),final);stopifnot(length(i)==1L);matrix(scan(text=paste(final[i+seq_len(ncol(P))],collapse=" "),quiet=TRUE),ncol(P),byrow=TRUE)}
    reported_matrix<-function(effect) {
      raw<-matrix_at(effect)
      # The positive ordinary matrix remains unchanged. For a rounding-
      # indefinite printout, reconstruct the SAME native reported eigensystem.
      if(min(eigen(raw,symmetric=TRUE,only.values=TRUE)$values)< -1e-12*max(abs(raw))) {
        start<-grep(paste0("Genetic variance\\(s\\) for effect +",effect," *$"),final)
        next_section<-grep("Genetic variance\\(s\\)|^ new R",final)
        end<-next_section[next_section>start][1];if(is.na(end))end<-length(final)+1L
        section<-final[start:(end-1L)]
        iv<-grep("eigenvectors",section);ie<-grep("eigenvalues",section)
        vectors<-matrix(scan(text=paste(section[iv+seq_len(ncol(P))],collapse=" "),quiet=TRUE),ncol(P),byrow=TRUE)
        values<-scan(text=paste(section[(ie+1L):length(section)],collapse=" "),quiet=TRUE)
        stopifnot(length(values)==ncol(P),all(values>=0))
        return(vectors%*%diag(values,nrow=length(values))%*%t(vectors))
      }
      raw
    }
    qg<-reported_matrix(2);qp<-reported_matrix(2+ncol(P))
    gamma_lines<-grep("1 -th trait:.*-th coefficient",final,value=TRUE)
    gamma<-as.numeric(sub(".*= *","",gamma_lines))
  } else {
    qg<-qp<-as.matrix(read.table(file.path(dir,"start-covariance.tsv")))
    gamma<-numeric()
  }
  reference_g<-diag(P%*%qg%*%t(P));reference_pe<-diag(P%*%qp%*%t(P))
  reference_r<-if(length(gamma))exp(as.numeric(P%*%gamma))else rep(1,nrow(P))
  reference_mean_diagonal<-mean(diag(K)[data[match(seq_len(n_plot),data[,6]),1]])
  reference_share<-reference_mean_diagonal*reference_g/(reference_mean_diagonal*reference_g+reference_pe+reference_r)
  actual_share<-vapply(summary$by_time,function(x)x$genetic_share,numeric(1))
  check(identical(as.logical(unlist(summary$observation_mask)),as.logical(observed)),paste("actual",backend,design,kernel_mode,"readback uses original observation mask rather than residual value"))
  check(length(actual_share)==4L&&max(abs(actual_share-reference_share))<1e-8,paste("actual",backend,design,kernel_mode,"date variance shares match an independent full-Q/kernel/gamma calculation"))
  check(max(abs(unlist(summary$genetic_covariance)-as.vector(t(qg))))<1e-10&&max(abs(vapply(summary$by_time,function(x)x$residual_variance,numeric(1))-reference_r))<1e-8,paste("actual",backend,design,"preserves final/supplied covariance and separates residual variance from SE"))
  expected_curve<-as.numeric(P%*%coefficients)
  code<-paste0("print CXGN::DroneImagery::LegendrePolynomials::normalized_legendre_polynomial_sum([",paste(format(coefficients,digits=17),collapse=","),"],$_),qq(\\n) for (0,1/3,2/3,1);")
  actual_curve<-as.numeric(system2("perl",c("-MCXGN::DroneImagery::LegendrePolynomials","-e",shQuote(code)),stdout=TRUE))
  check(length(actual_curve)==4L&&max(abs(actual_curve-expected_curve))<1e-7,paste("actual",backend,design,"saved genotype curve matches the fitted normalized signed polynomial basis"))
  predicted<-as.numeric(X%*%b+Z%*%u)
  yhat<-as.matrix(read.table(file.path(dir,"yhat_residual")))
  cat("NATIVE",design,backend,"prediction_max_delta",max(abs(predicted[observed]-yhat[observed,1])),"response_max_delta",max(abs(data[observed,9]-rowSums(yhat[observed,1:2,drop=FALSE]))),"\n")
  check(max(abs(predicted[observed]-yhat[observed,1]))<1e-4&&max(abs(data[observed,9]-rowSums(yhat[observed,1:2,drop=FALSE])))<1e-4,paste("actual",backend,design,"fitted/residual readback equals the independently reconstructed physical-unit model matrix"))
  if(backend=="blupf90") {
    solver_log<-readLines(file.path(dir,"polynomial.tsv.log"))
    convergence_line<-grep("iterations,.*convergence criterion=",solver_log,value=TRUE)
    convergence<-if(length(convergence_line))as.numeric(sub(".*criterion= *","",tail(convergence_line,1)))else NA_real_
    requested_line<-grep("^OPTION conv_crit ",readLines(file.path(dir,"parameters.txt")),value=TRUE)
    requested<-as.numeric(sub("^OPTION conv_crit ","",requested_line))
    direct<-any(grepl("^OPTION solv_method FSPAK",readLines(file.path(dir,"parameters.txt"))))
    if(direct) {
      check(length(requested)==1L&&requested==1e-12&&any(grepl("solving method.*FSPAK",solver_log)),paste("actual BLUPF90",design,kernel_mode,"uses the documented original direct solver independently of inverse tolerance"))
    }else{
      check(length(requested)==1L&&requested==1e-12&&is.finite(convergence)&&convergence<=requested,paste("actual BLUPF90",design,kernel_mode,"satisfies the standard native convergence criterion independently of inverse tolerance"))
    }
    # Official original BLUPF90 solves supplied (co)variances; its heterogeneous
    # residual estimation options belong to AI-REML. Compare fixed Q and R=I.
    Q<-as.matrix(read.table(file.path(dir,"start-covariance.tsv")))
    G<-as.matrix(Matrix::bdiag(kronecker(Q,K),kronecker(Q,diag(n_plot))))
    A<-cbind(X,Z);penalty<-matrix(0,ncol(A),ncol(A));penalty[-seq_len(n_fixed),-seq_len(n_fixed)]<-solve(G)
    independent<-solve(crossprod(A[observed,,drop=FALSE])+penalty,crossprod(A[observed,,drop=FALSE],data[observed,9]))
    fitted_reference<-as.numeric(A%*%independent)
    delta<-max(abs(predicted-fitted_reference));cat("MME",design,"fitted_max_delta",delta,"\n")
    genetic_reference<-as.numeric(independent[n_fixed+seq_len(2*n_gen)])
    genetic_delta<-max(abs(u[seq_len(2*n_gen)]-genetic_reference))
    cat("MME",design,kernel_mode,"genetic_coefficient_max_delta",genetic_delta,"\n")
    # Original FSPAK diagnostics had at most 4.1e-6 fitted and 1.4e-6
    # genetic error from native text precision; retain a strict 1e-4 bound.
    check(delta<1e-4&&genetic_delta<1e-4,paste("actual BLUPF90",design,kernel_mode,"matches the independent fixed-covariance mixed-model equations"))
    if(kernel_mode=="covariance") {
      wrong<-as.matrix(Matrix::bdiag(kronecker(Q,solve(K)),kronecker(Q,diag(n_plot))))
      wrong_penalty<-penalty;wrong_penalty[-seq_len(n_fixed),-seq_len(n_fixed)]<-solve(wrong)
      wrong_solution<-solve(crossprod(A[observed,,drop=FALSE])+wrong_penalty,crossprod(A[observed,,drop=FALSE],data[observed,9]))
      wrong_delta<-max(abs(u[seq_len(2*n_gen)]-as.numeric(wrong_solution[n_fixed+seq_len(2*n_gen)])))
      cat("OPPOSITE_KERNEL_CONTROL",design,"actual_vs_wrong_genetic_delta",wrong_delta,"\n")
      check(wrong_delta>.02&&wrong_delta>10*genetic_delta,"nonidentity covariance input rejects the opposite inverse-kernel interpretation")
    }
  }
}
cat("TOTAL PASS:",checks,"\n")
