################################################################################
## Function parameters
#   (1)  functionpath: (character) specifies the directory where auxillary 
#                      functions (e.g. enumerateG_revised-function.R) are 
#                      saved. 
#   (2)             L: (numeric) specifies the number of sites to sample and use for analysis. 
#                      A site is sampled if >0 reads were observed at that site for EACH of the k samples.
#   (3)         chrom: (numeric vector) specifies the chromosome(s) from which to sample the
#                      L sites.
#   (4)      mafrange: (numeric vector; length 2) specifies a range for the minor allele frequency (MAF) 
#                      of the sites to be sampled. The default is set as c(0.0,0.5), i.e. sample sites 
#                      regardless of MAF status. We found that the algorithm is most accurate when analyzing sites
#                      with MAFs in the range (0.4,0.5] in simulation experiments. We do not recommend
#                      sampling sites with rare minor alleles.
#   (5)        thinby: (numeric) specifies the minimum distance (in bp) between any two sampled sites
#   (6)         eUSER: (numeric) specifies the fixed sequencing error rate used to calculate 
#                      genotype likelihoods. This value may range from 0 to 1. 
#                      For an error rate of 1%, enter 0.01.
#   (7)       proband: (character) specifies the name of the genotype with k sequence runs, where k >1.
#   (8)    aliases.fn: (character) specifies the alias text file listing the names of the proband's k 
#                      sequence runs. Refer to the README file for a description of an alias text file 
#                      and formatting requirements. If an alias text file name is not provided or the file cannot be
#                      found, the function will automatically search for potential sequence runs associated 
#                      with the specified proband (see parameter 12 -- namedatabase). This procedure, however, 
#                      has limited capability (i.e. the search auxillary function may not find all synonymous names for 
#                      the listed proband), so we recommend that the user supply the function with an alias file if 
#                      aliases are known.                  
#   (9)         expid: (character) only specify an argument for this parameter 
#                      if you wish to run the function on ONE GIVEN proband multiple times SIMULATANEOUSLY.
#                      Use this parameter to avoid overwriting output files. A different value of <expid> should 
#                      be used for each of these runs.
#  (10)  headersuffix: (character) this function requires a header file for each chromosome (refer to the 
#                      README file for a description of this file type and formatting requirements). 
#                      Each header file follows the naming format chr${chromosome}_${headersuffix}.  
#                      Enter ${headersuffix} as the argument for this parameter. 
#                      As an example, the headersuffix associated with header file chr001_gbsheader is 
#                      'gbsheader'.
#  (11)        ncores: (numeric) specifies the number of cores to be used when running the function 
#                      (only portions of the function are parallelized). 
#  (12)  namedatabase: (character vector) if no aliases for the proband are provided, the function will search
#                      <namedatabase> for potential sequence runs associated with the specified proband. 
#  (13)     outprefix: (character vector) specifies the output filename prefix. Results are saved as Rds files. 
#                      If no filename prefix is supplied, the function will generate a prefix following the format 
#                      ${proband}_chrom${chromosome}_L${number of sites sampled}_maf${mafrange}_thinby${thinby}_chanmethod. 
#                      Files will be saved in the current working directory. Output filenames end with the suffix .rds.
#                      Example filename: 
#                      I011206_chrom1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18_L1000_maf0.4,0.5_thinby20000_chanmethod.rds
#
#     Additional information: 
#     If L exceeds the number of available sites, the function will return a warning message informing the user
#     of how many sites were available given the <thiinby> and <mafrange> criteria. The function will continue to estimate
#     the posterior probability of each identity vector regardless of this warning message. 
#
## Function output       
#     The function _outputs_ an Rds file storing a list with two elements: 'results' (list) and 'runtime' (proc_time).
#    
#                      results (list; length 4):
#                         (1) replicatenames: (list) the sample IDs of the k sequence runs associated with the proband
#                         (2) pI: (numeric vector) the posterior probability of each identity vector
#                         (3) statistics: (numeric vector) the mean read depth across the thinned set of sites for each sample
#                         (4) sitenames: (character vector) the sites sampled by the algorithm listed using the notation 
#                                        ${chromosome}_${physical position}
# 
#                      runtime: specifies how much real and CPU time (in seconds) required to run the function
#     The function _returns_ the posterior probability of each identity vector, i.e. pI (numeric vector). 
################################################################################
chanmethod = function(functionpath, L, chrom, mafrange, thinby, eUSER, proband, aliases.fn, expid, headersuffix, ncores, namedatabase, outprefix){
  require(gtools); require(stringr)
  source(paste(functionpath, "enumerateG_revised-function.R", sep="/"))
  source(paste(functionpath, "enumerateI-function.R", sep="/"))
  source(paste(functionpath, "normGL-function.R", sep="/"))
  source(paste(functionpath, "thin-function.R", sep="/"))
  source(paste(functionpath, "PL-function.R", sep="/"))
  source(paste(functionpath, "FORMAT-function.R", sep="/"))
  source(paste(functionpath, "searchforaliases-function.R", sep="/"))
  
  importdata = function(mafrange, chrompad, proband, set, thinby, expid, headersuffix){
    header.fn <- paste("chr", chrompad, "_", headersuffix, sep="")
    header <- read.table(header.fn, stringsAsFactors=F, header=T);
    
    proband.fn <- paste("chr", chrompad, "_", proband, ".AD.FORMAT", sep="")
    data <- read.delim(proband.fn, header=T, quote="", stringsAsFactors=FALSE, check.names=F)
    data <- as.matrix(data[,!colnames(data) %in% c("CHROM", "POS")])
    nastatus <- apply(data, 1, function(row){ x <- length(grep("^0,0$", row)); ifelse(x>0, "EXCLUDE", "INCLUDE")} )
    
    ##################################################################
    # procedure to find sites on chromosome <chrompad> whose maf resides in
    # (lowerbound, upperbound] defined by mafrange argument
    ##################################################################
    frq <- header$REF_FREQ                          # extract list of REF allele frequency estimates
    maf <- ifelse(frq>0.5, 1-frq, frq)                                       # compute maf at each site
    names(maf) <- header$POS
    maf[grep("EXCLUDE", nastatus)] <- NA 
    maf <- maf[!is.na(maf)]
    if(missing(mafrange)){ samplespaceL <- names(maf) } else 
      samplespaceL <- names(maf[maf>mafrange[1] & maf<=mafrange[2]])         # set of sites with specified maf (function arguement: mafrange) 
    mode(samplespaceL) <- "numeric"
    ##################################################################
    # procedure to sample <L> sites from chromosome <chrompad>, such that 
    # no two sites reside within <thinby> bp of one another
    ##################################################################
    thinned <- thin(samplespaceL, thinby)
    iteration <- 0
    while(iteration<5){    # iterate the sampling procedure 5 times
      nremaining <- length(samplespaceL[!samplespaceL %in% thinned])
      position <- sample(samplespaceL[!samplespaceL %in% thinned], nremaining, replace=F)
      position <- sort(c(thinned, position), decreasing=F)
      thinned <- thin(x=position, distance=thinby)
      iteration <- iteration+1
    }
    
    
    #   cardinalityL <- length(samplespaceL)
    #   missingL <- L; thinned <- c()
    #   fold <- 2; x <- ifelse(cardinalityL/L <fold, cardinalityL/L, fold)
    #   while(missingL>0){ 
    #     print(paste("missing", missingL, "sites;", "sampling and thinning procedure in progress", sep=" "))
    #     position <- sample(samplespaceL[!samplespaceL %in% thinned], missingL*x, replace=F)
    #     position <- sort(c(thinned, position), decreasing=F)
    #     thinned <- thin(x=position, distance=thinby)
    #     if(length(thinned)>L){ thinned <- sample(thinned, L, replace=F); 
    #                            print(paste("sampling and thinning procedure completed for chrom", chrompad, sep="")) }
    #     missingL <- L-length(thinned)
    #   }     
    ##################################################################
    # procedure to extract data for <fromgenotype> at the <L> sampled 
    # sites and import into R
    ##################################################################
    filter <- as.matrix(c("TRUESTATUS", header$POS %in% thinned))                    # create filter to extract L sites (chr0xx_expidset.filter) 
    filter.fn <- paste("chr", chrompad, "_", expid, set, ".filter", sep="")            # filter file name
    write.table(filter, filter.fn, row.names=F, col.names=F, quote=F, sep="\t")      # save filter file
    
    output.fn <- paste("chr", chrompad, "_", expid, set, ".tempdata", sep="")          # define name of temporary file (output.fn) 
    command <- paste("paste", filter.fn, header.fn,                                  # paste filter, header, and genotype columns and output to file (chr0xx_expidset.tempdata) 
                     proband.fn, "| grep 'TRUE' >", output.fn, sep=" ")     
    
    system(command) 
    data <- read.delim(output.fn, quote="", stringsAsFactors=FALSE, check.names=F)                  # import tempdata into R
    command <- paste("rm", filter.fn, output.fn, sep=" "); system(command)           # delete filter and tempdata file from working directory
    return(data)
  }
  ##################################################################
  # (1) import or find proband aliases 
  ##################################################################
  chrompad <- str_pad(string=chrom, width=3, side="left", pad=0) 
  set <- proband
  if(missing(expid)){ expid <- "" }
  
  if(missing(aliases.fn)){
    replicates <- searchforaliases(proband, namedatabase)
  } else replicates <- unlist(read.table(aliases.fn, quote="", stringsAsFactors=FALSE))
  k <- length(replicates)
  keep.fn <- paste(proband, "_aliases.txt", sep="") 
  #write.table(as.matrix(replicates), keep.fn, row.names=F, col.names=F, quote=F, sep="\t")
  
  ##################################################################
  # randomly sample L sites (genome-wide) and import data into R
  ##################################################################
  # data <- sapply(chrompad, function(x){ importdata(mafrange, chrompad=x, proband, set, thinby, expid, headersuffix) }, simplify=F)
  require(parallel)
  data <- mclapply(str_pad(1:18, 3, "left", "0"), function(chrompad){ importdata(mafrange, chrompad, proband, set, thinby, expid, headersuffix) },
                   mc.cores=ncores)
  data <- do.call(rbind, data)
  if(nrow(data)>L){ data <- data[sample(1:nrow(data), L, replace=F),] } else 
    # print(paste(proband, nrow(data), sep=": "))
  print(paste("Warning: L exceeds the number of available sites (", nrow(data), "). Decrease 'thinby' value or remove sample(s) with a large proportion(s) of missing data.", sep=""))
  
  af <- data$REF_FREQ; names(af) <- paste(data$CHROM, data$POS, sep="_")             # extract allele frequency information at sampled sites 
  
  data <- data[replicates]
  dimnames(data) <- list(names(af), gsub("[.]", ":", colnames(data)))
  
  detect = function(replicatenames, distance, datafile, eSEQ, AF, uniform){
    ## Import the data for the k (supposed) replicates.
    sample <- unlist(replicatenames, use.names=F)
    if(class(datafile)=="character"){ require(limma); X <- read.columns(datafile,  required.col=c("CHROM","POS", sample), sep="\t")
                                      rownames(X) <- paste(X$CHROM, X$POS, sep="_"); 
                                      X <- X[,-(1:2)] } else X <- datafile
    k <- ncol(X)
    L <- nrow(X)
    ## Remove sites where we observe "0,0" among all k replicates (i.e. complete missing case)
    completeNA <- ifelse(apply(X, 1, function(x){ length(grep("^0,0$", x)) })==k, T, F)
    X <- X[!completeNA,]
    
    ## We assume that sites are independent.
    ## We thin sites such that no two sites are within <distance> bp from one another. 
    if(distance>0){ sitenames <- thin(rownames(X), distance) } else 
      sitenames <- rownames(X)
    
    sitenames <- intersect(names(AF), sitenames)
    X <- as.matrix(X[sitenames, ])
    
    ## Compute the mean read depth and the proportion of missing data
    ## across the set of thinned sites for each sample.
    # statistics <- apply(X, 2, function(x){ y <- unlist(strsplit(x, ",")); mode(y) <- "numeric";
    #                                        return(c("meanDP"=mean(y), "percentNA"=length(grep("^0,0$",x))/length(x))) })
    
    ## Compute the mean read depth. The proportion of missing data across the thinned set of sites will be zero since 
    ## a site is sampled if >0 reads were observed at that site for EACH of the k samples.
    statistics <- apply(X, 2, function(x){ y <- unlist(strsplit(x, ",")); mode(y) <- "numeric";
                                           return(c("meanDP"=mean(y))) })
    
    
    ## Initialize the algorithm by defining a prior on S, such that
    ## P(S=s) = 1/k for s = {1,2,...,k}, where s denotes the total number
    ## of unique individuals from which the k (supposed) replicates derived.
    ## When assuming a uniform prior over S, we induce a prior on I.
    S <- enumerateI(k)
    reference <- enumerateG_revised(k, S)
    I <- names(reference[["P(G|I)"]])
    nS <- sapply(paste("s=",1:k,sep=""), function(s){ nrow(do.call(rbind, S[[s]])) })
    if(uniform=="onS"){ prior <- setNames(rep((1/k)/nS, nS), I) }
    if(uniform=="onI"){ prior <- setNames(rep((1/length(I)), length(I)), I) }
    
    ## Compute P(X(v)|G(v)=g), where g={AA,AB,BB} for all v and store these
    ## values in memory, eliminating the need to recompute P(X(v)|G(v)) at
    ## each iteration of the algorithm.
    likelihood <- apply(X, 1, function(x){ memory <- sapply(setNames(1:k, paste("d=",1:k,sep="")),
                                                            function(d){ L <- normGL(x[d],eSEQ,callthreshold=NA,coding="character");
                                                                         aa <- gsub("AA", L["AA"], reference[["G"]][,d]);
                                                                         ab <- gsub("AB", L["AB"], aa);
                                                                         bb <- gsub("BB", L["BB"], ab);
                                                                         mode(bb) <- "numeric"; return(bb) });
                                           apply(memory, 1, prod) })
    
    ## Define P(G(v)|I) as a function of (estimated) ALT frequency at site v.
    ## P(G(v)|I) is defined as the probability that the k samples have
    ## the labeled genotype vector G(v) = ( G(v)_1, G(v)_2, ..., G(v)_k )
    ## given that the k samples originate from identity vector I.
    
    #print("Define P(G(v)|I) as a function of (user-supplied) ALT frequency at site v.")
    
    step1 <- sapply(reference[["G|I"]], function(x) do.call(rbind, strsplit(x, ",")))
    step2 <- rapply(strsplit(gsub("I=","",I), ","), duplicated, how="list")
    step3 <- mapply(function(x,y){ y <- ifelse(y==F,T,F);
                                   z <- as.matrix(x[,y]); return(z) }, x=step1, y=step2)
    pB <- AF[sitenames]
    pB <- ifelse(pB==0, pB+0.001, pB)       # Add a small perturbation (+0.001) when ALT frequency is equal to 0.
    pB <- ifelse(pB==1, pB-0.001, pB)       # Add a small perturbation (-0.001) when ALT frequency is equal to 1.
    extension6 <- sapply(pB, simplify=F, function(v){ memory <- sapply(step3, function(i){ i[grep("AA", i)] <- (1-v)^2;
                                                                                           i[grep("AB", i)] <- 2*(1-v)*v;
                                                                                           i[grep("BB", i)] <- v^2;
                                                                                           mode(i) <- "numeric"; i <- apply(i, 1, prod);
                                                                                           return(i) });
                                                      memory <- mapply(function(x,y){names(x) <- y; return(x)}, x=memory, y=reference[["G|I"]]);
                                                      return(memory) })
    # likelihood stores P(X(v) | G(v))  
    # extension6 stores P(G(v) | I)
    
    ####################################################################################################
    ####################################################################################################
    ## Calculate the posterior probability of each identity vector.
    ####################################################################################################
    ####################################################################################################
    p <- prior
    logp <- log(p)
    
    a <- sapply(I, function(i){ sapply(sitenames, function(v){ sum(likelihood[names(extension6[[v]][[i]]), v]*extension6[[v]][[i]]) }) }) 
    b <- apply(a, 2, log)
    c <- apply(b, 2, function(x) sum(x, na.rm=T))
    
    # calculate in log space to avoid underflow
    lognum <- logden <- sapply(names(c), function(i){ c[i]+logp[i] }, USE.NAMES=F)
    
    #   sum of log probabilities: a + log(1+exp(b-a)) --OR-- a + log1p(exp(b-a))
    while(length(logden)>1){
      previous <- sample(logden, 2, replace=F)
      # a should be the larger (least negative) of the two operands
      a <- max(previous)
      b <- min(previous)
      updated <- a + log1p(exp(b-a)) 
      logden <- c(setdiff(logden, previous), updated)
    }
    p <- exp(lognum-logden)
    output <- list("replicatenames"=replicatenames, "pI"=p, "statistics"=statistics, "sitenames"=sitenames)
    return(output)
  }      
  
  replicatenames <- list(); replicatenames[[proband]] <- colnames(data)
  start <- proc.time()
  results <- detect(replicatenames, distance=0, datafile=data,                       # run detectv3-function.R
                    eSEQ=eUSER, AF=af, uniform="onI")
  end <- proc.time()-start
  if(missing(outprefix)){
    results.fn <- paste(proband, "_chrom", paste(chrom, collapse=","), "_L", nrow(data), "_maf", paste(mafrange, collapse=","), "_thinby", thinby, "_chanmethod.rds", sep="")
  } else results.fn <- paste(outprefix, ".rds", sep="")

  print(paste("Results are saved in Rds file ", results.fn, sep=""))
  saveRDS(list("results"=results, "runtime"=end), results.fn)
  # return(list("results"=results, "runtime"=end)) 
  return(results$pI)
}

example <- chanmethod(functionpath="/home/DB2/ariel/Rfunctions", 
                      chrom=1:18, 
                      eUSER=0.01, 
                      proband="I930134", 
                      aliases.fn="I930134_aliases.txt",
                      #namedatabase=as.matrix(read.delim("/home/DB2/ariel/rawmasterVCFnames.GBS_June_2016", header=FALSE, stringsAsFactors=FALSE))[-(1:9)],
                      mafrange=c(0.4,0.5), 
                      L=1000,
                      thinby=20000,
                      headersuffix="gbsheader",
                      ncores=3)