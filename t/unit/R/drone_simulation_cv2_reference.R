# One actual median-replacement sensitivity fit, not held-out accuracy.
args <- commandArgs(TRUE)
stopifnot(length(args)==2L)
output <- normalizePath(args[1]); main <- normalizePath(args[2])
parameters <- readLines(file.path(output,"cv1.params"))
index <- function(name) {i<-which(parameters==name);stopifnot(length(i)==1L);i}
q <- (as.integer(parameters[index("NUMBER_OF_EFFECTS")+1L])-1L)/2L
stopifnot(q==2L)
effects <- strsplit(parameters[index("EFFECTS: POSITION_IN_DATAFILE NUMBER_OF_LEVELS TYPE_OF_EFFECT")+seq_len(1L+2L*q)]," +")
levels <- vapply(effects,function(x)as.integer(x[2]),integer(1))
nf <- levels[1];ng <- levels[2];np <- levels[2+q]
covariance_indices <- which(parameters=="(CO)VARIANCES")
Q <- lapply(covariance_indices,function(i)matrix(scan(text=paste(parameters[i+seq_len(q)],collapse=" "),quiet=TRUE),q,q,byrow=TRUE))
kernel <- function(number,n) {
  block<-which(parameters=="RANDOM_GROUP")[number]
  type<-parameters[block+3L];filename<-parameters[block+5L]
  if(type=="diagonal")return(diag(n))
  stopifnot(type=="user_file_inv")
  rows<-as.matrix(read.table(file.path(output,filename)))
  K<-matrix(0,n,n)
  for(i in seq_len(nrow(rows))){K[rows[i,1],rows[i,2]]<-rows[i,3];K[rows[i,2],rows[i,1]]<-rows[i,3]}
  K
}
K <- kernel(1,ng);L <- kernel(2,np)
data <- as.matrix(read.table(file.path(output,parameters[2])))
original <- as.matrix(read.table(file.path(main,"training.dat")))
stopifnot(nrow(original)==nrow(data),max(abs(original[,-ncol(original)]-data[,-ncol(data)]))==0)
missing_line <- grep("^OPTION missing ",parameters,value=TRUE)
missing <- as.numeric(sub("^OPTION missing ","",missing_line))
observed <- data[,ncol(data)]!=missing
X <- model.matrix(~0+factor(data[,5],levels=seq_len(nf)))
Zg <- do.call(cbind,lapply(seq_len(q),function(i)diag(ng)[data[,1],,drop=FALSE]*data[,6+i]))
Zp <- do.call(cbind,lapply(seq_len(q),function(i)diag(np)[data[,6],,drop=FALSE]*data[,6+i]))
A <- cbind(X,Zg,Zp)
G <- as.matrix(Matrix::bdiag(kronecker(Q[[1]],K),kronecker(Q[[2]],L)))
penalty <- matrix(0,ncol(A),ncol(A));penalty[-seq_len(nf),-seq_len(nf)]<-solve(G)
independent <- solve(crossprod(A[observed,,drop=FALSE])+penalty,crossprod(A[observed,,drop=FALSE],data[observed,ncol(data)]))
expected <- as.numeric(A%*%independent)
solutions <- read.table(file.path(output,"solutions"),skip=1)
coefficient <- function(effect,n) {x<-solutions[solutions[,2]==effect,,drop=FALSE];stopifnot(setequal(x[,3],seq_len(n)));x[match(seq_len(n),x[,3]),4]}
b <- coefficient(1,nf)
u <- c(unlist(lapply(seq_len(q),function(i)coefficient(1+i,ng))),unlist(lapply(seq_len(q),function(i)coefficient(1+q+i,np))))
reconstructed <- as.numeric(A%*%c(b,u))
yhat <- as.matrix(read.table(file.path(output,"yhat_residual")))
stopifnot(nrow(yhat)==nrow(data))
coefficient_delta<-max(abs(c(b,u)-as.numeric(independent)))
prediction_delta<-max(abs(reconstructed[observed]-expected[observed]))
readback_delta<-max(abs(reconstructed[observed]-yhat[observed,1]))
SSE <- sum((data[observed,ncol(data)]-reconstructed[observed])^2)
native_SSE<-sum(yhat[observed,2]^2)
changed <- which(observed & original[,ncol(original)]!=missing & abs(original[,ncol(original)]-data[,ncol(data)])>1e-10)
stopifnot(length(changed)>0L,coefficient_delta<.005,prediction_delta<.005,readback_delta<1e-4,abs(SSE-native_SSE)<.02)
cat("PASS: original BLUPF90 sensitivity fit matches independent mixed-model equations; coefficient delta",coefficient_delta,"prediction delta",prediction_delta,"\n")
cat("PASS: actual full Xb+Zgug+Zpup readback delta",readback_delta,"median-input SSE",SSE,"native SSE",native_SSE,"\n")
cat("PASS:",length(changed),"actually replaced input positions have reconstructed full fitted values, not zero missing-output placeholders.\n")
cat("LIMIT: median replacement and main full-data covariance transfer do not constitute held-out prediction accuracy.\n")
jsonlite::write_json(list(quantity="Median-replacement sensitivity residual SSE",not_heldout_accuracy=TRUE,coefficient_max_delta=coefficient_delta,prediction_max_delta=prediction_delta,readback_max_delta=readback_delta,median_input_SSE=SSE,native_SSE=native_SSE,replaced_input_positions=changed,reconstructed_at_replaced_positions=reconstructed[changed],original_values_at_replaced_positions=original[changed,ncol(original)]),file.path(output,"independent-reference.json"),auto_unbox=TRUE,pretty=TRUE,digits=16)
