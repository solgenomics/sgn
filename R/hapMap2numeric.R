hapMap2numeric <- function(file){
  hapmap <- as.matrix(read.table(file, header=TRUE, row.names=1, sep="\t",
                                 stringsAsFactors=FALSE)[,-(2:10)])
  
  samples <- dimnames(hapmap)[[2]][-1]
  loci <- dimnames(hapmap)[[1]]
  
  #make sure sites are biallelic
  siteCheck <- names(table(hapmap[ ,1]))
  if(sum(grepl("/", siteCheck)) != length(siteCheck)){
    stop("There appear to be monomorphic sites in your file. Please remove them.")
  }
  
  siteCheck2 <- strsplit(siteCheck, "/")
  siteCheck2 <- unlist(lapply(siteCheck2, length))
  siteCheck2 <- siteCheck2 == 2
  if(sum(siteCheck2) != length(siteCheck2)){
    stop("There appear to be sites with more than two allele states in your file.
         Please allow a maximum of two alleles per site in your file.")
  }
  
  
  #check whether the file uses IUPAC coding or double letters
  nFor <- nchar(hapmap[1, 2])
  
  
  #use the appropriate conversions
  if(nFor == 2){
    # set up conversion table
    s <- as.integer(c(0,1,1,2,NA))
    ac <- s
    ag <- s
    at <- s
    cg <- s
    ct <- s
    gt <- s
    cx <- s
    gx <- s
    tx <- s
    ax <- s
    names(ac) <- c("AA","AC","CA","CC","NN")
    names(ag) <- c("AA","AG","GA","GG","NN")
    names(at) <- c("AA","AT","TA","TT","NN")
    names(cg) <- c("CC","CG","GC","GG","NN")
    names(ct) <- c("CC","CT","TC","TT","NN")
    names(gt) <- c("GG","GT","TG","TT","NN")
    names(cx) <- c("CC","C-","-C","--","NN")
    names(gx) <- c("GG","G-","-G","--","NN")
    names(tx) <- c("TT","T-","-T","--","NN")
    names(ax) <- c("AA","A-","-A","--","NN")
    conv <- list(ac,ac,ag,ag,at,at,cg,cg,ct,ct,gt,gt,cx,cx,gx,gx,tx,tx,ax,ax)
    names(conv) <- c("A/C","C/A","A/G","G/A","A/T","T/A","C/G","G/C",
                     "C/T","T/C","G/T","T/G","C/-","-/C","G/-","-/G","T/-","-/T","A/-","-/A")
  }
  
  if(nFor == 1){
  # set up conversion table
  s <- as.integer(c(0,1,2,NA))
  ac <- s
  ag <- s
  at <- s
  cg <- s
  ct <- s
  gt <- s
  cx <- s
  gx <- s
  tx <- s
  ax <- s
  names(ac) <- c("A","M","C","N")
  names(ag) <- c("A","R","G","N")
  names(at) <- c("A","W","T","N")
  names(cg) <- c("C","S","G","N")
  names(ct) <- c("C","Y","T","N")
  names(gt) <- c("G","K","T","N")
  names(cx) <- c("C","0","-","N")
  names(gx) <- c("G","0","-","N")
  names(tx) <- c("T","0","-","N")
  names(ax) <- c("A","0","-","N")
  conv <- list(ac,ac,ag,ag,at,at,cg,cg,ct,ct,gt,gt,cx,cx,gx,gx,tx,tx,ax,ax)
  names(conv) <- c("A/C","C/A","A/G","G/A","A/T","T/A","C/G","G/C",
                   "C/T","T/C","G/T","T/G","C/-","-/C","G/-","-/G","T/-","-/T","A/-","-/A")
  }
  
  # matrix to hold output
  x <- matrix(NA, nrow=length(samples), ncol=length(loci),
              dimnames=list(samples, loci))
  # convert genotypes
  for(L in 1:length(loci)){
    thisconv <- conv[[hapmap[L, 1]]]
    x[,L] <- thisconv[hapmap[L, -1]]
  }
  
  return(x)
}
