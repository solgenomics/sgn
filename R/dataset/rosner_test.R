# rosners_test

library('EnvStats')

##### Get data #####
args = commandArgs(trailingOnly = TRUE)

# (input_file_name, output_file_name, trait_name)
input_file_name <- args[1]
print(input_file_name)
output_file_name <- args[2]
print(output_file_name)
trait_name <- args[2]

# errorMessages <- c()

table <- read.csv(input_file_name)

##### remove NA #####
table <- table[rowSums(is.na(table)) != ncol(table), ]

outliers_number = 3

##### Make test #####
test <- rosnerTest(table[, 1], k = outliers_number)

# table[test$all.stats$Obs.Num, 2]

##### Default for test k = 3 loop if more outliers then 3 - it should return table with one extra row with first non outlier value  #####
while (test$n.outliers == outliers_number)  {
  outliers_number =  outliers_number + 1
  test <- rosnerTest(table[, 1], k = outliers_number)
}

# change observation number in data frame to phenotype id
test$all.stats$Obs.Num <- table[test$all.stats$Obs.Num, 2]

# write csv file without first row
write.csv(file = output_file_name, test$all.stats, row.names = FALSE) 