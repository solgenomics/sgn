
# R CMD BATCH --no-save --no-restore '--args phenotype_file="blabla.txt" output_file="blalba.png" ' analyze_phenotype.r
library(dplyr)
#install.packages("reshape")
library(reshape)
library(ggplot2)

args=(commandArgs(TRUE))

if(length(args)==0){
   print("No arguments supplied.")
   ##supply default values
   phenotype_file = 'phenotypes.txt'
   output_file = paste0(phenotype_file, ".png", sep="")
} else {
   for(i in 1:length(args)){
      eval(parse(text=args[[i]]))
   }
}
errorfile = paste(phenotype_file, ".err", sep="");
print(paste("args: ", args))
print(paste("phenotype file: ", phenotype_file))
print(paste("output_file: ", output_file))

phenodata = read.csv(phenotype_file, skip =3, fill=TRUE, sep=",", header = TRUE, stringsAsFactors = T, na.strings="NA");

#phenodata = read.csv("/home/bryan/Desktop/phenotype7dfK.csv",skip =3,fill=TRUE, sep=",", header = TRUE, stringsAsFactors = T, na.strings="NA");

# barplot from report

traits = c(
   "germplasmName",
   "Weight.of.cull.storage.roots.measuring.kg.per.plot.CO_331.0000612",
   "Weight.of.canner.storage.roots.measuring.kg.per.plot.CO_331.0000610",
   "Weight.of.90.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000613",
   "Weight.of.55.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000614",
   "Weight.of.40.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000615",
   "Weight.of.32.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000616",
   "Weight.of.jumbo.storage.roots.measuring.kg.per.plot.CO_331.0000611"
   )

raw_data.barplot = subset(phenodata, select = c(traits))

clean_data.barplot = raw_data.barplot[complete.cases(raw_data.barplot), ]

data.barplot = group_by(clean_data.barplot, germplasmName) %>% summarize(
   CUL = mean(Weight.of.cull.storage.roots.measuring.kg.per.plot.CO_331.0000612),
   CAN = mean(Weight.of.canner.storage.roots.measuring.kg.per.plot.CO_331.0000610),
   C90 = mean(Weight.of.90.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000613),
   C55 = mean(Weight.of.55.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000614),
   C40 = mean(Weight.of.40.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000615),
   C32 = mean(Weight.of.32.count.US.no..1.storage.roots.measuring.kg.per.plot.CO_331.0000616),
   JUM = mean(Weight.of.jumbo.storage.roots.measuring.kg.per.plot.CO_331.0000611)
   )

data.barplot <- as.data.frame(data.barplot)

total_root_weights = data.barplot$CUL + data.barplot$CAN + data.barplot$C90 +
   data.barplot$C55 + data.barplot$C40 + data.barplot$C32 + data.barplot$JUM

max = max(total_root_weights, na.rm=TRUE) * 1.2

data.barplot.melt <- melt(data.barplot)
data.barplot.melt$variable = gsub("CUL", "Cull" ,data.barplot.melt$variable)
data.barplot.melt$variable = gsub("CAN", "Canner",data.barplot.melt$variable)
data.barplot.melt$variable = gsub("C90", "No.1 (5.0-9.4oz)",data.barplot.melt$variable)
data.barplot.melt$variable = gsub("C55", "No.1 (9.5-14oz)",data.barplot.melt$variable)
data.barplot.melt$variable = gsub("C40", "No.1 (14.1-18oz)",data.barplot.melt$variable)
data.barplot.melt$variable = gsub("C32", "No.1(18.1-22oz)",data.barplot.melt$variable)
data.barplot.melt$variable = gsub("JUM", "Jumbo",data.barplot.melt$variable)

data.barplot.melt$variable = factor(data.barplot.melt$variable,
                                    levels = c("Cull", "Jumbo", "No.1(18.1-22oz)",
                                               "No.1 (14.1-18oz)","No.1 (9.5-14oz)",
                                               "No.1 (5.0-9.4oz)", "Canner"))

plot = ggplot( data.barplot.melt, aes(x = germplasmName, y = value, fill = variable)) + 
   geom_bar(stat = "identity", width = 0.4) + 
   coord_cartesian(ylim = c(0,max)) +
   scale_fill_manual(values = c("#FF3300", "#FF9900", "#006400","#00b200",          #redcull,orangejumbo,no1green, cannerd.blue 
                                "#00ed00", "#3dff3d","#000099")) +
   ## color http://www.cookbook-r.com/Graphs/Colors_(ggplot2)/
   theme(axis.text.x = element_text(face="bold", colour="black", size=14,angle = 45, hjust = 1),
         axis.text.y = element_text(face="bold", colour="black", size=14),
         axis.title.y=element_text(size=16,face="bold") ,
         axis.title.x=element_text(size=16,face="bold") ,
         plot.title = element_text(color="red", size=18, face="bold.italic", hjust = 0.5),
         plot.margin = unit(c(0.5,6,0.5,1), "cm"),
         legend.position = c(1.15, 0.7),
         legend.text = element_text(size=14, face="bold") ) +
   labs(y = "Yield (50lb Bushel/acre)" , x = "Clone",
        title = phenodata$studyName)

# plot(plot)

png(output_file)
print(plot)
dev.off()
