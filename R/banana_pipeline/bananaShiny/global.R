library(dplyr)
library(tidyr)
library(lubridate)
###########
# datasets
Flowers <- read.csv("all_flowering.csv")
flowern = Flowers[,-c(1:2)]
Flowering = flowern[order(flowern$flowering_date,decreasing = TRUE),]
bananadata <- read.csv("bananadata.csv")
statusD = read.csv("status.csv")
statusDDF = statusD[,-1]
statusDF = statusDDF[order(statusDDF$date, decreasing = T)]
Plant_status = statusDF
Contamn = read.csv("contamination.csv")
Contamination = Contamn[,-1]
parentNames = bananadata %>% select("mother_accessionName", "father_accessionName")
colnames(parentNames) = c("mother", "father")
merge_banana = cbind(parentNames, bananadata[,-c(3,5)])
current_data <- merge_banana %>% 
  select("crossnumber", "mother", "father", "firstpollination_date",
         starts_with("father_clone"),starts_with("repeatpollination_date"),"harvesting_date", "days_to_maturity","ripening_date",
         "days_to_maturity","seed_extraction_date","number_seeds", "good_seeds","badseeds", "days_ripening_extraction","number_rescued",
         "rescue_date", "days_extraction_rescue","germination_after_2weeks_date","actively_germination_after_two_weeks","days_rescue_2weeksGermination",
         "germination_after_6weeks_date","actively_germination_after_6weeks","days_2weeksGermination_6weeksGermination")

past_data = read.csv("Last_6_months_tisssue_culture_data.csv")

allData = merge(current_data, past_data, all=TRUE, all.x = T,sort=FALSE)
All_data = select(allData,"crossnumber","mother","father","firstpollination_date",starts_with("father_clone"),starts_with("repeatpollination_date"),"harvesting_date",
       "days_to_maturity","ripening_date","days_to_maturity","seed_extraction_date","number_seeds","days_ripening_extraction","rescue_date","good_seeds",
       "badseeds","number_rescued","days_extraction_rescue","actively_germination_after_6weeks","germination_after_2weeks_date","actively_germination_after_two_weeks",
       "days_rescue_2weeksGermination","germination_after_6weeks_date","days_2weeksGermination_6weeksGermination","contamination")

Firstpollination <- select(All_data,"crossnumber","mother","father","firstpollination_date")
Repeat.Pollination <- select(All_data,"crossnumber","mother","father",starts_with("father_clone"),starts_with("repeatpollination_date"))
RepeatPollination = Repeat.Pollination[complete.cases(Repeat.Pollination),]

Harvested <- select(All_data,"crossnumber","mother","father","harvesting_date","days_to_maturity")
Ripen = select(All_data,"crossnumber","mother","father","ripening_date","days_to_maturity")
Ripened = Ripen[complete.cases(Ripen),]
Seed.extraction <- select(All_data,"crossnumber","mother","father","seed_extraction_date","number_seeds")
Seed_extraction = Seed.extraction[complete.cases(Seed.extraction),]
Embryo.rescue <- select(All_data,"crossnumber","mother","father","rescue_date","number_rescued")
Embryorescue = Embryo.rescue[complete.cases(Embryo.rescue),]
Germinating_two_week <- select(All_data,"crossnumber","mother","father","germination_after_2weeks_date","actively_germination_after_two_weeks")
Germinating_two_weeks = Germinating_two_week[complete.cases(Germinating_two_week),]
Germinating_6week <- select(All_data,"crossnumber","mother","father","germination_after_6weeks_date","actively_germination_after_6weeks")
Germinating_6weeks = germ6wks = Germinating_6week[complete.cases(Germinating_6week),]

# Plantlets 
plantlets <- read.csv("plantlets.csv") 
all_plantlets = plantlets %>%
  select("plantletID","date_rooting","screenhse_transfer_date","days_rooting_screenhse",
         "hardening_date","days_scrnhse_hardening","date_of_transfer_to_openfield","days_hardening_openfield")
Rooting <- select(all_plantlets,"plantletID","date_rooting")
Hardening <- select(all_plantlets,"plantletID","hardening_date","days_scrnhse_hardening")
Screenhouse <- select(all_plantlets,"plantletID","screenhse_transfer_date","days_rooting_screenhse")
Openfield <- select(all_plantlets,"plantletID","date_of_transfer_to_openfield","days_hardening_openfield")


###################
## DATA EXPLORER
location = NA
activity = NA
accession = NA
mother = NA
father = NA
date = NA

nFlower = strrep(c("Arusha","flowering"),1)
if (dim(Flowering)[1]!=0){
  flower = data.frame(c(nFlower, Flowering))
  flowers <- select(flower, "X.Arusha.","X.flowering.","accession_name", "flowering_date")
  flowers$mother = mother
  flowers$father = father
  flowered = select(flowers, "X.Arusha.","X.flowering.","accession_name", "mother","father","flowering_date") 
  colnames(flowered) <- c("location","activity","accession","mother","father","date")
} else {
  flower <- cbind(location, activity,accession, mother, father,date)
  flowered = select(flower, "location","activity","accession","mother","father","date")
}

# F.Polln
nFirst = strrep(c("Arusha","firstpollination"), 1)
if(dim(Firstpollination)[1]!=0) {
  first = data.frame(c(nFirst, Firstpollination))
  first_pollinationed = select(first,"X.Arusha.","X.firstpollination.", "crossnumber", "mother","father","firstpollination_date")
  colnames(first_pollinationed) = c("location","activity","accession","mother","father","date")
} else {
  first_pollinationed <- cbind(location, activity,accession,mother, father,date)
}

# Repeat Polln
nRepeat = strrep(c("Arusha","repeatpollination"), 1)
if(dim(RepeatPollination)[1]!=0) {
  repeatP = data.frame(c(nRepeat, RepeatPollination))
  repeat_pollinationed = select(repeatP,"X.Arusha.","X.repeatpollination.", "crossnumber", "mother","father","repeatpollination_date.1")
  colnames(repeat_pollinationed) = c("location","activity","accession","mother","father","date")
} else {
  repeat_pollinationed <- cbind(location, activity,accession,mother, father,date)
}

# Harvest
nHarvest = strrep(c("Arusha","harvested"), 1)
if(dim(Harvested)[1]!=0){
  Harvest = data.frame(c(nHarvest,Harvested))
  harvestdf = select(Harvest,"X.Arusha.", "X.harvested.", "crossnumber", "mother","father","harvesting_date")
  colnames(harvestdf) = c("location","activity","accession","mother","father","date")
}else {
  harvestdf <- cbind(location, activity,accession,mother, father,date)
}

# Ripening
nRipen = strrep(c("Arusha","ripened"), 1)
if(dim(Ripened)[1]!=0){
  ripenD = data.frame(c(nRipen,Ripened))
  ripendf = select(ripenD,"X.Arusha.", "X.ripened.", "crossnumber", "mother","father","ripening_date")
  colnames(ripendf) = c("location","activity","accession","mother","father","date")
}else {
  ripendf <- cbind(location, activity,accession,mother, father,date)
}

# Extracted
nExtr = strrep(c("Arusha","extracted"), 1)
if(dim(Seed_extraction)[1]!=0){
  Extr = as.data.frame(c(nExtr,Seed_extraction))
  extracted <- select(Extr,"X.Arusha.", "X.extracted.", "crossnumber","mother","father", "seed_extraction_date")
  colnames(extracted) <- c("location","activity","accession","mother","father","date")
}else {
  extracted <- cbind(location, activity,accession,mother, father,date)
}
# Rescue
nRescue = strrep(c("Arusha","embryrescued"), 1)
if(dim(Embryorescue)[1]!=0){
  Rescue = as.data.frame(c(nRescue,Embryorescue))
  rescued <- select(Rescue,"X.Arusha.", "X.embryrescued.", "crossnumber", "mother","father","rescue_date")
  colnames(rescued) <- c("location","activity","accession","mother","father","date")
}else {
  rescued <- cbind(location, activity,accession,mother, father,date)
}
# Germinated after 2wks
n2Wks = strrep(c("Arusha","germinated after 2 weeks"), 1)
if(dim(Germinating_two_weeks)[1]!=0){
  G2wk = as.data.frame(c(n2Wks,Germinating_two_weeks))
  germinated_2weeks <- select(G2wk, "X.Arusha.","X.germinated.after.2.weeks.", "crossnumber","mother","father", "germination_after_2weeks_date")
  colnames(germinated_2weeks) <- c("location","activity","accession","mother","father","date")
}else {
  germinated_2weeks <- cbind(location, activity,accession,mother, father,date)
}

# Germinated after 6weeks
n6weeks = strrep(c("Arusha","germinated after 6 weeks"), 1)
if(dim(Germinating_6weeks)[1]!=0){
  G6weeks = as.data.frame(c(n6weeks,Germinating_6weeks))
  germinated_6weeks <- select(G6weeks,"X.Arusha.", "X.germinated.after.6.weeks.", "crossnumber", "mother","father","germination_after_6weeks_date")
  colnames(germinated_6weeks) <- c("location","activity","accession","mother","father","date")
}else {
  germinated_6weeks <- cbind(location, activity,accession,mother, father,date)
}

# Rooted
nRoot = strrep(c("Arusha","rooted"), 1)
if(dim(Rooting)[1]!=0){
  Root = as.data.frame(c(nRoot,Rooting))
  rooted <- select(Root, "X.Arusha.","X.rooted.", "plantletID","date_rooting")
  rooted$mother = 0
  rooted$father = 0
  colnames(rooted) <- c("location","activity","accession","date","mother","father")
}else {
  rooted <- cbind(location, activity,accession,date,mother, father)
}
# Screenhse
n.Shse = strrep(c("Arusha","screenhouse"), 1)
if(dim(Screenhouse)[1]!=0){
  S.hse = as.data.frame(c(n.Shse,Screenhouse))
  screen_housed <- select(S.hse,"X.Arusha.", "X.screenhouse.", "plantletID","screenhse_transfer_date")
  screen_housed$mother = 0
  screen_housed$father = 0
  colnames(screen_housed) <- c("location","activity","accession","date","mother","father")
}else {
  screen_housed <- cbind(location, activity,accession,date,mother, father)
}
# Hardened
nHard = strrep(c("Arusha","hardened"), 1)
if(dim(Hardening)[1]!=0){
  Hard = as.data.frame(c(nHard,Hardening))
  hardened <- select(Hard,"X.Arusha.", "X.hardened.", "plantletID", "hardening_date")
  hardened$mother = 0
  hardened$father = 0
  colnames(hardened) <- c("location","activity","accession","date","mother","father")
}else {
  hardened <- cbind(location, activity,accession,date,mother, father)
}

# Openfield
nOpn = strrep(c("Arusha","openfield"), 1)
if(dim(Openfield)[1]!=0){
  opn = as.data.frame(c(nOpn,Openfield))
  open_field <- select(opn, "X.Arusha.","X.openfield.", "plantletID","date_of_transfer_to_openfield")
  open_field$mother = 0
  open_field$father = 0
  colnames(open_field) <- c("location","activity","accession","date","mother","father")
} else {
  open_field <- cbind(location, activity,accession,date,mother, father)
}
# Status
nStatus = strrep(c("Arusha","status"), 1)
if(dim(statusDF)[1]!=0){
  sta = as.data.frame(c(nStatus,statusDF))
  statusD <- select(sta, "X.Arusha.","X.status.", "statusID", "date")
  colnames(statusD) <- c("location","activity","accession","date")
} else {
  statusD <- cbind(location, activity,accession,mother, father,date)
}

mylist <- list(flowered,first_pollinationed,repeat_pollinationed, harvestdf,ripendf, extracted,rescued,germinated_2weeks,germinated_6weeks)
r <- mylist[[1]]
for (i in 2:length(mylist)) {
  r <- merge(r, mylist[[i]], all=TRUE)
}
cleantable = r[complete.cases(r[ , 1]),]

# drill down
summary_cleantable <- group_by(cleantable, activity) %>%
  summarise(Count = n())


# Tables

clean_sort = cleantable[rev(order(as.Date(cleantable$date))),]
table_date = table(clean_sort$date)
uniqdate = unique(clean_sort$date)
subs = cbind(uniqdate,table_date)
colnames(subs) = c("Date","Number")
dates = rownames(subs)
subs$date = as.data.frame(dates)
rownames(subs)<-NULL
#subs = subs[,-1]
submission = as.data.frame(subs)


# CURRENT NUMBER OF ACCESSION AT DIFFERENT STAGES OF PROJECT
all_crosses <- All_data %>% select("crossnumber","repeatpollination_date.1","harvesting_date", "ripening_date","seed_extraction_date","rescue_date","germination_after_2weeks_date")
nrows<-dim(all_crosses)[1]
firstpollination=0
repeatpollination=0
harvested=0
ripening=0
seedextraction=0
embryorescue=0
germinatingafter2weeks=0
germinatingafter6weeks=0

# LOOP
for(i in 1:nrows){
  if (is.na(all_crosses$repeatpollination_date.1[i])){
    firstpollination<-firstpollination+1
  }
  else{
    if(is.na(all_crosses$harvesting_date[i]) & all_crosses$repeatpollination_date.1[i]!="NULL") {
      repeatpollination<-repeatpollination+1
    }
    else{
      if(is.na(all_crosses$ripening_date[i]) & all_crosses$harvesting_date[i]!="NULL"){
        harvested <- harvested+1
      }
      else{
        if(is.na(all_crosses$seed_extraction_date[i]) & all_crosses$ripening_date[i]!="NULL"){
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
            #else{
             # if(is.na(all_crosses$germination_after_6weeks_date[i]) & all_crosses$germination_after_2weeks_date[i]!="NULL"){
              #  germinatingafter2weeks = germinatingafter2weeks+1
              #}
              #else{
              #  if(is.na(all_crosses$subculture_date[i]) & all_crosses$germination_after_6weeks_date[i]!="NULL"){
              #    germinatingafter1month = germinatingafter1month+1
              #  }
              #}
            #}
          }
        }
      }
    }
  }
}
# Planlets
plantlets = all_plantlets  %>% select("plantletID","date_rooting","screenhse_transfer_date",      
                                    "hardening_date","date_of_transfer_to_openfield")
nplants = dim(plantlets)[1]
subcultures=0
rooting=0
screenhouse=0
hardening=0
openfield=0

# LOOP
#for(i in 1:nplants){
 # if (is.na(plantlets$date_rooting[i])){
#    subcultures=subcultures+1
#  }
#  else{
#    if(is.na(plantlets$screenhse_transfer_date[i]) & !is.na(plantlets$date_rooting[i])) {
#      rooting=rooting+1
#    }
#    else{
#      if(is.na(plantlets$hardening_date[i]) & plantlets$screenhse_transfer_date[i]!="NULL"){
#        screenhouse=screenhouse+1
#      }
#      else{
#        if(is.na(plantlets$date_of_transfer_to_openfield[i]) & plantlets$hardening_date[i]!="NULL"){
#          hardening = hardening+1
#        }
#        else{
#          if(plantlets$date_of_transfer_to_openfield[i]!="NULL"){
#            openfield = openfield+1
#          }
#        }
#      }
#    }
#  }
#}


# Table output
IN = c("firstpollination","repeatpollination","harvested","ripening","seedextraction","embryorescue",
       "germinatingafter2weeks","germinatingafter1month","rooting","screenhouse","hardening","openfield")
NUMBER = c(firstpollination,repeatpollination,harvested,ripening,seedextraction,embryorescue,
           germinatingafter2weeks,germinatingafter6weeks,rooting,screenhouse,hardening,openfield)
nTable = as.data.frame(cbind(IN, NUMBER))
n.Table = write.csv(nTable, file="nTable.csv", row.names = F)

