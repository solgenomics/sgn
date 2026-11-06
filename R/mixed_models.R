# Load the explicit analytical recorded-design-tag contract.
design_source <- NULL
for (frame in sys.frames()) if (!is.null(frame$ofile)) design_source <- frame$ofile
if (is.null(design_source)) {
  invocation <- commandArgs()
  file_option <- grep("^--file=", invocation, value = TRUE)
  if (length(file_option)) {
    design_source <- sub("^--file=", "", file_option[1])
  } else {
    file_index <- which(invocation %in% c("-f", "--file"))
    if (length(file_index) && file_index[1] < length(invocation)) design_source <- invocation[file_index[1] + 1L]
  }
}
if (is.null(design_source) || is.na(design_source) || !nzchar(design_source)) stop("Cannot locate the owning R script; use Rscript, R -f, or source().")
source(file.path(dirname(normalizePath(design_source)), "design_replication.R"), local = TRUE)

## File was edited in ESS mode in emacs and some indents changed. sorry.
##First read in the arguments listed at the command line
args=commandArgs(TRUE)

##args is now a list of character vectors
## First check to see if arguments are passed.
## Then cycle through each element of the list and evaluate the expressions.

if(length(args)==0){
    print("No arguments supplied.")
    ##supply default values
    datafile=''
    paramfile=''
    fixed_factors<-c()
    random_factors<-c()
    
} else {
    for(i in 1:length(args)){
        print(paste("Processing arg ", args[[i]]));
        eval(parse(text=args[[i]]))
    }
}


workdir = dirname(datafile);
setwd(workdir);

library(lme4)
#library(lmerTest)
library(emmeans)
library(effects)
library(stringr)
library(dplyr)

pd <- with_design_replication(read_analysis_phenotypes(datafile, check.names = TRUE))

source(paramfile)  # should give us dependent_variable and the model

trait = dependent_variables
pd$studyYear = as.factor(pd$studyYear)
pd$designReplicate <- factor(pd$designReplicate)
if ("blockNumber" %in% names(pd)) pd$blockNumber <- factor(pd$blockNumber)
print(paste("MODEL :", model))
print(paste("FIXED FACTORS: ", fixed_factors));
print(paste("RANDOM FACTORS: ", random_factors));
print(head(pd))

model_output_error <- function(message) {
    writeLines(message, paste0(datafile, ".model_error"))
    stop(message)
}

tryCatch(assert_genotype_name_identity(pd),
         error = function(e) model_output_error(conditionMessage(e)))

BLUE = as.data.frame(unique(pd$germplasmName))
colnames(BLUE) = "germplasmName"
adjustedBLUE = BLUE

BLUP = BLUE
adjusted_means = BLUE

for(i in 1:length(trait)){

    print(paste("processing trait", trait[i]))
    dependent_variables = trait[i]
    dependent_variables = gsub(" ", "\\.", dependent_variables) # replace space with "." in variable name
    dependent_variables = gsub("\\|", "\\.", dependent_variables) # replace | with .
    dependent_variables = gsub("\\:", "\\.", dependent_variables)
    dependent_variables = gsub("\\-", "\\.", dependent_variables)
    dependent_variables = gsub("\\/", "\\.", dependent_variables)
    
    print(paste("Dependent variables : ", dependent_variables))
    
    model_string = paste(dependent_variables, '~', model)
    
    print(paste('MODEL STRING:', model_string));
    #mixmodel = lmer(as.formula(model_string), data=pd)
    
    #model_summary = summary(allEffects(model,se=T))
    
    #pdout = model
    #print(pdout)
    
    model_formula <- canonical_design_formula(as.formula(model_string), pd)
    tryCatch(validate_design_group_terms(model_formula, pd),
             error = function(e) model_output_error(conditionMessage(e)))
    genotype_bars <- Filter(function(term) identical(as.character(term[[3]]), "germplasmName"), lme4::findbars(model_formula))
    fixed_genotype <- "germplasmName" %in% all.vars(lme4::nobars(model_formula))
    if (length(genotype_bars)) {
        if (fixed_genotype || length(genotype_bars) != 1L || !identical(as.character(genotype_bars[[1]][[2]]), "1")) {
            model_output_error("Genotype output supports either fixed germplasmName effects or one random genotype intercept; genotype random slopes and simultaneous fixed/random genotype terms are not supported.")
        }
        genotypeEffectType <- "random"
    } else if (fixed_genotype) {
        genotypeEffectType <- "fixed"
    } else {
        model_output_error("Select germplasmName as a fixed factor or a random intercept to obtain genotype means.")
    }

    mixmodel <- if (length(lme4::findbars(model_formula))) lmer(model_formula, data = pd) else lm(model_formula, data = pd)
    if (genotypeEffectType == "random") {
        # BLUPs remain genotype random-intercept deviations. Adjusted means add
        # the standard marginal fixed mean, not a reference-level intercept.
        res <- ranef(mixmodel)$germplasmName
        blup <- data.frame(germplasmName = rownames(res), estimate = res[["(Intercept)"]])
        names(blup)[2] <- trait[i]
        marginal <- as.data.frame(emmeans::emmeans(mixmodel, ~ 1))
        mean_column <- intersect(c("emmean", "lsmean"), names(marginal))
        if (length(mean_column) != 1L || nrow(marginal) != 1L || !is.finite(marginal[[mean_column]][1])) {
            model_output_error("The selected model does not provide an estimable marginal fixed mean for genotype output.")
        }
        adjusted <- blup
        adjusted[[trait[i]]] <- adjusted[[trait[i]]] + marginal[[mean_column]][1]
        BLUP <- merge(BLUP, blup, by = "germplasmName", all = TRUE)
        adjusted_means <- merge(adjusted_means, adjusted, by = "germplasmName", all = TRUE)
    } else {
        # Fixed genotype BLUEs use the same standard marginal-means calculation
        # as the existing adjusted-BLUE interface, with stable genotype identity.
        marginal <- as.data.frame(emmeans::emmeans(mixmodel, ~ germplasmName))
        mean_column <- intersect(c("emmean", "lsmean"), names(marginal))
        if (length(mean_column) != 1L || any(!is.finite(marginal[[mean_column]]))) {
            model_output_error("The selected model does not provide estimable fixed genotype means.")
        }
        blue <- marginal[, c("germplasmName", mean_column), drop = FALSE]
        names(blue)[2] <- trait[i]
        BLUE <- merge(BLUE, blue, by = "germplasmName", all = TRUE)
        adjustedBLUE <- merge(adjustedBLUE, blue, by = "germplasmName", all = TRUE)
    }

}

# save result files
#
# for random effects: file.BLUPs and file.adjustedBLUPs
# for fixed effects: file.BLUEs and file.adjustedBLUEs
#
if (genotypeEffectType=="random") {
    outfile_blup = paste(datafile, ".BLUPs", sep="");
    sink(outfile_blup)
    write.table(BLUP, quote=F, sep='\t', row.names=FALSE)
    sink();
    outfile_adjmeans = paste(datafile, ".adjustedBLUPs", sep="")
    sink(outfile_adjmeans)
    write.table(adjusted_means, quote=F , sep='\t', row.names=FALSE)
    sink();
  
} else {   #fixed
    outfile_blue = paste(datafile, ".BLUEs", sep="")
    sink(outfile_blue)
    write.table(BLUE, quote=F , sep='\t', row.names=FALSE)
    sink();
    outfile_adjblues = paste(datafile, ".adjustedBLUEs", sep="")
    sink(outfile_adjblues)
    write.table(adjustedBLUE, quote=F , sep='\t', row.names=FALSE)
    sink();
}