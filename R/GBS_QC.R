#to use
#R --slave --args output_test00.txt qc_output.txt < ~code/code_R/GBS_QC.R

myarg <- commandArgs()
cat(myarg,"\n");
m=length(myarg)
cat(m,"\n");

f_in<-myarg[4:4]
f_out<-myarg[5:5]
#f_plot<-myarg[6:6]
#f_output<-myarg[7:7]

#cat(f_index,"\n")
#cat(f_acc,"\n")
#cat(f_plot,"\n")
#cat(f_output,"\n")


#f_acc="WEMA_6x1122_entry_number_accession.csv_tail.csv"
#f_plot="Clean data 6x1122_WET11B-MARS-EVALTC-10-8_rep2_sorted.csv_tail.csv"

data.gbs<-read.csv(f_in,sep="\t",header=F)


m=dim(data.gbs)[1];
n=dim(data.gbs)[2];
nn=n-1;

#cat("There are",nn,"accession\n",file=f_out,sep=" ",append=TRUE);
#cat("Each accession has",m,"markers\n",file=f_out,sep=" ",append=TRUE);


data.cnr<-array();

s=1;

for (i in 2:n){

cn=length(which(data.gbs[,i]=="-9"));
cnr=cn/length(data.gbs[,i]);
j=i-1;
data.cnr[s]=cnr;
s=s+1;
cat("Sample",j,"missing rate is",cnr,"\n",file=f_out,sep=" ",append=TRUE);

}

png(file = "./documents/img/MissingRate.png")
hist(data.cnr)
dev.off()

#data.plot<-read.csv(f_plot,sep="\t",header=F)

#colnames(data.plot)[1]="ENTRY"

#V1 V2 V3  V4 V5 V6 V7   V8  V9 V10   V11  V12



#diff_acc_plot=setdiff(data.plot[,1],data.acc[,1])
#same_acc_plot=intersect(data.plot[,1],data.acc[,1])

#diff_acc_plot=diff_acc_plot[order(diff_acc_plot)]
#same_acc_plot=same_acc_plot[order(same_acc_plot)]

#dn=length(diff_acc_plot)
#sn=length(same_acc_plot)


#WEMA6x1008_WET10B-EVALTC-08-1_ungenotyped1_tester_CML395_CML444 

#mp=gregexpr("_rep",f_plot)

#data_acc_tester=as.character(data.acc[1,2])

#acc_tester=substr(data_acc_tester,gregexpr("tester",data_acc_tester)[[1]][1],nchar(data_acc_tester))

#ungenotyped=paste("WEMA_",substr(f_plot,12,mp[[1]][1]+4),"_ungenotyped_",acc_tester,"_",diff_acc_plot[1],sep="")

#for(i in 2:dn){
#
#ungenotyped=c(ungenotyped,paste("WEMA_",substr(f_plot,12,mp[[1]][1]+4),"_ungenotyped_",acc_tester,"_",diff_acc_plot[i],sep=""))
#
#}

#ungenotyped=paste("WEMA_",substr(f_plot,12,17),"_ungenotyped_",1,"_",acc_tester,sep="")

#for(i in 2:dn){

#ungenotyped=c(ungenotyped,paste("WEMA_",substr(f_plot,12,17),"_ungenotyped_",i,"_",acc_tester,sep=""))

#}

#diff_acc_plot_ungenotyped<-cbind(diff_acc_plot,ungenotyped)
#colnames(diff_acc_plot_ungenotyped)=c("ENTRY","DESIG")

#data.acc.sorted=data.acc[order(data.acc[,1]),]
#colnames(data.acc.sorted)=c("ENTRY","DESIG")

#data.acc.plus.ungenotyped<-rbind(data.acc.sorted,diff_acc_plot_ungenotyped)

#data.acc.plus.ungenotyped.plot<-merge(data.acc.plus.ungenotyped,data.plot,by="ENTRY",sort=F)

#cn=dim(data.acc.plus.ungenotyped.plot)[2]

#data.acc.plus.ungenotyped.plot.2<-data.acc.plus.ungenotyped.plot[,c(1,3,4,5,2,7:cn)]

#f_output=paste("WEMA_",substr(f_plot,12,mp[[1]][1]+3),"_plot_accession",sep="")

#acc_plot_file_name=paste(f_output,"_output.csv",sep="")

#cat(acc_plot_file_name,"\n")

#write.table(data.acc.plus.ungenotyped.plot.2,file=acc_plot_file_name,append = F, quote = F, sep = "\t",eol = "\n",row.names = F,col.names = F,na=" ");


#ff <- myarg[5:m]

#f<-paste(ff,collapse=" ")

#cat(f_index,"\n")
#cat(f,"\n")
#cat(length(f),"\n")

#cat(m,"\n")

#library(affy)
#eset=justRMA(celfile.path=f)
#write.exprs(eset,file=paste(f_index,"_exprs.txt",sep=""))
#save.image(file=paste(f,".RData",sep=""))
#q()


#list_trait<-function(file.name){
#getwd()

#library(gdata)
#file_name=paste("~/DataFromXuecai/Link genotypes with phenotypes/",f_index,sep="");
#cat(file_name,"\n");

#data.for.read<-read.csv(file_name,header=T,sep="\t")

#print(colnames(data.for.read))

#write.table(data.for.read[2:length(data.for.read[,2]),2],file="F3_name.txt",append = T, quote = F, s#ep = "\t",eol = "\n",row.names = F,col.names = F);

#}
quit("yes")