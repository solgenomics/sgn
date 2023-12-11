# rosners_test

library('EnvStats')

##### Get data #####
args = commandArgs(trailingOnly = TRUE)

# (input_file_name, output_file_name, trait_name)
input_file_name <- args[1]
print(input_file_name)
output_file_name <- args[2]
print(output_file_name)
# trait_name <- args[2]

errorMessages <- c()

# read argument  from command line with datafile
# input file / otput filename

table <- read.csv(input_file_name)
# remove all NA rows

table <- table[rowSums(is.na(table)) != ncol(table), ]

# View(table)
# View(table2)
# dim(table)
# dim(table2)

test <- rosnerTest(table[, 1])

# test$n.outliers
# test$parameters

# outliers  <- test$all.stats$Obs.Num[0:test$n.outliers]
write.csv(file = output_file_name, test$all.stats)
# write.csv(outliers)
# write.csv(test$n.outliers)

# ok jak zwracamy wynik
# co zwracamy

# 1 . tabela
# czy cos poza tabelą ?

