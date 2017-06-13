



import csv, time,random, sys
cols = ['studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber', 'Variable']
study_count = 4
accession_count = 50
value_range = (0,100)
value_wobble = 30

def make_row(study,accession,base_value):
    studyYear = "2038"
    studyDbId = str(study)
    studyName = "Study"+str(study)
    studyDesign = "chaos"
    locationDbId = "00800"
    locationName = "The Moon"
    germplasmDbId = accession
    germplasmName = "AN"+str(accession)
    germplasmSynonyms = ''
    observationLevel = "plot"
    observationUnitDbId = "MoonPot"+str(accession)
    observationUnitName = "MoonPot"+str(accession)
    replicate = "1"
    blockNumber = "1"
    plotNumber = str(accession)
    variable = str(max(0,base_value + random.randint(-value_wobble,value_wobble)))
    return [studyYear,studyDbId,studyName,studyDesign,locationDbId,locationName,germplasmDbId,germplasmName,germplasmSynonyms,observationLevel,observationUnitDbId,observationUnitName,replicate,blockNumber,plotNumber,variable]

# with open("generated.csv","w") as outfile:
writer = csv.writer(sys.stdout,delimiter=',',quotechar='"',quoting=csv.QUOTE_ALL)
writer.writerow(cols)
row_list = []
for accession in range(accession_count):
    base_value = random.randint(*value_range)
    for study in range(study_count):
        row_list.append(make_row(study,accession,base_value))
row_list.sort()
writer.writerows(row_list)

# with open("scheme.csv") as scheme:
#     csv = csv.reader(scheme)
#     for row in csv:
#         print row
#         time.sleep(1)