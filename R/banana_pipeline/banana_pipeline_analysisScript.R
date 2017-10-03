  ## prepare workspace
  cat("\014") # clear console
  setwd("D:\\github\\bananaShiny")
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
  flowerID = select(banana, contains("floweringID")) %>%
    gather(flowering, flowerID, ends_with("floweringID"), na.rm = T)
  flowerID$flowering <- NULL
  flower <- as.data.frame(flowerID$flowerID)
  flowerName = select(banana, ends_with("flowerName")) %>%
    gather(flower, accession_name, ends_with("flowerName"), na.rm=T)
  flowerName$flower <- NULL
  flowerIDs = as.data.frame(c(flowerID, flower, flowerName))
  colnames(flowerIDs) = c("flowerID","flower","accession_name")
  pSex <- select(banana, ends_with("plantSex")) %>%
    gather(psex, sex, ends_with("plantSex"), na.rm = T)
  pSex$psex <- NULL  
  floweringDate <- select(banana, ends_with("flowering_date")) %>%
    gather(date, flowering_date, ends_with("flowering_date"), na.rm = T)
  floweringDate$date <- NULL
  flowered <- as.data.frame(c(flowerIDs, pSex, floweringDate))
  fDate = as.Date(flowered$flowering_date)
  fdateLimit = Sys.Date() - 10
  floweringd = filter(flowered, fDate>=fdateLimit)
  flowering <- floweringd[order(floweringd$flowering_date),]
  
  # FIRST POLLINATION
  FPOLLN = select(banana, contains("FirstPollination"))
  parent <- select(FPOLLN, ends_with("parent")) %>%
    gather(parents, parentName, ends_with("parent"), na.rm = T)
  parent$parents <- NULL
  parent.ID = as.data.frame(str_split_fixed(parent$parentName, "/", 2))
  colnames(parent.ID) <- c("mother", "father")
  parentID = as.data.frame(cbind(gsub("[(]","",parent.ID$mother),gsub(")","",parent.ID$father)))
  colnames(parentID) <- c("mother", "father")
  femaleID <- as.data.frame(parentID$mother)
  female.acc.name = select(FPOLLN, ends_with("femaleName"))%>%
    gather(female, mother.acc.name, ends_with("femaleName"), na.rm=T)
  female.acc.name$female <- NULL
  male.acc.name = select(FPOLLN, ends_with("maleAccName"))%>%
    gather(male, father.acc.name, ends_with("maleAccName"), na.rm=T)
  male.acc.name$male <- NULL
  
  parents = as.data.frame(c(parent, femaleID, parentID, female.acc.name, male.acc.name))
  firstDate <- select(FPOLLN, ends_with("firstpollination_date")) %>%
    gather(date, firstpollination_date, ends_with("firstpollination_date"), na.rm = T)
  firstDate$date <- NULL
  cross <- select(FPOLLN, ends_with("crossID")) %>%
    gather(cross, crossnumber, ends_with("crossID"), na.rm = T)
  cross$cross <- NULL
  crossID <- as.data.frame(cross$crossnumber)
  first_pollination <- as.data.frame(c(parents, cross, firstDate, crossID))
  
  colnames(first_pollination) <- c("parentNames","femaleID",
                                  "mother","father","mother_accessionName","father_accessionName","crossnumber","firstpollination_date","crossID")
  firstpollination = as.data.frame(first_pollination[,c(7,2,3,5,4,6,8,9)])
  
  # Repeat pollination
  rpt = select(banana,contains("repeatpollination"))
  getCrossID = select(rpt, ends_with("getCrossID")) %>%
    gather(cross, crossnumber, ends_with("getCrossID"), na.rm = T)
  getCrossID$cross <- NULL
  rptMale_AccName = select(rpt, ends_with("getRptMaleAccName")) %>%
    gather(rptMale, Male, ends_with("getRptMaleAccName"), na.rm = T)
  rptMale_AccName$rptMale <- NULL
  rptPollnDate = select(rpt, ends_with("rptpollination_date")) %>%
    gather(date, repeatPollinationDate, ends_with("rptpollination_date"), na.rm = T)
  rptPollnDate$date <- NULL
  getMotherName = select(rpt, ends_with("getRptFemaleAccName"))%>%
    gather(mother, motherName, ends_with("getRptFemaleAccName"), na.rm = T)
  getMotherName$mother <- NULL
  
  repeatData <- as.data.frame(c(getCrossID,getMotherName, rptMale_AccName, rptPollnDate))
  repeatdf = select(repeatData,"crossnumber","motherName","Male","repeatPollinationDate")
  colnames(repeatdf) = c("crossnumber","mother_accession","father_clone","repeatpollination_date.1")
  if(dim(repeatdf)[1]>0){
  repeatdt = data.table(repeatdf)
  repeatDT = as.data.frame(repeatdt[,number := 1:.N, by = crossnumber])
  repeatDTwide = reshape(repeatDT,direction = "wide", idvar = "crossnumber", timevar = "number")
  repeatID = data.frame(repeatDTwide$crossnumber)
  colnames(repeatID) <- "repeatpollinationID"
  repeatDT.wide <- data.frame(c(repeatID, repeatDTwide))
  } else {
    repeatDT.wide = repeatdf
  }
  # HARVESTING
  harVEST = select(banana, contains("harvesting"))
  harvestedID = select(harVEST, ends_with("harvestID")) %>%
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
  
  harvested = as.data.frame(c(harvestedID, harvestID,harvestdate, pollination2Harvest, ripeningshed))
  harvested$pollinationDATE <- NULL
  harvested$harvestDATE <- NULL
  harvested$X_submission_time <- NULL
  harvestingdf = select(harvested,crossnumber,harvestedID.crossnumber, harvesting_date, days2Maturity)
  colnames(harvestingdf) = c("crossnumber", "harvestID", "harvesting_date","days_to_maturity")
  
  # RIPENING
  ripen_date = select(banana, ends_with("ripening_date"))%>%
    gather(date, ripening_date, ends_with("ripening_date"), na.rm = T)
  
  if(dim(ripen_date)[1]>0){
  RIPEN = select(banana,contains("record_ripening"))
  ripenid = select(RIPEN,ends_with("ripenedID")) %>%
    gather(ids, crossnumber, ends_with("ripenedID"), na.rm  = T)
  ripenid$ripenID = ripenid$crossnumber
  ripenid$ids <- NULL
  getHarDate = select(RIPEN, ends_with("getHarvest_date")) %>%
    gather(date, dateHarvested, ends_with("getHarvest_date"), na.rm = T)
  dateHarv = str_replace(getHarDate$dateHarvested, "-", "/")
  dateHarvest = str_replace(dateHarv, "-", "/")
  
  ripendate = select(RIPEN, ends_with("equal_ripening_date")) %>% 
    gather(date, ripen_date, ends_with("equal_ripening_date"), na.rm = T)
  dateRipe = str_replace(ripendate$ripen_date, "-", "/")
  dateRipened = str_replace(dateRipe, "-", "/")
  Harvest2Ripening = data.frame(dateHarvest, dateRipened)
  Harvest2Ripening$days_harvest_ripening <- as.Date(as.character(Harvest2Ripening$dateRipened), format="%Y/%m/%d")-
    as.Date(as.character(Harvest2Ripening$dateHarvest), format="%Y/%m/%d")
  Harvest2Ripening$dateRipened <- NULL
  Harvest2Ripening$dateHarvest <- NULL
  ripened = as.data.frame(c(ripenid, ripenID,ripendate, Harvest2Ripening))
  ripeningdf = select(ripened,crossnumber, ripenid.crossnumber, ripen_date, days_harvest_ripening)
  colnames(ripeningdf) = c("crossnumber", "ripenID","ripen_date","days_harvest_ripening")
  } else{
    colnames(ripen_date) = c("crossnumber","ripening_date")
    ripeningdf = ripen_date
  }
  # EXTRACTION
  EXTRACTION = select(banana, contains("seedExtraction"))
  extractid = select(EXTRACTION, ends_with("extractionID")) %>%
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
  extracted = as.data.frame(c(extractid, extractID,extractdate, total, ripen2Extract))
  extractiondf = select(extracted,crossnumber,extractid.crossnumber, seed_extraction_date, number_seeds, days_ripening_extraction)
  colnames(extractiondf) = c("crossnumber", "extractID","seed_extraction_date", "number_seeds", 
                             "days_ripening_extraction")
  
  ## STOLEN
  # mother
  statuses = select(banana,contains("plantstatus"))
  stolen.type = select(statuses, ends_with("plant_status")) %>%
    gather(type, status, ends_with("plant_status"), na.rm = T) %>%
    filter(status=="bunch_stolen")
  mother.stolenID = select(statuses, ends_with("stolen_statusID"))%>%
    gather(mother.status, motherID, ends_with("stolen_statusID"), na.rm = T)
  mother.stolen.ID <- data.frame(mother.stolenID$motherID)
  stolendate = select(statuses, ends_with("stolen_date")) %>%
    gather(date, stolen_date, ends_with("stolen_date"), na.rm = T)
  mother.stolen.status = as.data.frame(c(mother.stolenID, mother.stolen.ID, stolendate, stolen.type))
  mother.stolendf = select(mother.stolen.status,motherID, mother.stolenID.motherID, stolen_date, status)
  colnames(mother.stolendf) = c("ID", "statusID","date", "status")
  
  # stolen cross
  cross.stolenID = select(statuses, ends_with("stolenBunch_statusID"))%>%
    gather(cross.status, crossID, ends_with("stolenBunch_statusID"), na.rm = T)
  cross.stolen.ID <- data.frame(cross.stolenID$crossID)
  if(dim(mother.stolendf)[1]>0 & dim(cross.stolenID)[1]>0){
    cross.stolen.status = as.data.frame(c(cross.stolenID, cross.stolen.ID, stolendate, stolen.type))
    cross.stolendf = select(cross.stolen.status,crossID, cross.stolenID.crossID, stolen_date, status)
    colnames(cross.stolendf) = c("ID", "statusID","date", "status")
    stolendf = rbind(mother.stolendf, cross.stolendf)
  } else {
    stolendf = mother.stolendf
  }
  
  # Fallen mother
  fallen.type = select(statuses, ends_with("plant_status")) %>%
    gather(type, status, ends_with("plant_status"), na.rm = T) %>%
    filter(status=="fallen")
  mother.fallenID = select(statuses,ends_with("fallen_statusID"))%>%
    gather(mother.status, motherID, ends_with("fallen_statusID"), na.rm = T)
  mother.fallen.ID <- data.frame(mother.fallenID$motherID)
  fallendate = select(statuses, ends_with("fallen_date")) %>%
    gather(date, fallen_date, ends_with("fallen_date"), na.rm = T)
  
  mother.fallen.status = as.data.frame(c(mother.fallenID, mother.fallen.ID, fallendate, fallen.type))
  mother.fallendf = select(mother.fallen.status, motherID, mother.fallenID.motherID, fallen_date, status)
  colnames(mother.fallendf) = c("ID", "statusID","date", "status")
  
  # fallen cross
  cross.fallenID = select(statuses,ends_with("fallenBunch_statusID"))%>%
    gather(cross.status, crossID, ends_with("fallenBunch_statusID"), na.rm = T)
  cross.fallen.ID <- data.frame(cross.fallenID$crossID)
  if(dim(mother.fallendf)[1]>0 & dim(cross.fallenID)[1]>0){
    cross.fallen.status = as.data.frame(c(cross.fallenID, cross.fallen.ID, fallendate, fallen.type))
    cross.fallendf = select(cross.fallen.status,crossID, cross.fallenID.crossID, fallen_date, status)
    colnames(cross.fallendf) = c("ID", "statusID","date", "status")
    fallendf = rbind(mother.fallendf, cross.fallendf)
  } else {
    fallendf = mother.fallendf
  }
  
  # Other statuses
  target = c("has_disease","died","unusual","okay")
  othertype = select(statuses, ends_with("plant_status")) %>%
    gather(type, status, ends_with("plant_status"), na.rm = T) %>%
    filter(status %in% target)
  otherID = select(statuses,ends_with("plant_statusID"))%>%
    gather(status, ID, ends_with("plant_statusID"), na.rm = T)
  other.ID <- data.frame(otherID$ID)
  other.date = select(statuses, ends_with("status_Date")) %>%
    gather(sdate, date, ends_with("status_Date"), na.rm = T)
  
  otherstatus = as.data.frame(c(other.date, otherID, other.ID, other.date, othertype))
  otherdf = select(otherstatus,ID, otherID.ID, date, status.1)
  colnames(otherdf) = c("ID", "statusID","date", "status")
  
  statusDF = rbind(stolendf, fallendf, otherdf)
  
  ## LAB
  # RESCUE
  good = select(banana, ends_with("goodSeeds")) %>%
    gather(good, good_seeds,ends_with("goodSeeds"), na.rm = T)
  bad = select(banana, ends_with("badSeeds")) %>%
    gather(bad, bad_seeds, ends_with("badSeeds"),na.rm = T)
  RESCUED = select(banana, contains("embryoRescue"))
  rescueid = select(RESCUED, ends_with("embryorescueID"))%>%
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
  rescued = as.data.frame(c(rescueid,rescueID,good, bad, rescuedate, rescueseeds, Extract2Rescue))
  rescuingdf = select(rescued, crossnumber, rescueid.crossnumber, good_seeds, bad_seeds, number_rescued, rescue_date, days_extraction_rescue)
  colnames(rescuingdf) = c("crossnumber", "rescueID","good_seeds","badseeds","number_rescued", "rescue_date", "days_extraction_rescue")
  
  # 2 WEEKS GERMINATION
  week2Germination = select(banana, contains("embryo_germinatn_after_2wks") )
  twowksID = select(week2Germination,ends_with("germinating_2wksID")) %>%
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
  germination2weeks = as.data.frame(c(twowksID, week2ID, twowksDate, active2wks, Rescue_2wks))
  germination2weeksdf = select(germination2weeks,crossnumber,twowksID.crossnumber, germination_after_2weeks_date, actively_germination_after_two_weeks, days_rescue_2wksGermination)
  colnames(germination2weeksdf) = c("crossnumber", "week2ID","germination_after_2weeks_date", 
                                  "actively_germination_after_two_weeks","days_rescue_2weeksGermination")
  
  # 6 weeks GERMINATION
  week6 = select(banana, contains("embryo_germinatn_after_6weeks"))
  week6ID = select(week6, ends_with("germinating_6weeksID"))%>%
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
  germination6weeks = as.data.frame(c(week6ID, week6.ID, week6Date, active6weeks, Germination_2wks_6weeks))
  germination6weeksdf = select(germination6weeks, crossnumber,week6ID.crossnumber, germination_after_6weeks_date, actively_germination_after_6weeks, days_2weeks_6weeks_Germination)
  colnames(germination6weeksdf) = c("crossnumber", "week6ID","germination_after_6weeks_date",
                                    "actively_germination_after_6weeks", "days_2weeksGermination_6weeksGermination")
  # Seeds germinating after 6 weeks
  if(dim(germination6weeksdf)[1]>0){
  seeds_germinating_after_6weeks = select(week6,ends_with("activeID"))%>%
    gather(id, seed_id, ends_with("activeID"), na.rm=T)
  seeds_germinating_after_6weeks$id <- NULL
  seeds_germinating_after_6weeks$id = seeds_germinating_after_6weeks$seed_id
  cross_seedID = data.frame(str_sub(seeds_germinating_after_6weeks$id, 1, str_length(seeds_germinating_after_6weeks$id)-2))
  colnames(cross_seedID) = "crossnumber"
  seed_date = select(week6, ends_with("active_date"))%>%
    gather(mo, mother, ends_with("active_date"), na.rm = T)
  getMother = select(week6, ends_with("active_mother"))%>%
    gather(mo, mother, ends_with("active_mother"), na.rm = T)
  getMother$mo <- NULL
  getFather = select(week6, ends_with("active_father"))%>%
    gather(fa, father, ends_with("active_father"), na.rm = T)
  getFather$fa <- NULL
  seeds_data = data.frame(c(cross_seedID,seeds_germinating_after_6weeks, getMother, getFather))
  } else{
    crossnumber = 0; seed_id = 0; seeds_germinating_after_6weeks = 0; mother = 0; father = 0
    seeds_data = data.frame(cbind(crossnumber,seed_id,seeds_germinating_after_6weeks,mother,father))
  }
  
  # SUBCULTURE
  SUBCT = select(banana, contains("subculturing"))
  subcultureid = select(SUBCT, ends_with("subcultureID"))%>%
    gather(ids, crossnumber, ends_with("subcultureID"), na.rm = T)
  subcultureID <- data.frame(subcultureid$crossnumber)
  subcdate = select(SUBCT, ends_with("subculture_date")) %>%
    gather(date, subculture_date, ends_with("subculture_date"),na.rm = T)
  subDate = str_replace(subcdate$subculture_date, "-","/")
  subdDate = str_replace(subDate,"-","/")
  subcultures = select(SUBCT, ends_with("multiplicationNumber")) %>% 
    gather(date, subcultures,ends_with("multiplicationNumber"), na.rm = T)
  subculturin = as.data.frame(c(subcultureid, subcultureID, subcdate, subcultures))
  subculturingdf = select(subculturin, crossnumber, subcultureid.crossnumber, subculture_date, subcultures)
  colnames(subculturingdf) = c( "crossnumber","subcultureID", "subculture_date","subcultures")

# Subcultures
if(is.na(SUBCT$Laboratory.subculturing.multiplicationNumber)){
  id = 0
  sub_id = 0
  subIDs = cbind(sub_id, id)
  colnames(subIDs) = c("sub_id","id")
} else{
subids = select(SUBCT, ends_with("multiplicationID"))%>%
  gather(id, sub_id, ends_with("multiplicationID"), na.rm=T)
subids$id <- NULL
subids$id = subids$sub_id
subIDs = subids
}
# ROOTING
ROOT = select(banana, contains("rooting"))
rootid = select(ROOT, ends_with("rootingID")) %>% 
  gather(id, plantletID, ends_with("rootingID"),na.rm = T)
rootID <- data.frame(rootid$plantletID)

rootdate = select(ROOT, ends_with("rooting_date")) %>%
  gather(date, date_rooting, ends_with("rooting_date"),na.rm = T)
rootDate = str_replace(rootdate$date_rooting, "-","/")
rDate = str_replace(rootDate,"-","/")
rootin = as.data.frame(c(rootid, rootID, rootdate))
rootingdf = select(rootin,plantletID, rootid.plantletID, date_rooting)
colnames(rootingdf) = c("plantletID","rootID", "date_rooting")

# SCREEN HOUSE
HOUSE = select(banana, contains("screenhouse"))
transferscrnhseid = select(HOUSE, ends_with("screenhseID")) %>%
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
transferscreenhse = as.data.frame(c(transferscrnhseid, transferscrnhseID, transferdate, rooting2Screenhse))
screenhsedf = select(transferscreenhse, plantletID,transferscrnhseid.plantletID, date_of_transfer_to_screenhse,days_rooting_screenhse)      #transfer to screenhsedf
colnames(screenhsedf) = c("plantletID", "transferscrnhseID","screenhse_transfer_date","days_rooting_screenhse")

# Hardening
HARD = select(banana, contains("hardening"))
hardenedid = select(HARD, ends_with("hardeningID")) %>%
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
hardening = as.data.frame(c(hardenedid,hardenID, hardeneddate, screenhse2Hardening))
hardeningdf = select(hardening,plantletID, hardenedid.plantletID,hardening_date, days_scrnhse_hardening)  ## hardening
colnames(hardeningdf) = c("plantletID","hardenID", "hardening_date", "days_scrnhse_hardening")

# Open field
OPEN = select(banana, contains("transplant_openfield"))
openfield_ID = select(OPEN,ends_with("openfieldID")) %>%
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
openfieldtransfer = as.data.frame(c( openfield_ID,openfieldID, opendate, harden2OField))
openfieldtransferdf = select(openfieldtransfer, plantletID,openfield_ID.plantletID,date_of_transfer_to_openfield, days_hardening_openfield) #to open field
colnames(openfieldtransferdf) = c("plantletID", "openfieldID","date_of_transfer_to_openfield",
                                  "days_hardening_openfield")

# Screenhouse status
sstatus = select(banana, contains("screenhse_status"))
sstatusDate = select(sstatus, ends_with("scrnhsestatus_Date"))%>%
  gather(sdate,date, ends_with("scrnhsestatus_Date"), na.rm = T)
sstatusDate$sdate <-NULL
sstatusID = select(sstatus, ends_with("scrnhse_statusID"))%>%
  gather(ssID, statusID, ends_with("scrnhse_statusID"), na.rm = T)
sstatusID$ssID <- NULL
s.status = select(sstatus, ends_with("scrnhseStatus"))%>%
  gather(sstatus, status, ends_with("scrnhseStatus"), na.rm = T)
s.status$sstatus <- NULL
scrnhse.status = data.frame(c(sstatusID, sstatusDate, s.status))
scrnhse.status$ID = scrnhse.status$statusID
colnames(scrnhse.status) = c("statusID", "date","status","ID")
select(scrnhse.status, "ID","statusID","date","status")

merged_status = rbind(statusDF, scrnhse.status)

# Contamination
ContaminID <- select(banana,ends_with("econtaminationID")) %>%
  gather(contamination, crossnumber, ends_with("econtaminationID"), na.rm = T)
contaminationID <- data.frame(ContaminID$crossnumber)
ContaminDate <- select(banana, ends_with("contamination_date")) %>%
  gather(date, contamination_date, ends_with("contamination_date"), na.rm = T)
contaminated = select(banana, ends_with("contaminated")) %>%
  gather(contamination, contaminated, ends_with("contaminated"), na.rm=T)

contamination <- as.data.frame(c(ContaminID, contaminationID, ContaminDate, contaminated)) %>%
  select(crossnumber,ContaminID.crossnumber, contamination_date, contaminated)
colnames(contamination) <- c("crossnumber","contaminationID","contamination_date","contamination")
contamination$time <- NULL

## ALL DATA
floweringDF <- write.csv(flowering, file = "flowering.csv", row.names = F)
all.flowering <- write.csv(flowered, file = "all_flowering.csv", row.names = F)
write.csv(seeds_data,file = "seeds_germinating_after_6weeks.csv", row.names = F)
subplants = write.csv(subIDs, file = "subcultures.csv", row.names = F)
merged.status = write.csv(merged_status, file = "status.csv", row.names = F)
contamin <- write.csv(contamination, file = "contamination.csv", row.names = F)
allbanana = list(firstpollination, repeatDT.wide, harvestingdf, ripeningdf, extractiondf, rescuingdf, germination2weeksdf,germination6weeksdf)                   
bananadat = Reduce(function(x,y) merge(x,y, all = T, by= "crossnumber"), allbanana)
bananadata = select(bananadat, crossnumber, everything())
bananadata1 = write.csv(bananadata, file = "bananadata.csv", row.names = F)

## plantlets
allplantlets = list(rootingdf, screenhsedf, hardeningdf, openfieldtransferdf)
merge_plantlets = Reduce(function(x,y) merge(x,y, all=T, by = "plantletID"), allplantlets)
plantsDF = select(merge_plantlets, plantletID, everything())
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
    attach_file("D:\\github\\bananaShiny\\statusReport.csv") -> file_attachment
  
  send_message(file_attachment)
}

## POST MEDIA FILES TO ONA
# Get tokens
raw.result <- GET("https://api.ona.io/api/v1/user.json", authenticate(user = "seedtracker",password = "Seedtracking101"))
raw.result.char<-rawToChar(raw.result$content)
raw.result.json<-fromJSON(raw.result.char)
TOKEN_KEY <- raw.result.json$temp_token

# DELETE CSV FILES
# flowering
meta_flowerid <- readChar("D:\\github\\bananaShiny\\metadata_flowerid.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_flowerid),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# seeds germinating after 6 weeks
meta_germ_6weeks <- readChar("D:\\github\\bananaShiny\\metadata_germ_6weeks.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_germ_6weeks),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# bananadata
meta_bananaid <- readChar("D:\\github\\bananaShiny\\metadata_bananaid.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_bananaid),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# Status
meta_statusID <- readChar("D:\\github\\bananaShiny\\metadata_statusID.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_statusID),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# Contamination
meta_contaminationID <- readChar("D:\\github\\bananaShiny\\metadata_contaminationID.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_contaminationID),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# Plantlets
meta_plantletsID = readChar("D:\\github\\bananaShiny\\metadata_plantletsID.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_plantletsID),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

# subculture
meta_subcultureID = readChar("D:\\github\\bananaShiny\\metadata_subculture.txt", 10)
hdr=c(Authorization=paste("Temptoken ",TOKEN_KEY))
DELETE(paste("https://api.ona.io/api/v1/metadata/",meta_subcultureID),add_headers(Authorization=paste("Temptoken ",TOKEN_KEY)))

## UPLOAD FLOWERING DATA
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.flower.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='flowering.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\bananaShiny\\flowering.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)
# germination after 6 weeks
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.germ_6weeks.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='seeds_germinating_after_6weeks.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\bananaShiny\\seeds_germinating_after_6weeks.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)
# upload bananadata
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.banana.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='bananadata.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\bananaShiny\\bananadata.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)
# status upload
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.status.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='status.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\bananaShiny\\status.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)

# contamination upload
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.contamination.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                data_value='contamination.csv',data_type='media',xform=237289,
                                data_file=fileUpload(filename = "D:\\github\\bananaShiny\\contamination.csv",contentType = 'text/csv'),
                                .opts=list(httpheader=header), verbose = TRUE)

# Plantlets upload
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.plantlets.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                       data_value='plantlets.csv',data_type='media',xform=237289,
                                       data_file=fileUpload(filename = "D:\\github\\bananaShiny\\plantlets.csv",contentType = 'text/csv'),
                                       .opts=list(httpheader=header), verbose = TRUE)
# subculture
header=c(Authorization=paste("Temptoken ", TOKEN_KEY), `Content-Type` = 'multipart/form-data')
post.subculture.results <- postForm("https://api.ona.io/api/v1/metadata.json",
                                   data_value='subcultures.csv',data_type='media',xform=237289,
                                   data_file=fileUpload(filename = "D:\\github\\bananaShiny\\subcultures.csv",contentType = 'text/csv'),
                                   .opts=list(httpheader=header), verbose = TRUE)


## get ID
# flowerID
flower.raw.result.json<-fromJSON(post.flower.results)
metadata_flowerid <- flower.raw.result.json$id
meta_flower <- cat(metadata_flowerid, file = "D:\\github\\bananaShiny\\metadata_flowerid.txt")

# Bananadata ID
banana.raw.result.json<-fromJSON(post.banana.results)
metadata_bananaid <- banana.raw.result.json$id
meta_flower <- cat(metadata_bananaid, file = "D:\\github\\bananaShiny\\metadata_bananaid.txt")

# get status ID
status.raw.result.json<-fromJSON(post.status.results)
metadata_statusid <- status.raw.result.json$id
meta_status <- cat(metadata_statusid, file = "D:\\github\\bananaShiny\\metadata_statusID.txt")

# get contamination ID
contamination.raw.result.json<-fromJSON(post.contamination.results)
metadata_contaminationid <- contamination.raw.result.json$id
meta_contamination <- cat(metadata_contaminationid, file = "D:\\github\\bananaShiny\\metadata_contaminationID.txt")

# get plantlets ID
plantlets.raw.result.json<-fromJSON(post.plantlets.results)
metadata_plantletsid <- plantlets.raw.result.json$id
meta_plantlets <- cat(metadata_plantletsid, file = "D:\\github\\bananaShiny\\metadata_plantletsID.txt")

# germinating after 6 weeks
germ_6weeks.raw.result.json<-fromJSON(post.germ_6weeks.results)
metadata_germ_6weeks <- germ_6weeks.raw.result.json$id
meta_germ_6weeks <- cat(metadata_germ_6weeks, file = "D:\\github\\bananaShiny\\metadata_germ_6weeks.txt")

# subculture
subculture.raw.result.json<-fromJSON(post.subculture.results)
metadata_subculture <- subculture.raw.result.json$id
meta_subculture <- cat(metadata_subculture, file = "D:\\github\\bananaShiny\\metadata_subculture.txt")
