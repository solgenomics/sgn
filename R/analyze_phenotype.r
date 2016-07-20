.table package 
fread function.
###
# test ANOVA & BLUP cassava data
###

library(Matrix)
library(lme4)
#library(reshape2)
library(tidyr)
library("GGally")
require(utils)


setwd('/Users/guillaume/Desktop/ANOVA_BLUP')
setwd('/Users/guillaume/Desktop')

rm(list=ls())
pheno_data = read.table("phenotype_download_file.txt", sep="\t", header=T)
#cassava = read.table("pairs_input_cassava.txt", sep="\t", header=T)

# check data input
dim(pheno_data)
head(pheno_data)
str(pheno_data)
summary(pheno_data)
names(pheno_data)
rownames(pheno_data)
attach(pheno_data)
pheno_data = as.data.frame(pheno_data)
pheno_data = na.omit(pheno_data)


############################################
## plot multiple histograms and correlation: typically to see variation between blocks and experiments or years/locations
############################################

#pheno_data = subset(pheno_data[,2:15])

# set variables as factors
pheno_data$stock_name <- factor(pheno_data$stock_name)
pheno_data$year <- factor(pheno_data$year)
pheno_data$block_number <- factor(pheno_data$block_number)


# from long to wide file format, including trial as var : get all vectors the same length

#for traits
pheno_data_wide <- spread(pheno_data,trait, value)
dim(pheno_data_wide)

pheno_data_wide$location <- factor(pheno_data_wide$location)
pheno_data_wide$year <- factor(pheno_data_wide$year)
pheno_data_wide$block_number <- factor(pheno_data_wide$block_number)
length(pheno_data$location)


################
rm(list=ls())

testdtf <- read.table("test_dtf.txt", sep="\t", header=T)
testdtf_lg <- read.table("test_dtf_lg.txt", sep="\t", header=T)

#factors levels
fact_levels <- data.frame(location = length(unique(pheno_data$location)),  year = length(unique(pheno_data$year)),  block = length(unique(pheno_data$block_number)), trait = length(unique(pheno_data$trait)), rep = length(unique(pheno_data$rep)))

#number lines
length(unique(pheno_data$location))*length(unique(pheno_data$year))*length(unique(pheno_data$block_number))*length(unique(pheno_data$trait))*length(unique(pheno_data$rep))

# plot_names are unique, can t be used as factor, stock_name are better but not always unique within an elementary unit (a block from a trial in a location in a year), ex:
#2010 10uyt22ictMK TMEB419 Mokwa cassava bacterial blight incidence 6-month evaluation 1 2011-uyt22ictMK-rep4-TMEB419a CO CO:0000179 4 4
#2010 10uyt22ictMK TMEB419 Mokwa cassava bacterial blight incidence 6-month evaluation 1 2011-uyt22ictMK-rep4-TMEB419b CO CO:0000179 4 4
# need to extract accession name from plot name : TMEB419a and TMEB419b here (split on third "-").

stock_from_plot_name <- data.frame(do.call('rbind', strsplit(as.character(pheno_data$plot_name),"\\d{4}-[\\s\\S]+-[a-z]{3}\\d-",perl=TRUE)))
colnames(stock_from_plot_name)[2] <- "stock_from_plot_name"
pheno_data_tot <-cbind(pheno_data, stock_from_plot_name[2])

project_name <- unique(pheno_data_tot$project_name)
trait <- unique(pheno_data_tot$trait)
year <- unique(pheno_data_tot$year)
location <- unique(pheno_data_tot$location)
block <- unique(pheno_data_tot$block_number)
rep <- unique(pheno_data_tot$rep)
stock <- unique(pheno_data_tot$stock_name)
stock_name_from_plot_name <- unique(pheno_data_tot$stock_name_from_plot_name)

fulldtf <- setNames(expand.grid(project_name,trait,year,location,rep,block,stock),c("project_name","trait","year","location","rep","block_number","stock_name"))
fulldtf <- setNames(expand.grid(trait,year,location,rep,block,stock_name_from_plot_name),c("trait","year","location","rep","block_number","stock_name_from_plot_name"))
dim(fulldtf)

completedtf <- merge(fulldtf, pheno_data_tot, all=TRUE, by=intersect(names(fulldtf), names(pheno_data_tot)))
dim(completedtf)

write.table(completedtf, file ="test_full_data6-1-15_v3.txt", sep="\t", col.names=T, row.names=T)

write.table(fulldtf, file ="temp2.txt", sep="\t", col.names=T, row.names=T)


# melt function with spread.

#################



# edit trait names to make them syntactically valid (I.e: space conflict with ggplot2)
names(pheno_data_wide) <- make.names(names(pheno_data_wide))
write.table(pheno_data_wide, file= "pheno_data_wide_traits_out.txt", sep="\t")
# for blocks
pheno_data_wide2 <- spread(pheno_data,project_name, value)
dim(pheno_data_wide2)
write.table(pheno_data_wide2, file= "pheno_data_wide_out.txt", sep="\t")

# from wide to long , back to the inital format once vectors have been normalized
pheno_data_wide2 = read.table("pheno_data_wide_out.txt", sep="\t", header=T)
pheno_data_long <- gather(pheno_data_wide2, trial, trait, T10uyt22ictMK:T10uyt22ictZA)
write.table(pheno_data_long, file= "pheno_data_long_out.txt", sep="\t")
#ex of output
#  year         stock_name location                                                 trait                               plot_name cv_name cvterm_accession rep block_number 10uyt22ictMK 10uyt22ictWR 10uyt22ictZA
#1 2010 IITA-TMS-IBA000338    Mokwa cassava bacterial blight incidence 6-month evaluation 2011-uyt22ictMK-rep1-IITA-TMS-IBA000338      CO       CO:0000179   1            1          1.0           NA           NA

# same using reshape
#pheno_data_wide2  <- lapply(pheno_data_wide2[11:ncol(pheno_data_wide2)], factor)
#pheno_data_long2 <- melt(pheno_data_wide2, id.vars=c("T10uyt22ictMK","T10uyt22ictWR","T10uyt22ictZA"), factorAsStrings=F)
#dim(pheno_data_long2)

# check trait name syntax
tidy.name.vector <- make.names(name.vector, unique=TRUE)
pheno_data <- make.names(pheno_data$trait)


mydf <- data.frame(subject, grp, time, outcome)


## use the long format input


#### get all factor combinations for year, loc,trait , block
# Create an index of the different combination of trait, year, location and design variables: concatenate year,loc, block, trait in a unique string and add it to dataframe
# get all factor combinations for year, loc, trait, block and rep
# combination <- expand.grid(location = unique(pheno_data$location),  year = unique(pheno_data$year),  block = unique(pheno_data$block_number), trait = unique(pheno_data$trait)  )
combination <- expand.grid(location = unique(pheno_data$location),  year = unique(pheno_data$year),  block = unique(pheno_data$block_number), trait = unique(pheno_data$trait), rep = unique(pheno_data$rep))
head(combination)

# Add a uniquename to the combination
#combination$name <- with(combination, paste(trait,location,year,block,rep, sep="_"))
combination$name <- with(combination, paste(trait,location,year,block,rep, sep="_"))

#with(pheno_data, pheno_data[order("trait", "year","location", "block_number","trait", "rep"),])

# plot for each factor combinations
my.data.frame.tot = NULL

#rownumber <- nrow(combination)
# library(plyr)
# obj1 <- as.data.frame(cbind(rownames(my.data.frame1), my.data.frame1$value))
# obj2 <- as.data.frame(cbind(rownames(my.data.frame2), my.data.frame2$value))
# testcombined <- rbind.fill(my.data.frame1[c(rownames(my.data.frame1), my.data.frame1$value)], my.data.frame2[c(rownames(my.data.frame2), my.data.frame2$value)])
# testcombined <- rbind.fill.matrix(obj1, obj2)
# testcombined.tot <- rbind.fill.matrix(testcombined.tot, testcombined)


#  year project_name         stock_name location                                                 trait                               plot_name cv_name cvterm_accession rep  1   2  3  4
# 1 2010 10uyt22ictMK IITA-TMS-IBA000338    Mokwa cassava bacterial blight incidence 6-month evaluation 2011-uyt22ictMK-rep1-IITA-TMS-IBA000338      CO       CO:0000179   1  1  NA NA NA
# get subset iteratively
#my.data.frame <- subset(pheno_data_wide, pheno_data_wide$year == combination$year[j] & pheno_data_wide$location == combination$location[j] & pheno_data_wide$trait == combination$trait[j], i)



# get a balanced subset of the trial subsetting on year, location, trait
my.data.frame <- subset(pheno_data, pheno_data$year == combination$year[j] & pheno_data$location == combination$location[j] & pheno_data$trait == combination$trait[j], select= c(year, location, trait, rep, block_number, value))
# year, trait
my.data.frame <- subset(pheno_data, pheno_data$year == combination$year[j] & pheno_data$trait == combination$trait[j], select= c(year, location, trait, rep, block_number, value))
# year, location only
my.data.frame_loc <- subset(pheno_data, pheno_data$year == combination$year[j] & pheno_data$location == combination$location[j], select= c(year, location,trait, rep, block_number, value))
##produce the long format for traits in specific year-location
# make rows unique by adding an extra variable
my.data.frame_loc$row <- 1:nrow(my.data.frame_loc)
pheno_data_wide3 <- spread(my.data.frame_loc,trait, value)
dim(pheno_data_wide3)
names(pheno_data_wide3) <- make.names(names(pheno_data_wide3))
write.table(pheno_data_wide3, file= "pheno_data_wide_out_loc.txt", sep="\t")


#my.data.frame_1[give the trait name] <- subset(pheno_data_wide, pheno_data_wide$year == combination$year[i] & pheno_data_wide$location == combination$location[i]) & pheno_data_wide$block == combination$block[i] & pheno_data_wide$rep == combination$rep[i])





# write output
write.table(my.data.frame, file= "subset_test_pheno_data_wide_out.txt", sep="\t")
head(pheno_data_wide)

### plot pairs histo
pm <- ggpairs(my.data.frame, columns = c("location", "block_number", "value"),lower = list(continuous = "smooth",combo = "facetdensity",mapping = aes(color = location) ))
pm <- ggpairs(my.data.frame, columns = c("location", "block_number", "value"),mapping = aes(color = location))
pm <- ggpairs(pheno_data_wide2, columns=10:12,mapping = aes(color = location))
pm <- ggpairs(iris[, 1:4], lower=list(continuous="smooth", params=c(colour="blue")),diag=list(continuous="bar", params=c(colour="blue")), upper=list(params=list(corSize=6)), axisLabels='show')

pm <- ggpairs(iris[, 1:4], lower=list(continuous="smooth", params=c(colour="blue")),diag=list(continuous="bar", params=c(colour="blue")), upper=list(params=list(corSize=6)), axisLabels='show')


ggpairs(pheno_data[,c("value","block_number")], lower=list(continuous= wrap("smooth", params=c(colour="blue")),diag=list(continuous=wrap("barDiag", params=c(colour="blue"))), upper=list(params=wrap(list(corSize=6))), axisLabels='show'))

## create function to change regression methods
my_fn <- function(data, mapping, method="loess", ...){
      p <- ggplot(data = data, mapping = mapping) + 
      geom_point() + 
      geom_smooth(method=method, ...)
      p
    }

# plot using loess
ggpairs(swiss[1:4], lower = list(continuous = my_fn))
ggpairs(swiss[1:4], lower=  list(continuous= wrap("smooth", colour="blue")))
ggpairs(swiss[1:4], lower = list(continuous = wrap(my_fn, method="lm")))

ggpairs(pheno_data[,c("value","block_number")], lower=list(continuous= wrap("smooth", params=c(colour="blue"))), )
ggpairs(pheno_data[,c("value","location")], lower=list(continuous= wrap("smooth", colour="blue")))
ggpairs(pheno_data_wide[,c(10:ncol(pheno_data_wide))], lower=list(continuous= wrap("smooth", colour="blue")),diag=list(continuous=wrap("barDiag", colour="blue")))
ggpairs(pheno_data_wide3[,c(10:15)], lower=list(continuous= wrap("smooth", colour="blue")),diag=list(continuous=wrap("barDiag", colour="blue")))
ggpairs(pheno_data_wide3[,c(10:15)],lower=list(continuous= wrap("smooth", colour="blue")))


ggpairs(swiss[1:4], lower=list(continuous= wrap("smooth", colour="blue")),diag=list(continuous=wrap("barDiag", colour="blue")))
ggpairs(swiss[1:4], lower=list(continuous= wrap("smooth", colour="blue"))) # no pb
ggpairs(swiss[1:4],diag=list(continuous=wrap("barDiag", colour="blue")))  # pb


upper=wrap_fn_with_param_arg(list(corSize=6))
#plot using linear reg




,upper=list(params=(list(corSize=6)), axisLabels='show'))




i = NULL
for (i in 2:nrow(combination))
{
# extract subsets according to combination of year, location and traits   
my.data.frame <- subset(pheno_data, pheno_data$year == combination$year[i] & pheno_data$location == combination$location[i] & pheno_data$trait == combination$trait[i] & pheno_data$value)
data.frame.sub = as.data.frame(my.data.frame[,6])
names(data.frame.sub) = combination$name[i]
data.tot <- cbind(data.frame.sub, )
#assign(paste("trait",i,sep=""), trait_values)
trait_values2 <- assign(paste(combination$name[i],i,sep=""), trait_values)


#my.data.frame.tot = cbind(my.data.frame_1, my.data.frame_2)


# names(my.data.frame) <- c(combination$name[i])
#name_list <- names(pheno_data)
# add trait name in header
# aggregate in a matrix format
# sapply(nm,'[',seq(max(sapply(nm,length))))
# sapply()
``
}




## run the loop to plot graphics
for (i in 8:ncol(pheno_data_wide))
{
#pheno_data = pheno_data[pheno_data$year == "2010" & pheno_data$location == "Mokwa" & pheno_data$block_number == "1",i]
pheno_data = completedtf[pheno_data$year == "2010" & completedtf$location == "Mokwa" & completedtf$block_number == "1",i]
pheno_data_2010_Mokwa_B1 = pheno_data_wide[pheno_data_wide$year == "2010" & pheno_data_wide$location == "Mokwa" & pheno_data_wide$block_number == "1",i]
pheno_data_2010_Mokwa_B2 = pheno_data_wide[pheno_data_wide$year == "2010" & pheno_data_wide$location == "Mokwa" & pheno_data_wide$block_number == "2",i]
pheno_data_2010_Mokwa_B3 = pheno_data_wide[pheno_data_wide$year == "2010" & pheno_data_wide$location == "Mokwa" & pheno_data_wide$block_number == "3",i]
pheno_data_2010_Mokwa_B4 = pheno_data_wide[pheno_data_wide$year == "2010" & pheno_data_wide$location == "Mokwa" & pheno_data_wide$block_number == "4",i]
pheno_data_2010_Mokwa_allB = cbind(pheno_data_2010_Mokwa_B1,pheno_data_2010_Mokwa_B2,pheno_data_2010_Mokwa_B3,pheno_data_2010_Mokwa_B4)
#write.table(pheno_data_2010_Mokwa_B1, file= "test_pheno_data_wide_out_subtrait.txt", sep="\t")


my.data.frame.tot = cbind(my.data.frame_1, my.data.frame_2)
#data_2011_2012_B = cbind(data_2011_B1,data_2011_B2,data_2011_B3,data_2012_B1,data_2012_B2)
nm <-
}

#correlation

panel.cor <- function(x, y, digits=2, cex.cor)
{
  usr <- par("usr"); on.exit(par(usr))
  par(usr = c(0, 1, 0, 1))
  r <- abs(cor(x, y, use ="na.or.complete"))
  txt <- format(c(r, 0.123456789), digits=digits)[1]
  test <- cor.test(x,y,use ="na.or.complete")
  Signif <- ifelse(round(test$p.value,3)<0.001,"p<0.001",paste("p=",round(test$p.value,3)))  
  text(0.5, 0.25, paste("r=",txt))
  text(.5, .75, Signif)
}

#pairs(data,lower.panel=panel.smooth,upper.panel=panel.cor)

#smooth

panel.smooth<-function (x, y, col = "black", bg = NA, pch = 18, cex = 0.8, col.smooth = "red", span = 2/3, iter = 3, ...) 
{
  points(x, y, pch = pch, col = col, bg = bg, cex = cex)
  ok <- is.finite(x) & is.finite(y)
  if (any(ok)) 
    lines(stats::lowess(x[ok], y[ok], f = span, iter = iter), 
          col = col.smooth, ...)
}


#pairs(data,lower.panel=panel.smooth,upper.panel=panel.smooth)

#histo
panel.hist <- function(x, ...)
{
  usr <- par("usr"); on.exit(par(usr))
  par(usr = c(usr[1:2], 0, 1.5) )
  h <- hist(x, plot = FALSE)
  breaks <- h$breaks; nB <- length(breaks)
  y <- h$counts; y <- y/max(y)
  rect(breaks[-nB], 0, breaks[-1], y, col="green", ...)
}

#pairs(data,lower.panel=panel.smooth,upper.panel=panel.hist)
pairs(pheno_data_2010_Mokwa_allB, lower.panel=panel.smooth, upper.panel=panel.cor,diag.panel=panel.hist)
# main="trait name"
}
dev.off()

main = header_2011_2012[i]

#########################################
## difference between lines for a trait##
#########################################
## model + anova 
#################
fit_trait <- lm(formula=trait~as.factor(pheno_data$accession))
anova(fit_trait)

#can code that way too! Rename variables for ease of use
LINE = as.factor(pheno_data$accession)
# Simplified model
fit_trait_a = lm(trait~LINE)
anova(fit_trait_a)


## standard anova output ##
#Analysis of Variance Table
#
#Response: DMC
#                                Df Sum Sq Mean Sq F value   Pr(>F)   
#as.factor(pheno_data$accession) 16 131.83  8.2394   4.879 0.001444 **
#Residuals                       16  27.02  1.6888                    
#---
#Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1



# plot residual vs fits, qq plot, scale location, residuals vs leverage
par(mfrow=c(2,2))
plot(fit_trait_a)

#summary
########
names(fit_trait_a)
summary(fit_trait_a)

#Call:
#lm(formula = trait ~ as.factor(pheno_data$accession))
#
#Residuals:
#   Min     1Q Median     3Q    Max 
# -1.55  -0.70   0.00   0.70   1.55 
#
#Coefficients:
#                                                  Estimate Std. Error t value Pr(>|t|)    
#(Intercept)                                        32.1500     0.9189  34.988  < 2e-16 ***
...
