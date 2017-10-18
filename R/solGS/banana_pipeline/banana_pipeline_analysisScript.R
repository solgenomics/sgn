## prepare workspace
cat("\014") # clear console
setwd("D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela")
rm(list=ls(all=T)) # remove r objects
## Get data from ona
library(devtools)
update.packages("ona")
library(ona)
banana = onaDownload("BCMT_NM2017","seedtracker","megy","megy")

library(dplyr)
library(tidyr)
library(stringr)
library(httr)
library(jsonlite)
library(RCurl)
library(data.table)
library(gmailr)

## ORGANIZE DATA
# FLOWERING DATA
flowerID = select(banana, "X_submission_time","X_submitted_by",contains("floweringID")) %>%
  gather(flowering, flowerID, ends_with("floweringID"), na.rm = T)
flowerID$flowering <- NULL
flower <- as.data.frame(flowerID$flowerID)
flowerName = select(banana, ends_with("flowerName")) %>%
  gather(flower, accession_name, ends_with("flowerName"), na.rm=T)
flowerName$flower <- NULL
datetime = as.data.frame(str_split_fixed(flowerID$X_submission_time, "T", 2))
flowerIDs = as.data.frame(c(datetime, flowerID, flower, flowerName))
flowerIDs$X_submission_time <- NULL
colnames(flowerIDs) = c("submit_date","submit_time","submitted_by","flowerID","flower","accession_name")
pSex <- select(banana, ends_with("plantSex")) %>%
  gather(psex, sex, ends_with("plantSex"), na.rm = T)
pSex$psex <- NULL  
floweringDate <- select(banana, ends_with("flowering_date")) %>%
  gather(date, flowering_date, ends_with("flowering_date"), na.rm = T)
floweringDate$date <- NULL
flowered <- as.data.frame(c(flowerIDs, floweringDate, pSex))
fDate = as.Date(flowered$flowering_date)
fdateLimit = Sys.Date() - 7
floweringd = filter(flowered, fDate>=fdateLimit)
flowering <- floweringd[order(floweringd$flowering_date),]
floweringDF <- write.csv(flowering, file = "flowering.csv", row.names = F)
all.flowering <- write.csv(flowered, file = "all_flowering.csv", row.names = F)

# FIRST POLLINATION
FPOLLN = select(banana, "X_submission_time","X_submitted_by",ends_with("_gps_latitude"),ends_with("_gps_longitude"), contains("FirstPollination"))
parent <- select(FPOLLN,"X_submission_time","X_submitted_by",ends_with("_gps_latitude"),ends_with("_gps_longitude"), ends_with("parent")) %>%
  gather(parents, parentName, ends_with("parent"), na.rm = T)
parent$parents <- NULL
First.datetime = as.data.frame(str_split_fixed(parent$X_submission_time, "T", 2))
parentID = as.data.frame(str_split_fixed(parent$parentName, "/", 2))
colnames(parentID) <- c("mother", "father")
femaleID <- as.data.frame(parentID$mother)
female.acc.name = select(FPOLLN, ends_with("femaleName"))%>%
  gather(female, mother.acc.name, ends_with("femaleName"), na.rm=T)
female.acc.name$female <- NULL
male.acc.name = select(FPOLLN, ends_with("maleAccName"))%>%
  gather(male, father.acc.name, ends_with("maleAccName"), na.rm=T)
male.acc.name$male <- NULL

parents = as.data.frame(c(First.datetime, parent, femaleID, parentID, female.acc.name, male.acc.name))
parents$X_submission_time <- NULL
firstDate <- select(FPOLLN, ends_with("firstpollination_date")) %>%
  gather(date, firstpollination_date, ends_with("firstpollination_date"), na.rm = T)
firstDate$date <- NULL
cross <- select(FPOLLN, ends_with("crossID")) %>%
  gather(cross, crossnumber, ends_with("crossID"), na.rm = T)
cross$cross <- NULL
crossID <- as.data.frame(cross$crossnumber)
first_pollination <- as.data.frame(c(parents, cross, firstDate, crossID))

colnames(first_pollination) <- c("submission_date","submission_time","submitted_by","latitude","longitude","parentNames","femaleID",
                                "mother","father","mother_accessionName","father_accessionName","crossnumber","firstpollination_date","crossID")
firstpollination = as.data.frame(first_pollination[c(1:8,10,9,11:14)])
first <- write.csv(firstpollination, file = "firstpollination.csv", row.names = F)


# Repeat pollination
rpt = select(banana, "X_submission_time","X_submitted_by",contains("repeatpollination"))

getCrossID = select(rpt, "X_submission_time","X_submitted_by", ends_with("getCrossID")) %>%
  gather(cross, crossnumber, ends_with("getCrossID"), na.rm = T)
rptMaleID = select(rpt, ends_with("rptMaleID")) %>%
  gather(rptMale, Male_plotNumber, ends_with("rptMaleID"), na.rm = T)
rptMale_AccName = select(rpt, ends_with("getMaleAccName")) %>%
  gather(rptMale, Male_accessionName, ends_with("getMaleAccName"), na.rm = T)
rptPollnDate = select(rpt, ends_with("rptpollination_date")) %>%
  gather(date, repeatPollinationDate, ends_with("rptpollination_date"), na.rm = T)

repeatData <- as.data.frame(c(getCrossID,rptMaleID,rptMale_AccName, rptPollnDate))
repeatdf = select(repeatData,"X_submission_time","X_submitted_by","crossnumber","Male_plotNumber","Male_accessionName","repeatPollinationDate")
repeat.df = select(repeatData,"crossnumber","Male_plotNumber","Male_accessionName","repeatPollinationDate")
repeatdt = data.table(repeat.df)
repeatDT = as.data.frame(repeatdt[,number := 1:.N, by = crossnumber])
repeatDTwide = reshape(repeatDT,direction = "wide", idvar = "crossnumber", timevar = "number")
repeatID = data.frame(repeatDTwide$crossnumber)
colnames(repeatID) <- "repeatpollinationID"
repeatDT.wide <- data.frame(c(repeatID, repeatDTwide))
repeatpollnData <- write.csv(repeatDT.wide, file = "repeatpollination.csv", row.names = F)

# HARVESTING
harVEST = select(banana, "X_submission_time","X_submitted_by",contains("harvesting"))
harvestedID = select(harVEST, "X_submission_time","X_submitted_by",ends_with("harvestID")) %>%
  gather(id, crossnumber, ends_with("harvestID"),na.rm = T)
harvestID <- data.frame(harvestedID$crossnumber)
harvestdate = select(harVEST, ends_with("harvesting_date")) %>%
  gather(date, harvesting_date, na.rm = T) %>% select(harvesting_date)
hDate = str_replace(harvestdate$harvesting_date, "-", "/")
harvestDATE = str_replace(hDate, "-", "/")
pollinated_date = select(harVEST, ends_with("pollinated_date")) %>%
  gather(date, pollinated_date, na.rm=T) %>% select(pollinated_date) 
pDate = str_replace(pollinated_date$pollinated_date, "-", "/")
pollinationDATE = str_replace(pDate, "-", "/")
pollination2Harvest = data.frame(pollinationDATE, harvestDATE)
pollination2Harvest$days2Maturity <- as.Date(as.character(pollination2Harvest$harvestDATE), format="%Y/%m/%d")-
  as.Date(as.character(pollination2Harvest$pollinationDATE), format="%Y/%m/%d")
ripeningshed = select(banana, ends_with("taken_ripening_shed")) %>%
  gather(shed, to_ripeningshed, ends_with("taken_ripening_shed"), na.rm = T)
harvest.datetime = as.data.frame(str_split_fixed(harvestedID$X_submission_time, "T", 2))

harvested = as.data.frame(c(harvest.datetime,harvestedID, harvestID,harvestdate, pollination2Harvest, ripeningshed))
harvested$pollinationDATE <- NULL
harvested$harvestDATE <- NULL
harvested$X_submission_time <- NULL
harvestingdf = select(harvested,V1,V2,X_submitted_by, crossnumber,harvestedID.crossnumber, harvesting_date, days2Maturity,to_ripeningshed)
colnames(harvestingdf) = c("submission_date","submission_time","submitted_by","crossnumber", "harvestID", "harvesting_date","days_to_maturity","to_ripening_shed")
harvest = write.csv(harvestingdf, file = "harvesting.csv", row.names = F)

# RIPENING
RIPE = select(banana, "X_submission_time","X_submitted_by",contains("ripening"))
ripenid = select(RIPE, "X_submission_time","X_submitted_by",ends_with("ripenedID")) %>%
  gather(ids, crossnumber, ends_with("ripenedID"), na.rm  = T)
ripenID <- data.frame(ripenid$crossnumber)
getHarDate = select(RIPE, ends_with("Harvest_date")) %>%
  gather(date, dateHarvested, ends_with("Harvest_date"), na.rm = T)
dateHarv = str_replace(getHarDate$dateHarvested, "-", "/")
dateHarvest = str_replace(dateHarv, "-", "/")

ripendate = select(RIPE, ends_with("ripening_date")) %>% 
  gather(date, ripen_date, ends_with("ripening_date"), na.rm = T)
dateRipe = str_replace(ripendate$ripen_date, "-", "/")
dateRipened = str_replace(dateRipe, "-", "/")
Harvest2Ripening = data.frame(dateHarvest, dateRipened)
Harvest2Ripening$days_harvest_ripening <- as.Date(as.character(Harvest2Ripening$dateRipened), format="%Y/%m/%d")-
  as.Date(as.character(Harvest2Ripening$dateHarvest), format="%Y/%m/%d")
Harvest2Ripening$dateRipened <- NULL
Harvest2Ripening$dateHarvest <- NULL
ripen.datetime = as.data.frame(str_split_fixed(ripenid$X_submission_time, "T", 2))
ripened = as.data.frame(c(ripen.datetime, ripenid, ripenID,ripendate, Harvest2Ripening))
ripened$X_submission_time <- NULL
ripeningdf = select(ripened, V1,V2,X_submitted_by,crossnumber, ripenid.crossnumber, ripen_date, days_harvest_ripening)
colnames(ripeningdf) = c("submission_date","submission_time","submitted_by","crossnumber", "ripenID","ripen_date","days_harvest_ripening")

ripening = write.csv(ripeningdf, file = "ripening.csv", row.names = F) 

# EXTRACTION
EXTRACTION = select(banana, "X_submission_time", "X_submitted_by", contains("seedExtraction"))
extractid = select(EXTRACTION, "X_submission_time", "X_submitted_by", ends_with("extractionID")) %>%
  gather(extract, crossnumber,ends_with("extractionID"), na.rm = T)
extractID <- data.frame(extractid$crossnumber)
total = select(banana, ends_with("totalSeedsExtracted")) %>% 
  gather(total, number_seeds, ends_with("totalSeedsExtracted"), na.rm = T)
extractdate = select(EXTRACTION, ends_with("extraction_date")) %>% 
  gather(date, seed_extraction_date, ends_with("extraction_date"),na.rm = T)
dateExtract = str_replace(extractdate$seed_extraction_date, "-", "/")
dateExtrd = str_replace(dateExtract, "-", "/")

DateRipen = select(EXTRACTION, ends_with("ripened_date"))%>%
  gather(date, DateRipen, ends_with("ripened_date"), na.rm=T)
dateRip = str_replace(DateRipen$DateRipen, "-", "/")
dateRip = str_replace(dateRip, "-", "/")
ripen2Extract = data.frame(dateExtrd, dateRip)
ripen2Extract$days_ripening_extraction <- as.Date(as.character(ripen2Extract$dateExtrd), format="%Y/%m/%d")-
  as.Date(as.character(ripen2Extract$dateRip), format="%Y/%m/%d")
ripen2Extract$dateExtrd <- NULL
ripen2Extract$dateRip <- NULL
extr.datetime = as.data.frame(str_split_fixed(extractid$X_submission_time, "T", 2))
extracted = as.data.frame(c(extr.datetime,extractid, extractID,extractdate, total, ripen2Extract))
extracted$X_submission_time <- NULL
extractiondf = select(extracted, V1, V2,X_submitted_by,crossnumber,extractid.crossnumber, seed_extraction_date, number_seeds, days_ripening_extraction)
colnames(extractiondf) = c("submission_date","submission_time","submitted_by", "crossnumber", "extractID","seed_extraction_date", "number_seeds", 
                           "days_ripening_extraction")
extractd = write.csv(extractiondf, file = "extraction.csv", row.names = F)


## STOLEN
# mother
statuses = select(banana, "X_submission_time","X_submitted_by",contains("plantstatus"))
stolen.type = select(statuses, ends_with("plant_status")) %>%
  gather(type, status, ends_with("plant_status"), na.rm = T) %>%
  filter(status=="bunch_stolen")
mother.stolenID = select(statuses, "X_submission_time","X_submitted_by",ends_with("stolen_statusID"))%>%
  gather(mother.status, motherID, ends_with("stolen_statusID"), na.rm = T)
mother.stolen.ID <- data.frame(mother.stolenID$motherID)
stolendate = select(statuses, ends_with("stolen_date")) %>%
  gather(date, stolen_date, ends_with("stolen_date"), na.rm = T)

stolen.status.datetime = as.data.frame(str_split_fixed(mother.stolenID$X_submission_time, "T", 2))
mother.stolen.status = as.data.frame(c(stolen.status.datetime, mother.stolenID, mother.stolen.ID, stolendate, stolen.type))
mother.stolen.status$X_submission_time <- NULL
mother.stolendf = select(mother.stolen.status, V1,V2,X_submitted_by, motherID, mother.stolenID.motherID, stolen_date, status)
colnames(mother.stolendf) = c("submission_date","submission_time","submitted_by","ID", "statusID","date", "status")

# stolen cross
cross.stolenID = select(statuses, "X_submission_time","X_submitted_by",ends_with("stolenBunch_statusID"))%>%
  gather(cross.status, crossID, ends_with("stolenBunch_statusID"), na.rm = T)
cross.stolen.ID <- data.frame(cross.stolenID$crossID)
if(dim(mother.stolendf)[1]>0 & dim(cross.stolenID)[1]>0){
  cross.status.datetime = as.data.frame(str_split_fixed(cross.stolenID$X_submission_time, "T", 2))
  cross.stolen.status = as.data.frame(c(cross.status.datetime, cross.stolenID, cross.stolen.ID, stolendate, stolen.type))
  cross.stolen.status$X_submission_time <- NULL
  cross.stolendf = select(cross.stolen.status, V1,V2,X_submitted_by, crossID, cross.stolenID.crossID, stolen_date, status)
  colnames(cross.stolendf) = c("submission_date","submission_time","submitted_by","ID", "statusID","date", "status")
  stolendf = rbind(mother.stolendf, cross.stolendf)
} else {
  stolendf = mother.stolendf
}

########################################################

# Fallen mother
fallen.type = select(statuses, ends_with("plant_status")) %>%
  gather(type, status, ends_with("plant_status"), na.rm = T) %>%
  filter(status=="fallen")
mother.fallenID = select(statuses, "X_submission_time","X_submitted_by",ends_with("fallen_statusID"))%>%
  gather(mother.status, motherID, ends_with("fallen_statusID"), na.rm = T)
mother.fallen.ID <- data.frame(mother.fallenID$motherID)
fallendate = select(statuses, ends_with("fallen_date")) %>%
  gather(date, fallen_date, ends_with("fallen_date"), na.rm = T)

fallen.status.datetime = as.data.frame(str_split_fixed(mother.fallenID$X_submission_time, "T", 2))
mother.fallen.status = as.data.frame(c(fallen.status.datetime, mother.fallenID, mother.fallen.ID, fallendate, fallen.type))
mother.fallen.status$X_submission_time <- NULL
mother.fallendf = select(mother.fallen.status, V1,V2,X_submitted_by, motherID, mother.fallenID.motherID, fallen_date, status)
colnames(mother.fallendf) = c("submission_date","submission_time","submitted_by","ID", "statusID","date", "status")

# fallen cross
cross.fallenID = select(statuses, "X_submission_time","X_submitted_by",ends_with("fallenBunch_statusID"))%>%
  gather(cross.status, crossID, ends_with("fallenBunch_statusID"), na.rm = T)
cross.fallen.ID <- data.frame(cross.fallenID$crossID)
if(dim(mother.fallendf)[1]>0 & dim(cross.fallenID)[1]>0){
  cross.status.datetime = as.data.frame(str_split_fixed(cross.fallenID$X_submission_time, "T", 2))
  cross.fallen.status = as.data.frame(c(cross.status.datetime, cross.fallenID, cross.fallen.ID, fallendate, fallen.type))
  cross.fallen.status$X_submission_time <- NULL
  cross.fallendf = select(cross.fallen.status, V1,V2,X_submitted_by, crossID, cross.fallenID.crossID, fallen_date, status)
  colnames(cross.fallendf) = c("submission_date","submission_time","submitted_by","ID", "statusID","date", "status")
  fallendf = rbind(mother.fallendf, cross.fallendf)
} else {
  fallendf = mother.fallendf
}

# Other statuses
target = c("has_disease","died","unusual","okay")
othertype = select(statuses, ends_with("plant_status")) %>%
  gather(type, status, ends_with("plant_status"), na.rm = T) %>%
  filter(status %in% target)
otherID = select(statuses, "X_submission_time","X_submitted_by",ends_with("plant_statusID"))%>%
  gather(status, ID, ends_with("plant_statusID"), na.rm = T)
other.ID <- data.frame(otherID$ID)
other.date = select(statuses, ends_with("status_Date")) %>%
  gather(sdate, date, ends_with("status_Date"), na.rm = T)

otherstatus.datetime = as.data.frame(str_split_fixed(otherID$X_submission_time, "T", 2))
otherstatus = as.data.frame(c(otherstatus.datetime, other.date, otherID, other.ID, other.date, othertype))
otherstatus$X_submission_time <- NULL
otherdf = select(otherstatus, V1,V2,X_submitted_by, ID, otherID.ID, date, status.1)
colnames(otherdf) = c("submission_date","submission_time","submitted_by","ID", "statusID","date", "status")

statusDF = rbind(stolendf, fallendf, otherdf)

## LAB
# RESCUE
good = select(banana, ends_with("goodSeeds")) %>%
  gather(good, good_seeds,ends_with("goodSeeds"), na.rm = T)
bad = select(banana, ends_with("badSeeds")) %>%
  gather(bad, bad_seeds, ends_with("badSeeds"),na.rm = T)
RESCUED = select(banana, "X_submission_time","X_submitted_by",contains("embryoRescue"))
rescueid = select(RESCUED, "X_submission_time","X_submitted_by",ends_with("embryorescueID"))%>%
  gather(id, crossnumber,ends_with("embryorescueID"), na.rm = T)
rescueID <- data.frame(rescueid$crossnumber)
rescueseeds = select(RESCUED, ends_with("embryorescue_seeds")) %>%
  gather(seeds, number_rescued, ends_with("embryorescue_seeds"),na.rm = T)
rescuedate = select(RESCUED, ends_with("embryorescue_date"))%>%
  gather(id, rescue_date,ends_with("embryorescue_date"), na.rm = T)
date_Resc = str_replace(rescuedate$rescue_date, "-", "/")
dateResc = str_replace(date_Resc, "-", "/")

dateEXTRD = select(RESCUED, ends_with("extracted_date")) %>%
  gather(date, extract_date, ends_with("extracted_date"), na.rm = T)
date_EXTRD = str_replace(dateEXTRD$extract_date, "-", "/")
dateEXTRD = str_replace(date_EXTRD, "-", "/")
Extract2Rescue = data.frame(dateEXTRD, dateResc)
Extract2Rescue$days_extraction_rescue <- as.Date(as.character(Extract2Rescue$dateResc), format="%Y/%m/%d")-
  as.Date(as.character(Extract2Rescue$dateEXTRD), format="%Y/%m/%d")
Extract2Rescue$dateEXTRD <- NULL
Extract2Rescue$dateResc <-NULL
resc.datetime = as.data.frame(str_split_fixed(rescueid$X_submission_time, "T", 2))
rescued = as.data.frame(c(resc.datetime,rescueid,rescueID,good, bad, rescuedate, rescueseeds, Extract2Rescue))
rescued$X_submission_time <- NULL
rescuingdf = select(rescued, V1, V2,X_submitted_by,crossnumber, rescueid.crossnumber, good_seeds, bad_seeds, number_rescued, rescue_date, days_extraction_rescue)
colnames(rescuingdf) = c("submission_date","submission_time","submitted_by","crossnumber", "rescueID","good_seeds","badseeds","number_rescued", "rescue_date", "days_extraction_rescue")
rescueed = write.csv(rescuingdf, file = "rescued.csv", row.names = F)

# 2 WEEKS GERMINATION
week2Germination = select(banana,"X_submission_time","X_submitted_by", contains("embryo_germinatn_after_2wks") )
twowksID = select(week2Germination, "X_submission_time","X_submitted_by",ends_with("germinating_2wksID")) %>%
  gather(germinating, crossnumber, ends_with("germinating_2wksID"), na.rm = T)
week2ID <- data.frame(twowksID$crossnumber)
active2wks = select(week2Germination, ends_with("actively_2wks")) %>%
  gather(active, actively_germination_after_two_weeks, ends_with("actively_2wks"),na.rm = T)
twowksDate = select(week2Germination, ends_with("2wks_date")) %>% 
  gather(date, germination_after_2weeks_date, ends_with("2wks_date"),na.rm = T)
date2wk = str_replace(twowksDate$germination_after_2weeks_date, "-", "/")
date2wks = str_replace(date2wk, "-", "/")
rescDate = select(week2Germination, ends_with("rescued_date")) %>%
  gather(date, rescuedDate, ends_with("rescued_date"), na.rm = T)
dateERescue = str_replace(rescDate$rescuedDate, "-", "/")
dateERescued = str_replace(dateERescue, "-", "/")

Rescue_2wks = data.frame(date2wks, dateERescued)
Rescue_2wks$days_rescue_2wksGermination <- as.Date(as.character(Rescue_2wks$date2wks), format="%Y/%m/%d")-
  as.Date(as.character(Rescue_2wks$dateERescued), format="%Y/%m/%d")
Rescue_2wks$date2wks <- NULL
Rescue_2wks$dateERescued <- NULL
two.datetime = as.data.frame(str_split_fixed(twowksID$X_submission_time, "T", 2))
germination2weeks = as.data.frame(c(two.datetime,twowksID, week2ID, twowksDate, active2wks, Rescue_2wks))
germination2weeks$X_submission_time <- NULL
germination2weeksdf = select(germination2weeks, V1,V2,X_submitted_by,crossnumber,twowksID.crossnumber, germination_after_2weeks_date, actively_germination_after_two_weeks, days_rescue_2wksGermination)
colnames(germination2weeksdf) = c("submission_date","submission_time","submitted_by","crossnumber", "week2ID","germination_after_2weeks_date", 
                                "actively_germination_after_two_weeks","days_rescue_2weeksGermination")
germ2wks = write.csv(germination2weeksdf, file = "germinating2weeks.csv", row.names = F)

# 6 weeks GERMINATION
week6 = select(banana,"X_submission_time","X_submitted_by",contains("embryo_germinatn_after_6weeks"))
week6ID = select(week6, "X_submission_time","X_submitted_by", ends_with("germinating_6weeksID"))%>%
  gather(germinating, crossnumber, ends_with("germinating_6weeksID"),na.rm = T)
week6.ID <- data.frame(week6ID$crossnumber)
active6weeks = select(week6, ends_with("actively_6weeks")) %>%
  gather(active, actively_germination_after_6weeks, ends_with("actively_6weeks"),na.rm = T)

week6Date = select(week6, ends_with("germinating_6weeks_date")) %>%
  gather(date, germination_after_6weeks_date, ends_with("germinating_6weeks_date"),na.rm = T)
date6weeks = str_replace(week6Date$germination_after_6weeks_date, "-", "/")
date.6weeks = str_replace(date6weeks, "-", "/")
germ2wks_date = select(week6, ends_with("germinated_2wksdate")) %>%
  gather(date, germ2wksdate, ends_with("germinated_2wksdate"), na.rm = T)
germ2wkDate = str_replace(germ2wks_date$germ2wksdate, "-","/")
germinated2wksDate = str_replace(germ2wkDate,"-","/")
Germination_2wks_6weeks = data.frame(germinated2wksDate, date.6weeks)
Germination_2wks_6weeks$days_2weeks_6weeks_Germination <- as.Date(as.character(Germination_2wks_6weeks$date.6weeks), format="%Y/%m/%d")-
  as.Date(as.character(Germination_2wks_6weeks$germinated2wksDate), format="%Y/%m/%d")
Germination_2wks_6weeks$germinated2wksDate <- NULL
Germination_2wks_6weeks$dateOneM <- NULL
week6.datetime = as.data.frame(str_split_fixed(week6ID$X_submission_time, "T", 2))
germination6weeks = as.data.frame(c(week6.datetime,week6ID, week6.ID, week6Date, active6weeks, Germination_2wks_6weeks))
germination6weeks$X_submission_time <- NULL
germination6weeksdf = select(germination6weeks,V1, V2,X_submitted_by,crossnumber,week6ID.crossnumber, germination_after_6weeks_date, actively_germination_after_6weeks, days_2weeks_6weeks_Germination)
colnames(germination6weeksdf) = c("submission_date","submission_time","submitted_by","crossnumber", "week6ID","germination_after_6weeks_date",
                                  "actively_germination_after_6weeks", "days_2weeksGermination_6weeksGermination")
germ6weeks = write.csv(germination6weeksdf, file = "germinating6weeks.csv", row.names = F)

# SUBCULTURE
SUBCT = select(banana, "X_submission_time","X_submitted_by", contains("subculturing"))
subcultureid = select(SUBCT,  "X_submission_time","X_submitted_by", ends_with("subcultureID"))%>%
  gather(ids, crossnumber, ends_with("subcultureID"), na.rm = T)
subcultureID <- data.frame(subcultureid$crossnumber)
subcdate = select(SUBCT, ends_with("subculture_date")) %>%
  gather(date, subculture_date, ends_with("subculture_date"),na.rm = T)
subDate = str_replace(subcdate$subculture_date, "-","/")
subdDate = str_replace(subDate,"-","/")
week6Gdate = select(SUBCT, ends_with("germinated_6weeksdate")) %>%
  gather(date, week6germDate, ends_with("germinated_6weeksdate"), na.rm = T)
week6Date = str_replace(week6Gdate$week6germDate, "-","/")
week6.Date = str_replace(week6Date,"-","/")
week6Germ_subculture = data.frame(subdDate, week6.Date)
week6Germ_subculture$days_6weeks_Germination_subculture <- as.Date(as.character(week6Germ_subculture$subdDate), format="%Y/%m/%d")-
  as.Date(as.character(week6Germ_subculture$week6.Date), format="%Y/%m/%d")
week6Germ_subculture$subdDate <- NULL
week6Germ_subculture$monthDate <- NULL
subcultures = select(SUBCT, ends_with("multiplicationNumber")) %>% 
  gather(date, subcultures,ends_with("multiplicationNumber"), na.rm = T)
sub.datetime = as.data.frame(str_split_fixed(subcultureid$X_submission_time, "T", 2))
subculturin = as.data.frame(c(sub.datetime, subcultureid, subcultureID, subcdate, subcultures, week6Germ_subculture))
subculturin$X_submission_time <- NULL
subculturingdf = select(subculturin, V1, V2, X_submitted_by,crossnumber, subcultureid.crossnumber, subculture_date, subcultures, days_6weeks_Germination_subculture)
colnames(subculturingdf) = c("submision_date","submission_time","submitted_by","crossnumber","subcultureID", "subculture_date","subcultures", "days_6weeks_Germination_subculture")
#multiplication = select(subculture, ends_with("multiplicationID"))
subdata = write.csv(subculturingdf, file = "subculture.csv", row.names = F)

## SUBPLANTS
if (is.na(SUBCT$Laboratory.subculturing.subcultureID)){
  crossnumber = NA
  plantletID = NA
  subculture = NA
  subculture_date = NA
  subIDs = cbind(crossnumber,plantletID, subculture, subculture_date)
  colnames(subIDs) = c("crossnumber","plantletID",	"subculture","subculture_date")
}else{
subplants = select(SUBCT,ends_with("subculture_date"), ends_with("multiplicationID"))%>%
  gather(plantlets, subplants, ends_with("multiplicationID"), na.rm=T)
subplants$plantlets <- NULL
subplants$Laboratory.subculturing.subculture_date <- NULL
subID = data.frame(str_sub(subplants$subplants, 1, str_length(subplants$subplants)-4))
subIDplants = data.frame(c(subID, subplants))
subIDp = subIDplants[,c(1,2,5)]
colnames(subIDp) = c("crossnumber","subculture_date", "subculture")
subIDp$plantletID <- subIDp$subculture 
subIDs= subIDp[,c(1,4,3,2)]
}
subplants = write.csv(subIDs, file = "subplants.csv", row.names = F)

# ROOTING
ROOT = select(banana,"X_submission_time","X_submitted_by",contains("rooting"))
rootid = select(ROOT, "X_submission_time","X_submitted_by", ends_with("rootingID")) %>% 
  gather(id, plantletID, ends_with("rootingID"),na.rm = T)
rootID <- data.frame(rootid$plantletID)
root.datetime = as.data.frame(str_split_fixed(rootid$X_submission_time, "T", 2))

rootdate = select(ROOT, ends_with("rooting_date")) %>%
  gather(date, date_rooting, ends_with("rooting_date"),na.rm = T)
rootDate = str_replace(rootdate$date_rooting, "-","/")
rDate = str_replace(rootDate,"-","/")

sub_date = select(ROOT, ends_with("getSubDate"))%>%
  gather(date, date_subcultured, ends_with("getSubDate"), na.rm = T)
subDate = str_replace(sub_date$date_subcultured, "-","/")
sub.date = str_replace(subDate,"-","/")

subculture_rooting = data.frame(rDate, sub.date)
subculture_rooting$days_subculture_rooting <- as.Date(as.character(subculture_rooting$rDate), format="%Y/%m/%d")-
  as.Date(as.character(subculture_rooting$sub.date), format="%Y/%m/%d")
subculture_rooting$rDate <- NULL
subculture_rooting$sub.date <- NULL

rootin = as.data.frame(c(root.datetime,rootid, rootID, rootdate, subculture_rooting))
rootin$X_submission_time <- NULL
rootingdf = select(rootin, V1, V2,X_submitted_by,plantletID, rootid.plantletID, date_rooting, days_subculture_rooting )
colnames(rootingdf) = c("submission_date","submission_time","submitted_by","plantletID","rootID", "date_rooting", "days_subculture_rooting")
rooted = write.csv(rootingdf, file = "rooting.csv", row.names = F)


# SCREEN HOUSE
HOUSE = select(banana, "X_submission_time","X_submitted_by", contains("screenhouse"))
transferscrnhseid = select(HOUSE,"X_submission_time","X_submitted_by", ends_with("screenhseID")) %>%
  gather(id, plantletID,ends_with("screenhseID"), na.rm = T)
transferscrnhseID <- data.frame(transferscrnhseid$plantletID)
transferdate = select(HOUSE, ends_with("screenhse_transfer_date")) %>% 
  gather(date, date_of_transfer_to_screenhse,ends_with("screenhse_transfer_date"), na.rm = T)

dateHSE = str_replace(transferdate$date_of_transfer_to_screenhse, "-", "/")
dateHSED = str_replace(dateHSE, "-", "/")
rootedDate = select(HOUSE, ends_with("rooted_date")) %>%
  gather(date, rootdate, ends_with("rooted_date"), na.rm = T)
dateRTD = str_replace(rootedDate$rootdate, "-", "/")
dateROOTED = str_replace(dateRTD, "-", "/")
rooting2Screenhse = data.frame(dateROOTED, dateHSED)
rooting2Screenhse$days_rooting_screenhse <- as.Date(as.character(rooting2Screenhse$dateHSED), format="%Y/%m/%d")-
  as.Date(as.character(rooting2Screenhse$dateROOTED), format="%Y/%m/%d")
rooting2Screenhse$dateROOTED <- NULL
rooting2Screenhse$dateHSED <- NULL
trans.datetime = as.data.frame(str_split_fixed(transferscrnhseid$X_submission_time, "T", 2))
transferscreenhse = as.data.frame(c(trans.datetime,transferscrnhseid, transferscrnhseID, transferdate, rooting2Screenhse))
transferscreenhse$X_submission_time <- NULL
screenhsedf = select(transferscreenhse, V1, V2,X_submitted_by,plantletID,transferscrnhseid.plantletID, date_of_transfer_to_screenhse,days_rooting_screenhse)      #transfer to screenhsedf
colnames(screenhsedf) = c("submission_date","submission_time","submitted_by","plantletID", "transferscrnhseID","screenhse_transfer_date","days_rooting_screenhse")
screenhse = write.csv(screenhsedf, file = "screenhouse.csv", row.names = F)

# Hardening
HARD = select(banana, "X_submission_time","X_submitted_by", contains("hardening"))
hardenedid = select(HARD,"X_submission_time","X_submitted_by", ends_with("hardeningID")) %>%
  gather(id, plantletID, ends_with("hardeningID"),na.rm = T)
hardenID <- data.frame(hardenedid$plantletID)
hardeneddate = select(HARD, ends_with("hardening_date")) %>% 
  gather(date, hardening_date,ends_with("hardening_date"), na.rm = T)
dateHARD = str_replace(hardeneddate$hardening_date, "-", "/")
dateHARDENED = str_replace(dateHARD, "-", "/")

screenhseDATE = select(HARD, ends_with("screenhsed_date")) %>%
  gather(date, screendate, ends_with("screenhsed_date"), na.rm = T)
dateSHSE = str_replace(screenhseDATE$screendate, "-", "/")
dateSHSED = str_replace(dateSHSE, "-", "/")
screenhse2Hardening = data.frame(dateHARDENED, dateSHSED)
screenhse2Hardening$days_scrnhse_hardening <- as.Date(as.character(screenhse2Hardening$dateHARDENED), format="%Y/%m/%d")-
  as.Date(as.character(screenhse2Hardening$dateSHSED), format="%Y/%m/%d")
screenhse2Hardening$dateHARDENED <- NULL
screenhse2Hardening$dateSHSED <- NULL
harden.datetime = as.data.frame(str_split_fixed(hardenedid$X_submission_time, "T", 2))
hardening = as.data.frame(c(harden.datetime,hardenedid,hardenID, hardeneddate, screenhse2Hardening))
hardening$X_submission_time <- NULL
hardeningdf = select(hardening, V1, V2, X_submitted_by, plantletID, hardenedid.plantletID,hardening_date, days_scrnhse_hardening)  ## hardening
colnames(hardeningdf) = c("submission_date","submission_time","submitted_by","plantletID","hardenID", "hardening_date", "days_scrnhse_hardening")
hardenned = write.csv(hardeningdf, file = "hardening.csv", row.names = F)

# Open field
OPEN = select(banana,"X_submission_time","X_submitted_by", contains("transplant_openfield"))
openfield_ID = select(OPEN, "X_submission_time","X_submitted_by",ends_with("openfieldID")) %>%
  gather(id, plantletID,ends_with("openfieldID"), na.rm = T)
openfieldID <- data.frame(openfield_ID$plantletID)
opendate = select(OPEN, ends_with("transplanting_date")) %>%
  gather(date, date_of_transfer_to_openfield, ends_with("transplanting_date"),na.rm = T)
dateOPEN = str_replace(opendate$date_of_transfer_to_openfield, "-", "/")
dateOPENFD = str_replace(dateOPEN, "-", "/")

dateHardd = select(OPEN, ends_with("hardened_date"))%>%
  gather(date, hard_date, ends_with("hardened_date"), na.rm = T)
dateHarder = str_replace(dateHardd$hard_date, "-","/")
dateHD = str_replace(dateHarder, "-","/")
harden2OField = data.frame(dateOPENFD, dateHD)
harden2OField$days_hardening_openfield <- as.Date(as.character(harden2OField$dateOPENFD), format="%Y/%m/%d")-
  as.Date(as.character(harden2OField$dateHD), format="%Y/%m/%d")
harden2OField$dateOPENFD <- NULL
harden2OField$dateHD <- NULL
open.datetime = as.data.frame(str_split_fixed(openfield_ID$X_submission_time, "T", 2))
openfieldtransfer = as.data.frame(c(open.datetime,openfield_ID,openfieldID, opendate, harden2OField))
openfieldtransfer$X_submission_time <- NULL
openfieldtransferdf = select(openfieldtransfer,V1, V2, X_submitted_by, plantletID,openfield_ID.plantletID,date_of_transfer_to_openfield, days_hardening_openfield) #to open field
colnames(openfieldtransferdf) = c("submission_date","submission_time","submitted_by","plantletID", "openfieldID","date_of_transfer_to_openfield",
                                  "days_hardening_openfield")
openfd = write.csv(openfieldtransferdf, file = "openfield.csv", row.names = F)

# Screenhouse status
sstatus = select(banana, "X_submission_time","X_submitted_by", contains("screenhse_status"))
sstatusDate = select(sstatus, ends_with("scrnhsestatus_Date"))%>%
  gather(sdate,date, ends_with("scrnhsestatus_Date"), na.rm = T)
sstatusDate$sdate <-NULL
sstatusID = select(sstatus, "X_submission_time","X_submitted_by", ends_with("scrnhse_statusID"))%>%
  gather(ssID, statusID, ends_with("scrnhse_statusID"), na.rm = T)
sstatusID$ssID <- NULL
sstatusID$sstatus_datetime = as.data.frame(str_split_fixed(sstatusID$X_submission_time, "T", 2))
sstatusID$X_submission_time <- NULL
s.status = select(sstatus, ends_with("scrnhseStatus"))%>%
  gather(sstatus, status, ends_with("scrnhseStatus"), na.rm = T)
s.status$sstatus <- NULL
scrnhse.status = data.frame(c(sstatusID, sstatusDate, s.status))
scrnhse.status$ID = scrnhse.status$statusID
colnames(scrnhse.status) = c("submitted_by", "statusID", "submission_date","submission_time","date","status","ID")
select(scrnhse.status, "submission_date","submission_time","submitted_by","ID","statusID","date","status")

merged_status = rbind(statusDF, scrnhse.status)
merged.status = write.csv(merged_status, file = "status.csv", row.names = F)

# Contamination
ContaminID <- select(banana, "X_submission_time","X_submitted_by",ends_with("econtaminationID")) %>%
  gather(contamination, crossnumber, ends_with("econtaminationID"), na.rm = T)
contaminationID <- data.frame(ContaminID$crossnumber)
ContaminDate <- select(banana, ends_with("contamination_date")) %>%
  gather(date, contamination_date, ends_with("contamination_date"), na.rm = T)
contam.datetime = as.data.frame(str_split_fixed(ContaminID$X_submission_time, "T", 2))
contaminated = select(banana, ends_with("contaminated")) %>%
  gather(contamination, contaminated, ends_with("contaminated"), na.rm=T)

contamination <- as.data.frame(c(contam.datetime,ContaminID, contaminationID, ContaminDate, contaminated)) %>%
  select(V1,V2,"X_submitted_by", crossnumber,ContaminID.crossnumber, contamination_date, contaminated)
colnames(contamination) <- c("submission_date","submission_time","submitted_by","crossnumber","contaminationID","contamination_date","contamination")
contamination$time <- NULL
contamin <- write.csv(contamination, file = "contamination.csv", row.names = F)

## ALL DATA
allbanana = list(firstpollination, repeatDT.wide, harvestingdf[,4:8], ripeningdf[,4:7], extractiondf[,4:8], rescuingdf[,4:10], germination2weeksdf[,4:8],
                 germination6weeksdf[,4:8], subculturingdf[,4:8])                   
bananadat = Reduce(function(x,y) merge(x,y, all = T, by= "crossnumber"), allbanana)
bananadf = select(bananadat, crossnumber, everything())
bananadata = bananadf
bananadata1 = write.csv(bananadata, file = "bananadata.csv", row.names = F)

## PLANTLETS
allplantlets = list(subIDs, rootingdf[,4:7], screenhsedf[,4:7], hardeningdf[,4:7], openfieldtransferdf[,4:7])
merge_plantlets = Reduce(function(x,y) merge(x,y, all=T, by = "plantletID"), allplantlets)
plantsDF = select(merge_plantlets, crossnumber, plantletID, everything())
plantletsdf = write.csv(plantsDF, file = "plantlets.csv", row.names = F)

## EMAIL NOTIFICATIONS
today = Sys.Date()
# 1. status reported today
pStatus = statusDF
filter.status = filter(pStatus, status!='okay')
sdate = as.Date(filter.status$date)
filter.status.date = filter(filter.status, sdate==today)

if (dim(filter.status.date)[1]!=0){
  write.csv(filter.status.date, file = "statusReport.csv", row.names = F)
  mime() %>%
    to("karanjamargaret@gmail.com") %>%
    from("megykah@gmail.com") %>%
    text_body("Please see the list of accession that have been reported to have a problem today. Bests, Margaret") -> first_part
  
  first_part %>%
    subject("Banana pipeline today status report") %>%
    attach_file("D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\statusReport.csv") -> file_attachment
  
  send_message(file_attachment)
}

# Datasets 
dataset <- c(bananadata, firstpollination, harvestingdf, ripeningdf, extractiondf, rescuingdf, germination2weeksdf,
             germination6weeksdf, subculturingdf, rootingdf, screenhsedf, hardeningdf, openfieldtransferdf)

## POST MEDIA FILES TO ONA
# Get tokens
raw.result <- GET("https://api.ona.io/api/v1/user.json", authenticate(user = "seedtracker",password = "Seedtracking101"))
raw.result.char<-rawToChar(raw.result$content)
raw.result.json<-fromJSON(raw.result.char)
TOKEN_KEY <- raw.result.json$temp_token

# DELETE CSV FILES
# flowering
meta_flowerid <- readChar("D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_flowerid.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_flowerid),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# bananadata
meta_bananaid <- readChar("D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_bananaid.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_bananaid),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# Status
meta_statusID <- readChar("D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_statusID.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_statusID),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# Contamination
meta_contaminationID <- readChar("D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_contaminationID.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_contaminationID),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# Plantlets
meta_plantletsID = readChar("D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_plantletsID.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_plantletsID),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

## UPLOAD FLOWERING DATA
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.flower.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='flowering.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\flowering.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)
# upload bananadata
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.banana.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='bananadata.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\bananadata.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)
# status upload
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.status.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='status.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\status.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)

# contamination upload
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.contamination.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='contamination.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\contamination.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)

# Plantlets upload
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.plantlets.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                       data_value='plantlets.csv',data_type='media',xform=237289,
                                       data_file=fileUpload(filename = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\plantlets.csv",contentType = 'text/csv'),
                                       .opts=list(httpheader=header), verbose = TRUE)
D:\github\ODK_bananaCrossingTool\Nelson Mandela

## get ID
# flowerID
flower.raw.result.json<-fromJSON(post.flower.results)
metadata_flowerid <- flower.raw.result.json$id
meta_flower <- cat(metadata_flowerid, file = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_flowerid.txt")

# Bananadata ID
banana.raw.result.json<-fromJSON(post.banana.results)
metadata_bananaid <- banana.raw.result.json$id
meta_flower <- cat(metadata_bananaid, file = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_bananaid.txt")

# get status ID
status.raw.result.json<-fromJSON(post.status.results)
metadata_statusid <- status.raw.result.json$id
meta_status <- cat(metadata_statusid, file = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_statusID.txt")

# get contamination ID
contamination.raw.result.json<-fromJSON(post.contamination.results)
metadata_contaminationid <- contamination.raw.result.json$id
meta_contamination <- cat(metadata_contaminationid, file = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_contaminationID.txt")

# get subplantlets ID
plantlets.raw.result.json<-fromJSON(post.plantlets.results)
metadata_plantletsid <- plantlets.raw.result.json$id
meta_plantlets <- cat(metadata_plantletsid, file = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\metadata_plantletsID.txt")

## DATA EXPLORER
# organize shiny app data
library(dplyr)
library(tidyr)
nFlower = strrep(c("Arusha","flowering"),1)
if (dim(flowered)[1]!=0){
  flower = data.frame(c(nFlower, flowered))
  flowered <- select(flower, "X.Arusha.","X.flowering.","accession_name", "submit_date", "submitted_by")
  colnames(flowered) <- c("location","activity","accession","date","contributor")
} else {
  flowered <- data.frame(0)
}

# F.Polln
nFirst = strrep(c("Arusha","firstpollination"), 1)
if(dim(firstpollination)[1]!=0) {
  first = data.frame(c(nFirst, firstpollination))
  first_pollinationed = select(first,"X.Arusha.","X.firstpollination.", "crossnumber", "submission_date", "submitted_by")
  colnames(first_pollinationed) = c("location","activity","accession","date","contributor")
} else {
  first_pollinationed <- data.frame(0)
}

# Repeat Polln
nRepeat = strrep(c("Arusha","repeatpollination"), 1)
if(dim(repeatdf)[1]!=0) {
  repeatP = data.frame(c(nRepeat, repeatdf))
  repeat_pollinationed = select(repeatP,"X.Arusha.","X.repeatpollination.", "crossnumber", "repeatPollinationDate","X_submitted_by")
  colnames(repeat_pollinationed) = c("location","activity","accession","date","contributor")
} else {
  repeat_pollinationed <- data.frame(0)
}

# Harvest
nHarvest = strrep(c("Arusha","harvested"), 1)
if(dim(harvestingdf)[1]!=0){
  Harvest = data.frame(c(nHarvest,harvestingdf))
  harvestdf = select(Harvest,"X.Arusha.", "X.harvested.", "crossnumber", "harvesting_date", "submitted_by")
  colnames(harvestdf) = c("location","activity","accession","date","contributor")
}else {
  harvestdf <- data.frame(0)
}

# Ripening
nRipen = strrep(c("Arusha","ripened"), 1)
if(dim(ripeningdf)[1]!=0){
  ripenD = data.frame(c(nRipen,ripeningdf))
  ripendf = select(ripenD,"X.Arusha.", "X.ripened.", "crossnumber", "ripen_date", "submitted_by")
  colnames(ripendf) = c("location","activity","accession","date","contributor")
}else {
  ripendf <- data.frame(0)
}

# Extracted
nExtr = strrep(c("Arusha","extracted"), 1)
if(dim(extractiondf)[1]!=0){
  Extr = as.data.frame(c(nExtr,extractiondf))
  extracted <- select(Extr,"X.Arusha.", "X.extracted.", "crossnumber", "seed_extraction_date", "submitted_by")
  colnames(extracted) <- c("location","activity","accession","date","contributor")
}else {
  extracted <- data.frame(0)
}
# Rescue
nRescue = strrep(c("Arusha","embryrescued"), 1)
if(dim(rescuingdf)[1]!=0){
  Rescue = as.data.frame(c(nRescue,rescuingdf))
  rescued <- select(Rescue,"X.Arusha.", "X.embryrescued.", "crossnumber", "rescue_date", "submitted_by")
  colnames(rescued) <- c("location","activity","accession","date","contributor")
}else {
  rescued <- data.frame(0)
}
# Germinated after 2wks
n2Wks = strrep(c("Arusha","germinated after 2 weeks"), 1)
if(dim(germination2weeksdf)[1]!=0){
  G2wk = as.data.frame(c(n2Wks,germination2weeksdf))
  germinated_2weeks <- select(G2wk, "X.Arusha.","X.germinated.after.2.weeks.", "crossnumber", "germination_after_2weeks_date", "submitted_by")
  colnames(germinated_2weeks) <- c("location","activity","accession","date","contributor")
}else {
  germinated_2weeks <- data.frame(0)
}

# Germinated after 6weeks
n6weeks = strrep(c("Arusha","germinated after 6 weeks"), 1)
if(dim(germination6weeksdf)[1]!=0){
  G6weeks = as.data.frame(c(n6weeks,germination6weeksdf))
  germinated_6weeks <- select(G6weeks,"X.Arusha.", "X.germinated.after.6.weeks.", "crossnumber", "germination_after_6weeks_date", "submitted_by")
  colnames(germinated_6weeks) <- c("location","activity","accession","date","contributor")
}else {
  germinated_6weeks <- data.frame(0)
}
# Subculture
nSub = strrep(c("Arusha","subcultured"), 1)
if(dim(subculturingdf)[1]!=0){
  Sub = as.data.frame(c(nSub,subculturingdf))
  subculturing <- select(Sub, "X.Arusha.","X.subcultured.", "crossnumber", "subculture_date", "submitted_by")
  colnames(subculturing) <- c("location","activity","accession","date","contributor")
}else {
  subculturing <- data.frame(0)
}
# Rooted
nRoot = strrep(c("Arusha","rooted"), 1)
if(dim(rootingdf)[1]!=0){
  Root = as.data.frame(c(nRoot,rootingdf))
  rooted <- select(Root, "X.Arusha.","X.rooted.", "plantletID", "date_rooting", "submitted_by")
  colnames(rooted) <- c("location","activity","accession","date","contributor")
}else {
  rooted <- data.frame(0)
}
# Screenhse
n.Shse = strrep(c("Arusha","screenhouse"), 1)
if(dim(screenhsedf)[1]!=0){
  S.hse = as.data.frame(c(n.Shse,screenhsedf))
  screen_housed <- select(S.hse,"X.Arusha.", "X.screenhouse.", "plantletID", "screenhse_transfer_date", "submitted_by")
  colnames(screen_housed) <- c("location","activity","accession","date","contributor")
}else {
  screen_housed <- data.frame(0)
}
# Hardened
nHard = strrep(c("Arusha","hardened"), 1)
if(dim(hardeningdf)[1]!=0){
  Hard = as.data.frame(c(nHard,hardeningdf))
  hardened <- select(Hard,"X.Arusha.", "X.hardened.", "plantletID", "hardening_date", "submitted_by")
  colnames(hardened) <- c("location","activity","accession","date","contributor")
}else {
  hardened <- data.frame(0)
}

# Openfield
nOpn = strrep(c("Arusha","openfield"), 1)
if(dim(openfieldtransferdf)[1]!=0){
  opn = as.data.frame(c(nOpn,openfieldtransferdf))
  open_field <- select(opn, "X.Arusha.","X.openfield.", "plantletID", "date_of_transfer_to_openfield", "submitted_by")
  colnames(open_field) <- c("location","activity","accession","date","contributor")
} else {
  open_field <- data.frame(0)
}
# Status
nStatus = strrep(c("Arusha","status"), 1)
if(dim(statusDF)[1]!=0){
  sta = as.data.frame(c(nStatus,statusDF))
  statusD <- select(sta, "X.Arusha.","X.status.", "statusID", "date", "submitted_by")
  colnames(statusD) <- c("location","activity","accession","date","contributor")
} else {
  statusD <- data.frame(0)
}

mylist <- list(flowered,first_pollinationed,repeat_pollinationed, harvestdf,ripendf, extracted,rescued,germinated_2weeks,germinated_6weeks,
               subculturing,rooted,screen_housed,hardened,open_field, statusD)
r <- mylist[[1]]
for (i in 2:length(mylist)) {
  r <- merge(r, mylist[[i]], all=TRUE)
}
cleantable = r
cleanTable = write.csv(r, file = "D:\\github\\ODK_bananaCrossingTool\\Nelson Mandela\\cleantable.csv", row.names = F)

# NUMBER OF ACCESSION IN DIFFERENT STAGES OF PROJECT
all_crosses <- bananadata %>% select("crossnumber","repeatPollinationDate.1","harvesting_date", "ripen_date","seed_extraction_date","rescue_date","germination_after_2weeks_date",
                                  "germination_after_6weeks_date","subculture_date")
nrows<-dim(all_crosses)[1]
firstpollination=0
repeatpollination=0
harvested=0
ripening=0
seedextraction=0
embryorescue=0
germinatingafter2weeks=0
germinatingafter1month=0

# LOOP
for(i in 1:nrows){
  if (is.na(all_crosses$repeatPollinationDate.1[i])){
    firstpollination<-firstpollination+1
  }
  else{
    if(is.na(all_crosses$harvesting_date[i]) & all_crosses$repeatPollinationDate.1[i]!="NULL") {
      repeatpollination<-repeatpollination+1
    }
    else{
      if(is.na(all_crosses$ripen_date[i]) & all_crosses$harvesting_date[i]!="NULL"){
        harvested <- harvested+1
      }
      else{
        if(is.na(all_crosses$seed_extraction_date[i]) & all_crosses$ripen_date[i]!="NULL"){
          ripening <- ripening+1
        }
        else{
          if(is.na(all_crosses$rescue_date[i]) & all_crosses$seed_extraction_date[i]!="NULL"){
            seedextraction = seedextraction+1
          }
          else{
            if(is.na(all_crosses$germination_after_2weeks_date[i]) & all_crosses$rescue_date[i]!="NULL"){
              embryorescue = embryorescue+1
            }
            else{
              if(is.na(all_crosses$germination_after_6weeks_date[i]) & all_crosses$germination_after_2weeks_date[i]!="NULL"){
                germinatingafter2weeks = germinatingafter2weeks+1
              }
              else{
                if(is.na(all_crosses$subculture_date[i]) & all_crosses$germination_after_6weeks_date[i]!="NULL"){
                  germinatingafter1month = germinatingafter1month+1
                }
              }
            }
          }
        }
      }
    }
  }
}
# Planlets
all_plantlets = plantsDF %>% select("crossnumber","plantletID","subculture_date","date_rooting","screenhse_transfer_date",      
                                     "hardening_date","date_of_transfer_to_openfield")
nplants = dim(all_plantlets)[1]
subculture=0
rooting=0
screenhouse=0
hardening=0
openfield=0

# LOOP
for(i in 1:nplants){
  if (is.na(all_plantlets$date_rooting[i])){
    subcultures=subcultures+1
  }
  else{
    if(is.na(all_plantlets$screenhse_transfer_date[i]) & all_plantlets$date_rooting[i]!="NULL") {
      rooting=rooting+1
    }
    else{
      if(is.na(all_plantlets$hardening_date[i]) & all_plantlets$screenhse_transfer_date[i]!="NULL"){
        screenhouse=screenhouse+1
      }
      else{
        if(is.na(all_plantlets$date_of_transfer_to_openfield[i]) & all_plantlets$hardening_date[i]!="NULL"){
          hardening = hardening+1
        }
        else{
          if(all_plantlets$date_of_transfer_to_openfield[i]!="NULL"){
            openfield = openfield+1
          }
        }
      }
    }
  }
}


# Table out
in_activity = c("firstpollination","repeatpollination","harvested","ripening","seedextraction","embryorescue",
           "germinatingafter2weeks","germinatingafter1month","subculture","rooting","screenhouse","hardening","openfield")
number = c(firstpollination,repeatpollination,harvested,ripening,seedextraction,embryorescue,
            germinatingafter2weeks,germinatingafter1month,subculture,rooting,screenhouse,hardening,openfield)
nTable = as.data.frame(cbind(in_activity, number))
n.Table = write.csv(nTable, file="nTable.csv", row.names = F)
