# R packages required on SGN websites

#removes older ones of duplicate packages
#installs new ones from CRAN, bioconductor, github
#in ~/cxgn/R_libs

#Leaves behind deps installed in site libraries ("/usr/local/lib/R/site-library:/usr/lib/R/site-library:/usr/lib/R/library")
#To avoid future version conflicts between deps installed in these libraries and 'cxgn/sgn/R_libs', you would be better off
#removing them manually.


#Set the env variable R_LIBS_USER in /etc/R/Renviron to '~/cxgn/R_libs' in your local system or to '/home/production/cxgn/R_libs' in the production servers. 
#This will ensure deps you manually install in R will be in the same place as sgn R libraries
#and avoid installation of the same R packages in multiple places.
#It will also add packages in the \"~/cxgn/R_libs\" to the search path";

rLibsUser <- unlist(strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep))
rLibsSite <- unlist(strsplit(Sys.getenv("R_LIBS_SITE"), .Platform$path.sep))
rLibsSgn  <- "~/cxgn/R_libs"
cranSite  <-  'http://mirror.las.iastate.edu/CRAN/'
cranFile  <- "~/cxgn/sgn/R_files/cran"
gitFile   <- "~/cxgn/sgn/R_files/github"
bioCFile  <- "~/cxgn/sgn/R_files/bioconductor"

preRLibsSgn <- grep(rLibsSgn, rLibsUser, perl=TRUE, value=TRUE)

if (!is.null(preRLibsSgn) || !file.exists(preRLibsSgn)) {
  dir.create(rLibsSgn, recursive = TRUE, showWarnings = TRUE)
}

if(!dir.exists(rLibsSgn))
{ 
    stop("SGN R Libs dir ", rLibsSgn, ' Does not exist and failed to create it.')   
} else {
  Sys.setenv(R_LIBS_USER=rLibsSgn) 
}

.libPaths(c(rLibsSgn, .libPaths()))

if (!require(stringr, lib.loc=rLibsSgn, quietly=TRUE, warn.conflicts=FALSE)) {
  install.packages('stringr', repos=cranSite)
  library(stringr)
}

if (!require(dplyr, lib.loc=rLibsSgn, quietly=TRUE, warn.conflicts=FALSE)) {  
  install.packages('dplyr', repos=cranSite)
  library(dplyr)
}

if (!require(devtools, lib.loc=rLibsSgn, quietly=TRUE, warn.conflicts=FALSE)) {
  install.packages('devtools', repos=cranSite)
  library(devtools)
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

        dupsDf <- dupsDf %>%
          filter(LibPath != lb) %>%
            data.frame
      
      } else if (v == 1)  {
        lb <- dupsDf[2, 'LibPath']
        message( 'removing older copy ', dN, ' from ', lb)
        remove.packages(dN, lib=lb)

        dupsDf <- dupsDf %>%
          filter(LibPath != lb) %>%
            data.frame

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
newGit  <- githubPacks[!githubPacks %in% insPacksUni]
newBioc <- biocPacks[!biocPacks %in% insPacksUni]

#stop('quit before install...')

if (length(newCran) > 0) {
  install.packages(newCran,
                   repos=cranSite,
                   quiet=TRUE,
                   verbose=FALSE,
                   dependencies=TRUE)
} else {
  message('No new cran packages to install.')
}

newGitPaths <- c()
if (!is.null(newGit)) {
 
  for (ng in newGit) {
    ngp <- grep(ng, githubPackPaths, value=TRUE)
    ifelse(is.null(newGitPaths), newGitPaths <- ngp,  newGitPaths <- c(newGitPaths, ngp))   
  }
}

if (length(newGitPaths) > 0) {
    withr::with_libpaths(new=rLibsSgn,
                         install_github(newGitPaths,
                                        force=TRUE,
                                        quiet=TRUE,
                                        verbose=FALSE,
                                        dependencies=TRUE))
} else {
  message('No new github packages to install.')
}


if (length(newBioc) > 0 ) {
    source('http://bioconductor.org/biocLite.R')
    biocLite(newBioc,
             suppressUpdates=TRUE,
             suppressAutoUpdate=TRUE,
             ask=FALSE,
             quiet=TRUE,
             verbose=FALSE,
             siteRepos=cranSite)
} else {
  message('No new bioconductor packages to install.')
}
