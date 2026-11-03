# Bounded synthetic software regressions, not scientific or field acceptance.
argv <- commandArgs(TRUE)
stopifnot(length(argv) == 2L)
root <- normalizePath(argv[1]); out <- normalizePath(argv[2])
source(file.path(root,"R/heritability/design_factors.R"))
groups <- strsplit(Sys.getenv("SGN_MODEL_TEST_GROUPS", "all"), ",", fixed=TRUE)[[1]]
run_group <- function(name) "all" %in% groups || name %in% groups
checks <- 0L
check <- function(value, message) {
  if (!isTRUE(value)) stop(message)
  checks <<- checks+1L
  cat("PASS:",message,"\n")
}
same <- function(a,b) isTRUE(all.equal(a,b,tolerance=1e-6,check.attributes=FALSE))
available <- function(packages, label) {
  missing <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
  if(length(missing)) cat("SKIP:",label,"missing packages",paste(missing,collapse=","),"\n")
  !length(missing)
}
write_input <- function(d,p) write.table(d,p,sep="\t",quote=FALSE,row.names=FALSE,na="NA")
execute <- function(script,args,wd,success=TRUE) {
  log<-file.path(wd,"execution.log")
  status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(root,script),args)),stdout=log,stderr=log)
  if ((status==0)!=success) {cat(readLines(log),sep="\n");stop("Unexpected owning-script status for ",script,": ",status)}
  checks <<- checks+1L
  invisible(status)
}
json <- function(p){x<-jsonlite::fromJSON(p);if(is.character(x)&&length(x)==1)x<-jsonlite::fromJSON(x);x}
balanced <- function(design="RCBD",environments=1L) {
  d<-expand.grid(germplasmName=paste0("G",1:8),replicate=1:3,locationName=paste0("E",seq_len(environments)),stringsAsFactors=FALSE)
  g<-as.integer(sub("G","",d$germplasmName));e<-as.integer(sub("E","",d$locationName))
  d$studyName<-paste0("Trial",e);d$studyYear<-2026;d$studyDesign<-design
  d$blockNumber<-if(design=="CRD")1L else d$replicate
  d$rowNumber<-rep(1:3,length.out=nrow(d));d$colNumber<-rep(1:8,each=3,length.out=nrow(d))
  d$observationUnitName<-paste0("P",seq_len(nrow(d)));d$plotNumber<-seq_len(nrow(d));d$entryType<-"test"
  d$Yield<-50+2*g+3*e+c(-6,8,-2)[d$replicate]+sin(seq_len(nrow(d))*1.91)*2+cos(g*e)*4
  d
}
renumber<-function(d){if(unique(d$studyDesign)=="CRD"){g<-match(d$germplasmName,unique(d$germplasmName));d$replicate<-((d$replicate+g)%%3)+1}else d$replicate<-c(8,1,19)[d$replicate];d}
design_fixture<-function(design){
  if(design %in% c("RCBD","CRD"))return(balanced(design))
  trt<-paste0("G",seq_len(if(design=="Alpha")12 else 16))
  book<-if(design=="Alpha")agricolae::design.alpha(trt,k=3,r=3,seed=20261102)$book else agricolae::design.lattice(trt,r=3,seed=20261102)$book
  rep_name<-if(design=="Alpha")"replication" else "r"
  d<-data.frame(germplasmName=as.character(book$trt),replicate=as.integer(as.character(book[[rep_name]])),blockNumber=book$block,studyDesign=design,locationName="E1",studyName="Trial1",studyYear=2026,stringsAsFactors=FALSE)
  check(all(table(d$germplasmName)==3),paste(design,"generated memberships"))
  d$rowNumber<-rep(1:6,length.out=nrow(d));d$colNumber<-rep(1:8,each=6,length.out=nrow(d));d$observationUnitName<-paste0("P",seq_len(nrow(d)));d$plotNumber<-seq_len(nrow(d));d$entryType<-"test"
  d$Yield<-50+as.integer(sub("G","",d$germplasmName))*2+c(-6,8,-2)[d$replicate]+as.numeric(factor(d$blockNumber))*.8+sin(seq_len(nrow(d))*1.91)*2
  d
}

# Design metadata must be explicit: occurrence labels never substitute for blocks.
crd<-prepare_heritability_design(balanced("CRD"))
check(!length(crd$fixed_terms),"CRD ignores accession occurrence numbers")
rcbd<-prepare_heritability_design(balanced())
check(is.factor(rcbd$data$.trialBlock),"RCBD actual blocks are categorical")
bad<-balanced();bad$studyDesign<-NULL
check(inherits(try(prepare_heritability_design(bad),silent=TRUE),"try-error"),"missing studyDesign is refused")
bad<-balanced();bad$blockNumber<-1
check(inherits(try(prepare_heritability_design(bad),silent=TRUE),"try-error"),"RCBD does not infer blocks from replicate occurrences")
bad<-balanced();bad$studyDesign[1]<-"CRD"
check(inherits(try(prepare_heritability_design(bad),silent=TRUE),"try-error"),"mixed study designs are refused")

if(run_group("h2") && available(c("lmerTest","agricolae","ltm","rjson","data.table","phenoAnalysis","dplyr","jsonlite"),"both actual H2 entrypoints")) {
  h2<-function(d,case,consumer="blup",success=TRUE,trait_name="Yield"){
    wd<-file.path(out,case);dir.create(wd);p<-file.path(wd,"phenotype_data.tsv")
    trait_header <- paste0(trait_name,"|CO_343:0000001")
    names(d)[names(d)=="Yield"]<-trait_header;write_input(d,p)
    if(consumer=="blup"){
      csv<-file.path(wd,"h2.csv");execute("R/heritability/h2_blup_rscript.R",c(p,gsub("[ /]",".",trait_name),file.path(wd,"h2.json"),csv,file.path(wd,"error.txt")),wd,success)
    }else{
      metadata<-file.path(wd,"metadata");writeLines(paste(setdiff(names(d),trait_header),collapse="\t"),metadata)
      ins<-file.path(wd,"input_files");writeLines(paste(p,metadata,"/heritability/example",sep="\t"),ins)
      csv<-file.path(wd,"h2_coefficients_table.tsv");outs<-file.path(wd,"output_files");writeLines(paste(csv,file.path(wd,"h2_coefficients_json.json"),sep="\t"),outs)
      execute("R/heritability/h2_rscript.R",c(ins,outs),wd,success)
    }
    if(success)if(consumer=="blup")read.csv(csv)else read.delim(csv)else NULL
  }
  library(lmerTest)
  for(design in c("RCBD","CRD","Alpha","Lattice")) {
    d<-design_fixture(design);p<-prepare_heritability_design(d)
    if(design %in% c("Alpha","Lattice"))check(is.factor(p$data$.trialReplicate)&&is.factor(p$data$.trialBlock),paste(design,"replicate and nested block factors"))
    # Independent corrected single-study reference: ordinary categorical block
    # formulas, not the shared helper or its contrast-generation implementation.
    reference_formula <- switch(design,
      CRD = Yield ~ 1 + (1|germplasmName),
      RCBD = Yield ~ factor(blockNumber) + (1|germplasmName),
      Yield ~ factor(replicate)/factor(blockNumber) + (1|germplasmName))
    reference <- lmer(reference_formula, data=d)
    vc <- as.data.frame(VarCorr(reference))
    vg <- vc$vcov[vc$grp=="germplasmName"][1];vr <- vc$vcov[vc$grp=="Residual"][1]
    expected <- c(Hert=round(vg/(vg+vr),3),Vg=round(vg,3),Vres=round(vr,3))
    for(consumer in c("blup","solgs")) {
      base<-h2(d,paste(design,consumer,"base",sep="_"),consumer)
      check(same(as.numeric(unlist(base[1,names(expected)],use.names=FALSE)),unname(expected)),paste(consumer,design,"matches independently specified categorical reference"))
      labels<-h2(renumber(d),paste(design,consumer,"labels",sep="_"),consumer)
      check(same(base,labels),paste(consumer,design,"H2 and variance output label invariance"))
    }
  }
  slash <- h2(balanced(),"trait_name_slash","blup",trait_name="Yield/plant")
  check(identical(slash$trait,"Yield plant"),"BLUP trait matching preserves the standard slash-to-dot request contract")
  # Independent multi-environment qualification of the actual shared fitter.
  # Known environment offsets must remain in the existing location component.
  library(lmerTest)
  for (design in c("RCBD","CRD","Alpha","Lattice")) {
    one <- design_fixture(design)
    multi <- do.call(rbind,lapply(1:3,function(e) {
      x<-one;x$locationName<-paste0("E",e);x$studyName<-paste0("Trial",e)
      x$observationUnitName<-paste0("E",e,"_",x$observationUnitName)
      x$Yield<-x$Yield+c(-25,0,30)[e]+sin(seq_len(nrow(x))*e)*.2;x
    }))
    prepared <- prepare_heritability_design(multi)
    if(length(prepared$fixed_terms)) {
      C <- as.matrix(prepared$data$.h2DesignEffects)
      check(all(vapply(split(seq_len(nrow(C)),prepared$data$.trialEnvironment),function(rows)max(abs(colSums(C[rows,,drop=FALSE])))<1e-10,logical(1))),paste(design,"balanced nested contrasts sum to zero within environment"))
      X <- model.matrix(~ .h2DesignEffects,data=prepared$data)
      check(qr(X)$rank==ncol(X),paste(design,"nested fixed design matrix has full rank"))
    } else X<-model.matrix(~1,data=prepared$data)
    Z<-model.matrix(~0+locationName,data=prepared$data)
    check(qr(cbind(X,Z))$rank-qr(X)$rank==2L,paste(design,"location contrasts remain identifiable"))
    base<-fit_heritability_trait(multi,"Yield",include_location=TRUE,include_year=TRUE)
    labels<-renumber(multi)
    if(design!="CRD") {
      blocks<-unique(labels$blockNumber)
      labels$blockNumber<-paste0("B",rev(seq_along(blocks)))[match(labels$blockNumber,blocks)]
    }
    changed<-fit_heritability_trait(labels,"Yield",include_location=TRUE,include_year=TRUE)
    check(max(abs(fitted(base$model)-fitted(changed$model)))<1e-5,paste(design,"multi-environment fit is label invariant"))
    # Qualified optimizer resolution, not a relaxed model/design contract:
    # RCBD relabelled fits differed by5.9e-5 in location variance while REML
    # differed4.5e-9 and fitted values1.5e-6. Tighter bobyqa reduced variance
    # delta further. Check every component relatively, objective and the
    # reported H2 coefficient; exact raw variance equality is not warranted.
    base_variance <- unlist(base[c("Vg","Ve","Vres")])
    changed_variance <- unlist(changed[c("Vg","Ve","Vres")])
    relative_delta <- max(abs(base_variance-changed_variance)/pmax(abs(base_variance),abs(changed_variance),1e-8))
    objective_delta <- abs(REMLcrit(base$model)-REMLcrit(changed$model))
    base_h2 <- round(base$Vg/sum(base_variance),3)
    changed_h2 <- round(changed$Vg/sum(changed_variance),3)
    cat("MULTI",design,"variance_relative_delta",relative_delta,"REML_delta",objective_delta,"H2",base_h2,changed_h2,"\n")
    check(relative_delta<1e-4 && objective_delta<1e-7 && base$Ve>10 && identical(base_h2,changed_h2),paste(design,"known location offsets retain an identifiable positive variance"))
    actual <- h2(multi,paste0("multi_environment_",design),"blup")
    # The file exports Ve rounded to2 decimals; its helper uses the same
    # qualified optimizer, while the phenotype table has text precision.
    check(abs(actual$Ve-base$Ve)/abs(base$Ve)<1e-4 && same(actual$Hert,base_h2),paste(design,"full BLUP entrypoint retains the original location-inclusive ratio"))
  }
  confounded <- balanced("CRD",3)
  confounded$studyYear <- 2023+as.integer(sub("E","",confounded$locationName))
  error <- try(fit_heritability_trait(confounded,"Yield",include_location=TRUE,include_year=TRUE),silent=TRUE)
  check(inherits(error,"try-error") && grepl("not identifiable",as.character(error)),"location/year confounding is explicitly refused")
  d<-balanced("CRD");d$Yield[d$germplasmName=="G1" & d$replicate!=1]<-NA
  check(same(h2(d,"eligibility_base","solgs"),h2(renumber(d),"eligibility_labels","solgs")),"solGS observed-record eligibility ignores maximum occurrence label")
  bad<-balanced();bad$studyDesign<-NULL
  h2(bad,"missing_design_blup","blup",FALSE);h2(bad,"missing_design_solgs","solgs",FALSE)
}

if((run_group("h2_order") || run_group("h2")) && available(c("ltm","rjson","data.table","phenoAnalysis","dplyr","lmerTest"),"solGS two-trait order invariance")) {
  wd<-file.path(out,"h2_trait_order");dir.create(wd)
  execute("t/unit/R/h2_trait_order.R",c(root,wd),wd)
}

if(run_group("stratification") && available(c("dplyr","tidyr","jsonlite"),"actual environment stratification")) {
  strat<-function(d,case){wd<-file.path(out,case);dir.create(wd);p<-file.path(wd,"phenotype.tsv");write_input(d,p);outputs<-file.path(wd,c("pairwise","groups","membership","ungrouped","summary","anova","message"));execute("R/environment_stratification.R",c(p,"Yield","0.05",outputs),wd);list(pairwise=json(outputs[1]),groups=json(outputs[2]),anova=json(outputs[6]))}
  d<-balanced("CRD",3);a<-strat(d,"strat_crd");b<-strat(renumber(d),"strat_occurrence")
  check(all(a$anova$design=="CRD"),"stratification honors explicit CRD")
  check(same(a$anova,b$anova)&&same(a$pairwise,b$pairwise),"stratification ignores accession-specific CRD occurrence renumbering")
  check(nrow(a$groups)>0 && all(grepl("2026",a$groups$years)),"stratification retains standard studyYear")
}

if(run_group("ammi") && available(c("agricolae","dplyr","tidyr","jsonlite","plyr"),"actual complete-block AMMI")) {
  ammi<-function(d,case,success=TRUE){wd<-file.path(out,case);dir.create(wd);p<-file.path(wd,"phenotype.tsv");write_input(d,p);outputs<-file.path(wd,c("result.json","graph.json","message.txt","summary.json"));execute("R/stability/ammi_script.R",c(p,"Yield","imput_no","ammi",outputs),wd,success);if(success)json(outputs[1])else readLines(outputs[3])}
  d<-balanced("RCBD",3);a<-ammi(d,"ammi_complete")
  z<-renumber(d);z$blockNumber<-c(8,1,19)[d$blockNumber]
  check(same(a,ammi(z,"ammi_labels")),"AMMI complete-block label invariance")
  reference<-with(d,agricolae::AMMI(locationName,germplasmName,blockNumber,Yield,console=FALSE))
  expected<-data.frame(location=reference$means$ENV,Accession=reference$means$GEN,means=reference$means$Yield)
  merged<-merge(a,expected,by=c("location","Accession"),suffixes=c(".actual",".reference"))
  check(nrow(merged)==nrow(expected)&&same(merged$means.actual,merged$means.reference),"AMMI output means match the independent actual complete-block estimator")
  message<-ammi(d[d$blockNumber==1,],"ammi_one",FALSE)
  check(any(grepl("at least two genuine",message)),"AMMI refuses one genuine block without synthetic duplication")
  message<-ammi(balanced("CRD",3),"ammi_crd",FALSE)
  check(any(grepl("CRD",message)),"AMMI explains unsupported CRD error estimator while GGE remains available")
}

if(run_group("spatial") && available(c("SpATS","spdep","dplyr"),"actual SpATS output identity")) {
  d<-expand.grid(colNumber=1:8,rowNumber=1:8);d$observationUnitName<-paste0("P",seq_len(nrow(d)));d$germplasmName<-paste0("G",((d$colNumber+3*d$rowNumber)%%8)+1);d$replicate<-rep(1:8,each=8);d$blockNumber<-d$replicate;d$plotNumber<-seq_len(nrow(d));d$Yield<-50+as.integer(sub("G","",d$germplasmName))*1.8+d$rowNumber*1.2+sin(d$colNumber)*2+cos(seq_len(nrow(d))*1.91)*1.5
  spats<-function(d,case){wd<-file.path(out,case);dir.create(wd);p<-file.path(wd,"phenotype.tsv");write_input(d,p);sel<-file.path(wd,"selection.tsv");write_input(data.frame(trait="Yield",quality="good data",Moran_pvalue=.01,spatial_correction_needed="YES"),sel);execute("R/Spatial_Correction.R",c(p,sel,"1","0","0.5","trait,quality,Moran_pvalue,spatial_correction_needed"),wd);x<-read.delim(paste0(p,".spatially_corrected"));x[order(x$observationUnitName),c("observationUnitName","Yield","Yield_spatially_corrected")]}
  a<-spats(d,"spats_base");b<-spats(d[c(seq(2,nrow(d),2),seq(1,nrow(d),2)),],"spats_reordered")
  check(same(a,b),"SpATS corrected values remain attached to the same plot IDs")
}
if(run_group("lme4") && available(c("lme4","emmeans","effects","stringr","dplyr"),"actual mixed-model genotype means")) {
  mixed<-function(d,case,model="replicate + (1|germplasmName)",success=TRUE){
    wd<-file.path(out,case);dir.create(wd);p<-file.path(wd,"phenotype.tsv");write_input(d,p)
    params<-file.path(wd,"params.R");writeLines(c('dependent_variables <- c("Yield")','fixed_factors <- c("replicate")','random_factors <- c("germplasmName")',paste0('model <- "',model,'"')),params)
    execute("R/mixed_models.R",c(paste0('datafile="',p,'"'),paste0('paramfile="',params,'"')),wd,success)
    if(!success)return(NULL)
    suffix<-if(grepl("1\\|germplasmName",model))".adjustedBLUPs" else ".adjustedBLUEs"
    read.delim(paste0(p,suffix))
  }
  d<-balanced();check(same(mixed(d,"mixed_base"),mixed(renumber(d),"mixed_block_labels")),"mixed-model adjusted genotype means ignore block reference ordering")
  mixed(d,"mixed_two_random","1 + (1|germplasmName) + (1|replicate)")
  interaction <- "replicate*colNumber + (1|germplasmName)"
  check(same(mixed(d,"mixed_interaction",interaction),mixed(renumber(d),"mixed_interaction_labels",interaction)),"mixed-model interaction means ignore block reference ordering")
  model<-"germplasmName + (1|replicate)";a<-mixed(d,"mixed_fixed_base",model)
  lookup<-setNames(paste0("H",8:1),paste0("G",1:8));d$germplasmName<-unname(lookup[d$germplasmName]);b<-mixed(d,"mixed_fixed_labels",model)
  b$germplasmName<-names(lookup)[match(b$germplasmName,lookup)];b<-b[order(b$germplasmName),]
  check(same(a,b),"fixed genotype BLUEs preserve genotype means under reference-label changes")
  mixed(balanced(),"unsupported_genotype_slope","replicate + (1+replicate|germplasmName)",FALSE)
}
if(run_group("sommer") && available(c("sommer","emmeans","stringr","dplyr"),"actual sommer and spl2D entrypoints")) {
  suppressPackageStartupMessages(library(sommer))
  sommer_engine<-function(d,case,engine="sommer",fixed_genotype=FALSE) {
    wd<-file.path(out,case);dir.create(wd);p<-file.path(wd,"phenotype.tsv");write_input(d,p)
    params<-file.path(wd,"params.R")
    random<-if(engine=="spl2D")"~ vsr(germplasmName) + vsr(locationDbId, Rowf) + vsr(locationDbId, Colf) + spl2Da(rowNumber,colNumber, at.var = locationDbId)" else "~ vsr(germplasmName)"
    fixed <- if(fixed_genotype)"Yield ~ germplasmName" else "Yield ~ replicate"
    if(fixed_genotype) random <- if(engine=="spl2D")"~ vsr(locationDbId, Rowf) + vsr(locationDbId, Colf) + spl2Da(rowNumber,colNumber, at.var = locationDbId)" else "~ vsr(replicate)"
    writeLines(c('dependent_variables <- c("Yield")','fixed_factors <- c("replicate")','random_factors <- c("germplasmName")',paste0('fixed_model <- "',fixed,'"'),paste0('random_model <- "',random,'"')),params)
    script<-if(engine=="spl2D")"R/mixed_models_spl2D.R" else "R/mixed_models_sommer.R"
    execute(script,c(paste0('datafile="',p,'"'),paste0('paramfile="',params,'"')),wd)
    x<-read.delim(paste0(p,if(fixed_genotype)".adjustedBLUEs" else ".adjustedBLUPs"),check.names=FALSE)
    check(ncol(x)==2L && names(x)[2]=="Yield" && nrow(x)==length(unique(d$germplasmName)),paste(engine,"outputs genotype IDs and selected trait schema"))
    names(x)[1]<-"germplasmName"
    if(!fixed_genotype) {
      raw<-read.delim(paste0(p,".BLUPs"),check.names=FALSE)
      check(identical(names(raw),c("germplasmName","Yield")),paste(engine,"raw BLUP schema retains selected trait units"))
      combined<-merge(x,raw,by="germplasmName",suffixes=c("_adjusted","_raw"))
      fixed_mean<-combined$Yield_adjusted-combined$Yield_raw
      check(length(fixed_mean)==nrow(x) && max(abs(fixed_mean-mean(fixed_mean)))<1e-5,paste(engine,"trait-unit BLUP plus marginal fixed mean equals adjusted genotype mean"))
    }
    x[order(x$germplasmName),]
  }
  d<-balanced();d$locationDbId<-1L
  check(same(sommer_engine(d,"sommer_base"),sommer_engine(renumber(d),"sommer_labels")),"sommer adjusted genotype means preserve replicate-label invariance")
  a<-sommer_engine(d,"sommer_fixed",fixed_genotype=TRUE)
  lookup<-setNames(paste0("H",8:1),paste0("G",1:8));z<-d;z$germplasmName<-unname(lookup[z$germplasmName])
  b<-sommer_engine(z,"sommer_fixed_labels",fixed_genotype=TRUE);b$germplasmName<-names(lookup)[match(b$germplasmName,lookup)];b<-b[order(b$germplasmName),]
  check(same(a,b),"sommer fixed genotype means preserve reference-label invariance")
  # Four complete16-genotype blocks, each covering two physical rows. Fixed
  # replicate does not consume every row contrast of the spatial random term.
  d<-expand.grid(colNumber=1:8,rowNumber=1:8);d$observationUnitName<-paste0("P",seq_len(nrow(d)))
  d$replicate<-((d$rowNumber-1)%/%2)+1
  d$germplasmName<-paste0("G",((d$colNumber-1+8*((d$rowNumber-1)%%2)+3*(d$replicate-1))%%16)+1)
  d$blockNumber<-d$replicate;d$plotNumber<-seq_len(nrow(d));d$studyYear<-2026;d$locationDbId<-1L;d$locationName<-"E1";d$studyName<-"Trial1";d$studyDesign<-"RCBD"
  check(all(table(d$germplasmName,d$replicate)==1),"spl2D fixture has16 genotypes once per actual block")
  d$Yield<-50+as.integer(sub("G","",d$germplasmName))*1.8+d$rowNumber*1.2+sin(d$colNumber)*2+cos(seq_len(nrow(d))*1.91)*1.5
  z<-d;z$replicate<-c(8,1,19,2)[z$replicate]
  check(same(sommer_engine(d,"spl2D_base","spl2D"),sommer_engine(z,"spl2D_labels","spl2D")),"spl2D adjusted genotype means preserve replicate-label invariance")
  source(file.path(root,"R/mixed_models_sommer_common.R"))
  for(fields in 1:2) {
    fields_data<-do.call(rbind,lapply(seq_len(fields),function(e){x<-d;x$locationDbId<-as.character(e);x$locationName<-paste0("E",e);x$observationUnitName<-paste0("E",e,"_",x$observationUnitName);x$Yield<-x$Yield+(e-1)*5;x}))
    fields_data$locationDbId<-factor(fields_data$locationDbId)
    legacy<-with(fields_data,sommer::spl2Dc(rowNumber,colNumber,at.var=locationDbId))
    prepared<-prepare_sommer_spline_basis(fields_data)
    basis<-prepared$basis;kernel<-prepared$kernel
    descriptor<-with(fields_data,vsm(dsm(locationDbId),ism(basis),Gu=kernel))
    delta<-max(abs(as.matrix(tcrossprod(do.call(cbind,legacy$Z))-tcrossprod(do.call(cbind,descriptor$Z)))))
    check(delta<1e-10,paste("spl2D public v2 descriptor preserves the exact",fields,"field covariance design kernel"))
    if(fields==2L) sommer_engine(fields_data,"spl2D_two_fields","spl2D")
  }
  a<-sommer_engine(d,"spl2D_fixed","spl2D",fixed_genotype=TRUE)
  lookup<-setNames(paste0("H",16:1),paste0("G",1:16));z<-d;z$germplasmName<-unname(lookup[z$germplasmName])
  b<-sommer_engine(z,"spl2D_fixed_labels","spl2D",fixed_genotype=TRUE);b$germplasmName<-names(lookup)[match(b$germplasmName,lookup)];b<-b[order(b$germplasmName),]
  check(same(a,b),"spl2D fixed genotype means preserve reference-label invariance")
}
cat("Completed",checks,"software checks. No scientific or field acceptance is claimed.\n")
