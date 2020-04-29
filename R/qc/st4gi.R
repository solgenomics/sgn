 setwd("C:/Users/bdeboeck/OneDrive - CGIAR/SweetGains project/CoP/CoP_curation")

# Load the st4gi package

library(st4gi)

# Load the data

mydata <- read.csv("PECIP2018_ST01CSR.csv")

# Have a look to the structure of the file
# Check that all numeric traits are of type num or int

str(mydata)

# Check names
# All names are recognized but "group" which is a classification factor

check.names.sp(mydata)

# Check frequencies with any trait
# This means each genotype is only once in each replication
# This cannot be the case of designs as preps

check.freq("crw", "cipno", env = NULL, "rep", mydata)

# Let us see what happens if we duplicate one row
# and if there are missing values

d <- mydata # A copy of mydata
d[5, ] <- d[8, ] # duplicate row 8 in row 5
check.freq("bc.cc", "cipno", env = NULL, "rep", d)

# Check positions
# This means each row-column position in each replication occurs only once

check.pos("row", "col", "rep", mydata)

# Let us see what happens if we duplicate one row

check.pos("row", "col", "rep", d)

# Fix all the detected problems in the data file and load the data again if necessary

mydata <- read.csv("PECIP2018_ST01CSR.csv")

# Compute all possible traits
# To compute values in tons/ha we are considering a density
# of 333333 plants per hectare

mydata <- cdt(mydata, method = "np", value = 33333)

# Check data
# This will check for inconsistencies  in the data as well as outliers
# In this example, only extreme values are detected

check.data(mydata)

# See what happens if number of roots were 0 for some plot

d <- mydata # A copy of mydata
d[5, 'nocr'] <- 0 # Zero commercial roots for plot 5
check.data(d)

# Fix all the detected problems in the data file and load the data again

mydata <- read.csv("PECIP2018_ST01CSR.csv")

# Run clean.data
# clean.data will do two things:
# - Put all impossible values to missing value
# - Put some values to zero (see the documentation of the function for details)
# Run this with caution and without computed traits

mydata <- clean.data(mydata)

# See what happens if we introduce some problems

d <- mydata # A copy of mydata
d[1, 'noph'] <- 0 # Zero plants harvested for plot 1
d[2, 'noph'] <- 0 # Zero plants harvested for plot 2
d[2, 12:20] <- NA # All traits are missing for plot 2
d[5, 'nocr'] <- 0 # Zero commercial roots for plot 5
d <- clean.data(d)

# Compute all possible traits

mydata <- cdt(mydata, method = "np", value = 33333)

# Save the output with a new name

write.csv(mydata, "newname.csv")