# AMMI's supplied agricolae estimator fits ENV + REP %in% ENV + GEN + ENV:GEN.
# It cannot estimate an unblocked CRD or an incomplete-block error term.
# GGE consumes genotype/environment means independently of replication tags.
prepare_stability_data <- function(pheno, trait, method, impute = FALSE) {
  needed <- c("germplasmName", "locationName", trait)
  if (!all(needed %in% names(pheno))) stop("Stability input is missing accession, environment or trait metadata.")
  if (!method %in% c("ammi","gge")) stop("Choose the supported AMMI or GGE analysis.")
  keep <- !is.na(pheno$germplasmName) & !tolower(pheno$germplasmName) %in% "filler"
  pheno <- pheno[keep,,drop=FALSE]
  assert_genotype_name_identity(pheno)
  raw <- data.frame(Gen=as.character(pheno$germplasmName),Env=as.character(pheno$locationName),Yield=pheno[[trait]],stringsAsFactors=FALSE)
  if (!is.numeric(raw$Yield)) stop("Stability analysis requires a numeric trait.")
  if (anyNA(raw$Env) || any(raw$Env == "")) stop("Stability analysis requires known environment labels.")
  if (length(unique(raw$Env)) < 2L || length(unique(raw$Gen)) < 2L) stop("Stability analysis requires at least two genotypes and environments.")
  missing_frequency <- mean(is.na(raw$Yield))
  summary <- data.frame(mean=mean(raw$Yield,na.rm=TRUE),min=min(raw$Yield,na.rm=TRUE),maxV=max(raw$Yield,na.rm=TRUE),sdV=sd(raw$Yield,na.rm=TRUE),missing=missing_frequency)
  if (missing_frequency >= .4) stop("The frequency of missing data is too high. Please check the dataset.")
  if (method == "ammi") {
    if (!"studyDesign" %in% names(pheno)) stop("AMMI requires declared studyDesign and recorded complete-block replication metadata.")
    designs <- unique(tolower(trimws(pheno$studyDesign)))
    if (anyNA(designs) || any(!grepl("^rcbd$|randomi[sz]ed complete block",designs))) stop("The supplied AMMI estimator supports replicated complete-block designs only; CRD, augmented and incomplete-block error terms are not supplied by this estimator. GGE means remain available.")
    if (!"blockNumber" %in% names(pheno)) stop("RCBD AMMI requires actual complete-block blockNumber metadata.")
    raw$Rep <- as.character(pheno$blockNumber)
    if (anyNA(raw$Rep) || any(raw$Rep == "")) stop("AMMI requires known recorded complete-block metadata; accession occurrence counters cannot replace it.")
    counts <- tapply(raw$Rep,raw$Env,function(x) length(unique(x)))
    if (any(counts < 2L)) stop("AMMI requires at least two genuine recorded replications in every environment; duplicated observations are not replications.")
    if (anyDuplicated(raw[,c("Gen","Env","Rep")])) stop("AMMI requires one observed genotype per complete-block replication; repeated records need explicit prior aggregation by physical observation unit.")
    tab <- table(raw$Gen,interaction(raw$Env,raw$Rep,drop=TRUE))
    if (any(tab != 1L)) stop("AMMI requires complete genotype-by-environment-by-recorded-replication cells.")
    if (impute) {
      # Preserve the original replication-aware mean-imputation route only for
      # actual complete blocks. No synthetic second replication is created.
      raw <- stability_mean_imputation(raw,c("Gen","Rep"))
    } else if (anyNA(raw$Yield)) stop("AMMI has missing observations; select imputation or supply complete observations.")
    raw$Gen <- factor(raw$Gen); raw$Env <- factor(raw$Env); raw$Rep <- factor(raw$Rep)
    return(list(observations=raw,model_data=raw,summary=summary,imputation_accuracy=NA_real_))
  }
  # Average repeated records of the same physical unit first when its identity
  # is supplied. Never use genotype x design-replicate as an individual ID.
  unit <- intersect(c("observationUnitDbId","observationUnitName"),names(pheno))
  mean_present <- function(x) if(all(is.na(x))) NA_real_ else mean(x,na.rm=TRUE)
  if(length(unit)) {
    raw$Unit <- as.character(pheno[[unit[1]]])
    if(anyNA(raw$Unit) || any(raw$Unit == "")) stop("Provided observation-unit identities must be complete.")
    raw <- aggregate(Yield ~ Gen + Env + Unit,raw,mean_present,na.action=na.pass)
  }
  means <- aggregate(Yield ~ Gen + Env,raw,mean_present,na.action=na.pass)
  grid <- expand.grid(Gen=unique(raw$Gen),Env=unique(raw$Env),stringsAsFactors=FALSE)
  means <- merge(grid,means,by=c("Gen","Env"),all.x=TRUE,sort=FALSE)
  missing_cells <- sum(is.na(means$Yield))
  accuracy <- NA_real_
  if(impute) {
    # Validate the same environment-mean algorithm on held-out observed cells;
    # imputed values are never used as ground truth for reported accuracy.
    held <- integer()
    if(missing_cells) for(env in unique(means$Env)) {
      candidates <- which(means$Env == env & !is.na(means$Yield))
      n <- min(length(candidates)-1L,max(1L,round(length(candidates)*missing_cells/nrow(means))))
      if(n > 0L) held <- c(held,sample(candidates,n))
    }
    if(length(held) >= 2L) {
      control <- means; control$Yield[held] <- NA_real_
      predicted <- stability_mean_imputation(control,"Gen")
      key <- function(d) paste(d$Gen,d$Env,sep="\r")
      y <- predicted$Yield[match(key(means)[held],key(predicted))]
      if(sd(y)>0 && sd(means$Yield[held])>0) accuracy <- cor(means$Yield[held],y)
    }
    means <- stability_mean_imputation(means,"Gen")
  } else if(missing_cells) stop("GGE requires genotype-by-environment means for every cell; select mean imputation for missing cells.")
  summary$imputation_unit <- "genotype_environment_mean"
  summary$imputation_method <- if(impute) "environment_mean (mice mean)" else "none"
  summary$observed_cells <- nrow(means)-missing_cells
  summary$imputed_cells <- if(impute) missing_cells else 0L
  list(observations=raw,model_data=means,summary=summary,imputation_accuracy=accuracy)
}

stability_mean_imputation <- function(data, identity_columns) {
  # Anonymous environment columns avoid altering labels containing spaces/dots.
  envs <- unique(as.character(data$Env))
  aliases <- paste0("environment",seq_along(envs))
  input <- data[,c(identity_columns,"Env","Yield"),drop=FALSE]
  input$Env <- aliases[match(input$Env,envs)]
  wide <- tidyr::pivot_wider(input,names_from="Env",values_from="Yield")
  values <- as.data.frame(wide[,aliases,drop=FALSE])
  if(any(vapply(values,function(x) all(is.na(x)),logical(1)))) stop("Mean imputation cannot estimate an environment with no observed genotype means.")
  if(anyNA(values)) {
    fit <- mice::mice(values,method="mean",m=3,maxit=10,predictorMatrix=matrix(0,ncol(values),ncol(values)),remove.constant=FALSE,remove.collinear=FALSE,printFlag=FALSE)
    values <- mice::complete(fit,1)
  }
  wide[,aliases] <- values
  result <- as.data.frame(tidyr::pivot_longer(wide,cols=tidyr::all_of(aliases),names_to="Env",values_to="Yield"))
  result$Env <- envs[match(result$Env,aliases)]
  result
}
