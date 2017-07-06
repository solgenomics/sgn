# R packages required on SGN websites

#removes older ones of duplicate packages
#installs new ones from CRAN, bioconductor, github
#in ~/cxgn/sgn/R_libs

## check if these pkgs installed first, if not install


rLibsUser <- unlist(strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep))
rLibsSite <- unlist(strsplit(Sys.getenv("R_LIBS_SITE"), .Platform$path.sep))
rLibsSgn  <- "~/cxgn/sgn/R_libs"
cranSite  <- 'http://lib.stat.cmu.edu/R/CRAN'
cranFile  <- "~/cxgn/sgn/R_files/cran"
gitFile   <- "~/cxgn/sgn/R_files/github"
bioCFile  <- "~/cxgn/sgn/R_files/bioconductor"

preRLibsSgn <- grep(rLibsSgn, rLibsUser, perl=TRUE, value=TRUE)
print('sgndirold')
print(preRLibsSgn)

if (!file.exists(preRLibsSgn) && !dir.create(rLibsSgn, recursive = TRUE, showWarnings = TRUE)) { 
    stop("SGN R Libs dir ", rLibsSgn, ' Does not exist and failed to create it.')
    
} else {
  Sys.setenv(R_LIBS_USER=rLibsSgn) 
}

.libPaths(c(rLibsSgn, .libPaths()))

if (!require(dplyr, lib.loc=rLibsSgn, quietly=TRUE, warn.conflicts=FALSE)) {
  install.packages('dplyr', repos=cranSite)
}

if (!require(stringr, lib.loc=rLibsSgn, quietly=TRUE, warn.conflicts=FALSE)) {
  install.packages('stringr', repos=cranSite)
}

if (!require(devtools, lib.loc=rLibsSgn, quietly=TRUE, warn.conflicts=FALSE)) {
  install.packages('devtools', repos=cranSite)
}


installedPackages <- function (..., lib.loc=NULL) {

  pks <- installed.packages(..., lib.loc=lib.loc)
  pks <- pks[, c('Package', 'LibPath', 'Version')]
  pks <- data.frame(pks, stringsAsFactors=FALSE)

}


duplicatedPackagesDf <- function(packagesDf) {

  dupPackages <- packagesDf %>%
    group_by(Package) %>%
      filter(n()>1) %>%
        arrange(Package) %>%
          data.frame()
  
  if (is.data.frame(dupPackages) == FALSE) {
    dupPackages <- NULL
  }
}


dupPackNames <- function(dupPackDf) {

  dupsNames <- c()
  if(!is.null(dupPackDf)) {
  if (is.data.frame(dupPackDf)) {
    dupsNames <- dupPackDf %>%
      select(Package) %>%
        distinct() %>%
          data.frame() 
 
    if (nrow(dupsNames) == 0) {
      dupsNames <- NULL
    } else {
      dupsNames <- dupsNames$Package
    }
  }
}
  return(dupsNames)
}


removeOlderPackages <- function (dupPackages) {

  dupNames <- dupPackNames(dupPackages)

  for (dN in dupNames) {
    dupsDf <- dupPackages %>%
      filter(Package == dN) %>%
        data.frame

    dupCnt <- nrow(dupsDf)    
        
    while (dupCnt > 1 ) {
      message('package ', dN, ' ', dupCnt, ' times duplicated')
      v <- compareVersion(dupsDf[1, 'Version'], dupsDf[2, 'Version'])
   
      if (v == 0) {
        lb <- dupsDf$LibPath[1]
        message( 'removing double copy ', dN, ' from ', lb)
        remove.packages(dN, lib=lb)
        dupsDf <- dupsDf %>% filter(LibPath != lb) %>% data.frame
      
      } else if (v == 1)  {
        lb <- dupsDf[2, 'LibPath']
        message( 'removing older copy ', dN, ' from ', lb)
        remove.packages(dN, lib=lb)

        print(dupsDf)
        dupsDf <- dupsDf %>%
          filter(LibPath != lb) %>%
            data.frame
          print(dupsDf)
      } else if (v == -1) {
        lb <- dupsDf[1, 'LibPath']
        message( 'removing older copy ', dN, ' from ', lb)
        remove.packages(dN, lib=lb)

        dupsDf <- dupsDf %>%
          filter(LibPath != lb) %>%
            data.frame
      }
    
      dupCnt <- nrow(dupsDf)
    }   
  } 
}


filterFilePackages <- function (depsF) {

  fP <- read.dcf(depsF, fields="Depends")
  fP <- unlist(strsplit(fP, ','))
  fP <- trimws(fP, 'both')
  fP <- gsub("\\s*\\(.*\\)", '', fP, perl=TRUE)
  fP <- fP[fP != 'R']
 
}



insPacks <- installedPackages(lib.loc=rLibsSgn)
dupPackages <- duplicatedPackagesDf(insPacks)
removeOlderPackages(dupPackages)

cranPacks       <- filterFilePackages(cranFile)
biocPacks       <- filterFilePackages(bioCFile)
githubPackPaths <- filterFilePackages(gitFile)
githubPacks     <- basename(githubPackPaths)

allReqPacks <-c(cranPacks, biocPacks, githubPacks)

insPacksUni <- unique(insPacks$Package)

newCran <- cranPacks[!cranPacks %in% insPacksUni]
newGit  <- githubPackPaths 
newBioc <- biocPacks[!biocPacks %in% insPacksUni]

#stop('quit before install...')
if (length(newCran) > 0) {
  install_cran(newCran,
               repos=cranSite)
}

if (length(newGit) > 0) {
    install_github(newGit)
}


if (length(newBioC) > 0 ) {
    source('http://bioconductor.org/biocLite.R')
    biocLite(newBioc,
             suppressUpdates=TRUE,
             suppressAutoUpdate=TRUE,
             ask=FALSE,
             siteRepos=cranSite)
}






