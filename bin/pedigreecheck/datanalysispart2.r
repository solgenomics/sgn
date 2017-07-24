library(pedigreemm)
library(ggplot2)
library(proxy)
ped <- read.table ("/home/klz26/Downloads/pedigree1.txt", header = FALSE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)
colnames(ped)[1] <- "Name"
colnames(ped)[2] <- "Mother"
colnames(ped)[3] <- "Father"
colnames(ped)[4] <- "Cross Type"
ped[4] <- NULL

P2= editPed(dam=ped$Mother, sire=ped$Father, label=ped$Name)

P3= pedigree(P2$sire, P2$dam, P2$label)

Amat <- getA(P3)

genotype_data <- read.table ("/home/klz26/host/test/6genotypes-p3.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE, na.strings = "na")
markers <- read.table ("/home/klz26/Downloads/pasteall.txt", header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
colnames(markers) <- gsub('\\|[^|]+$', '', colnames(markers))
rownames(markers) <- rownames(genotype_data)

marker_distances <- dist(markers, method = "Euclidean", by_rows = FALSE)

include_list <- labels(Amat[,"UG120078"])
subset_matrix <- dist_matrix[rownames(dist_matrix) %in% include_list, colnames(dist_matrix) %in% include_list] 

x <- Amat[!rownames(Amat) %in% "UG120078","UG120078"]
y <- subset_matrix["UG120078",!colnames(subset_matrix) %in% "UG120078"]

xord <- order(names(x))
x <- x[xord]
yord <- order(names(y))
y <- y[yord]

ggplot()+ggtitle("UG120078 Relationships")+labs(x="Additive relationship",y="Marker-based distance")+geom_text(aes(x=x,y=y,label=names(x)))

