### Function for generating a randomized, MADII experimental design
## Tyler Tiede. University of Minnesota. March 7, 2014
#cat (" \n** Before using MADIIdgn be sure 
#that there are no files and/or folders in your Working Directory named\nthe same as 
#the character string you plan to designate for 'designID'; they will be overwritten.\n ")

#List of checks starting with the primary; assumes you have a primary check

MADIIdgn <- function(enviro="Eretz", 
                     entries= NULL, 
                     num.entries= NULL, 
                     chk.names= NULL, 
                     num.sec.chk= NULL, 
                     num.rows= NULL, 
                     num.cols= NULL,
                     
                     plot.start = 1001, 
                     designID=NULL, 
                     annoy=F)
  {
 
  ## Ensure that no folders/files in WD will be overwritten and then create folder for results
  #JL "is.null(designID)==F"  is equivalent to "!is.null(designID)"
  if(annoy==T & is.null(designID)==F){
  YorN <- NA    
    while(YorN %in% c("y","n","Y","N","yes","no","YES","NO","Yes","No") == F){
      YorN <- readline("Confirm there is Not a folder and/or file in your Working Directory with\nthe same name as 'designID' (type 'y' to proceed, or 'n' to stop): ")
    }  
    #JL It doesn't look like typing 'n' will actually stop the function...
    # I would put in something like if(YorN %in% c("n", "N", "no", "No", "NO")) stop("User requested stop")
    if(YorN %in% c("y","Y","yes","YES","Yes")==T){ 
      unlink(designID, recursive=T)
      dir.create(path=designID, recursive=F) 
    }
  } else{
    #if(is.null(designID)==F){
      unlink(designID, recursive=T)
      dir.create(path=designID, recursive=F) 
    #}
  }
   
  
  ## Load necessary packag#es
  require("grid", quietly=T) ; library(grid)
  
  ## QC of function inputs
  #JL why are these only warnings and not errors that cause the function to stop?
  if(is.null(entries) & is.null(num.entries)){
    warning("Must provide an entry list (entries=) OR the number of entries desired (num.entries=).")
  }
  
  if(is.null(chk.names) & is.null(num.sec.chk)){
    warning("Must provide a list of check names (chk.names=) with the primary check listed first\n OR the number of SECONDARY checks desired (num.sec.chk=).")
  }
  
  if(is.null(num.rows)){
    warning("Provide the number of rows (sometimes called ranges or beds) (num.rows=).")
  }
  
  if(num.rows %% 3 != 0){
    warning("The MADII design requires that the number of rows be a multiple of 3.")
  }
  
  
  ## Develop other non-input function parameters
  if(is.null(entries)){
    entries <- as.matrix(paste("entry", 1:num.entries, sep="_"))
  }
  
  if(is.null(num.entries)){
    entries <- as.matrix(entries) # If user input of entries was a list, will convert it to matrix
    num.entries <- nrow(entries)
  }
  

  ## This warning is dependent on the number of entries
  if(is.null(num.cols)==F){
    if(((num.cols / 5) * (num.rows / 3) + num.entries) > num.cols*num.rows){
      warning("The minimum number of plots has not been met by the given row/column dimensions.")
    }
  }
  
  if(is.null(chk.names)){
    sec.chks <- as.character(2:(num.sec.chk+1)) ## Do need as seperate object for later on in function
    chk.names <- paste("chk", c(1,sec.chks), sep="") ## All generic check names
  }
  
  if(is.null(num.sec.chk)){
    sec.chks <- chk.names[-1] ## The primary check must be listed first in the function input
    num.sec.chk <- length(sec.chks)
  }
  
  blk.rows <- num.rows / 3 # This is the standard for the MADII design
  
  ## If the number of columns is provided then it is straight forward, otherwise a set of algorithms will develop and optimize the paramaters
  if(is.null(num.cols)==F){
    
    if(num.cols%%5 != 0){
      warning("The MADII design requires that the number of columns be a multiple of 5.")
    }
    
    blk.cols <- num.cols / 5 # This is the standard for the MADII design
    
    num.blks <- blk.rows * blk.cols
    exp.size <- num.blks * 15
    num.chks <- exp.size - num.entries
    #JL is there a rule that if a block has secondary checks, then it must have _all_ secondary checks?
    # That would not seem like a good rule.  Maybe it is required by some MADII analyses but it would not be
    # required by the moving average analysis or by an AR1 analysis, and my guess is those are better.
    num.sec.chk.blks <- floor((num.chks - num.blks) / num.sec.chk) # one primary check in each block
    # Number of checks to total number of plots: I think per.chks gets awfully high depending on the design.  I think there
    # should be no more than two check plots per block of 15.  It's just too much effort otherwise.
    per.chks <- (num.blks + (num.sec.chk.blks*num.sec.chk)) / (num.entries + num.blks + (num.sec.chk.blks*num.sec.chk))
    num.fill <- exp.size - (num.blks + num.entries + num.sec.chk.blks*num.sec.chk) # Fill lines are empty plots at the end of the experiment
    #JL do Fill plots actually get planted to something?  I am thinking that they would be.  If they are, it would seem better to 
    #put secondary checks in them and distribute them randomly around the experiment
    
    if(is.null(designID)==F){
      write.table(per.chks, paste(designID, "/", "%checks_in_", designID, ".txt", sep=""))
    }else{
      write.table(per.chks, "%checks.txt")
    }
    
    
  }else{
    ## If the number of columns is not specified, below algorithms will develop the necessary design
    ## Calculate starting (non-optimized paramaters)
    per.chks <- 0.10 #JL yes, this is a good number
    
    ## Number of total checks in experiment (primary + secondary) ; calculated as percent of entries
    num.chks <- ceiling((per.chks * num.entries) / (1-per.chks)) 
    entries.plus.chks <- num.entries + num.chks
    
    num.cols <- ceiling(entries.plus.chks / num.rows)
    #JL num.cols <- ceiling(num.cols / 5) * 5
    # so the statement above could just be "num.cols <- ceiling(entries.plus.chks / num.rows / 5) * 5"
    while(num.cols %% 5 != 0){
      num.cols <- num.cols + 1
    }
    
    blk.cols <- num.cols / 5 # This is the standard for the MADII design
    num.blks <- blk.rows * blk.cols
    exp.size <- num.blks*15 # 15 plots per block
    num.sec.chk.blks <- ceiling((num.chks - num.blks) / num.sec.chk) # one primary check in each block
    
    ## If the ratio of blk.cols to num.sec.chk.blks does not allow each blk.col to have a sec.chk blk in it, then optimize per.chks
    while((blk.cols > num.sec.chk.blks) & (num.sec.chk.blks <  num.blks)){
      per.chks <- per.chks + 0.0001
      num.chks <- ceiling((per.chks * num.entries) / (1-per.chks))
      entries.plus.chks <- num.entries + num.chks
      
      num.cols <- ceiling(entries.plus.chks / num.rows)
      
      while(num.cols %% 5 != 0){
        num.cols <- num.cols + 1
      }
      
      blk.cols <- num.cols / 5 # This is the standard for the MADII design
      num.blks <- blk.rows * blk.cols
      exp.size <- num.blks*15 # 15 plots per block
      num.sec.chk.blks <- ceiling((num.chks - num.blks) / num.sec.chk) # one primary check in each block
      
    }
    
    num.fill <- num.blks*15 - (num.blks + num.entries + num.sec.chk.blks*num.sec.chk) # Fill lines are empty plots at the end of the experiment
  
    ## Increase number of checks to minimize number of Fill plots
    while(num.fill >= num.sec.chk & (num.sec.chk.blks <  num.blks)){ 
      per.chks <- per.chks + 0.0001
      num.chks <- ceiling((per.chks * num.entries) / (1-per.chks))
      entries.plus.chks <- num.entries + num.chks
      
      num.sec.chk.blks <- floor((num.chks - num.blks) / num.sec.chk) # one primary check in each block
      
      num.fill <-num.blks*15 - (num.blks + num.entries + num.sec.chk.blks*num.sec.chk) # Fill lines are empty plots at the end of the experiment
      
    }
    
    if(is.null(designID)==F){
      write.table(per.chks, paste(designID, "/", "%checks_in_", designID, ".txt", sep=""))
    }else{
      write.table(per.chks, "%checks.txt")
    }
  
  }
  
  
  #################################################################
  ############### Build Field File ################################
  
  ## Put together field design columns; plot, row, col, blk, row.blk, col.blk
  fld.dgn <- as.data.frame(matrix(data=c((plot.start:(plot.start-1+exp.size)), 
                                          rep(1:num.rows, each=num.cols), rep(c(1:num.cols, num.cols:1), length.out=exp.size), 
                                          rep(NA, times=exp.size), rep(1:blk.rows, each=(exp.size/blk.rows)), 
                                          rep(c(1:blk.cols, blk.cols:1), each=5, length.out=exp.size), 
                                          rep(NA, times=2*exp.size)), nrow=exp.size, byrow=F))
  
  colnames(fld.dgn) <- c("Plot", "Row", "Col", "Blk", "Row.Blk", "Col.Blk", "Line.Code", "Entry")
  
  if(num.fill>0){
    fld.dgn[(exp.size-num.fill+1):exp.size, 7] <- "F"
  }
  
  blk.list <- 1:num.blks
  for(b in 1:blk.rows){
    if((b %% 2 == 0)==T){
      blk.list[(1+blk.cols*(b-1)):((blk.cols*(b-1))+blk.cols)] <- rev((1+blk.cols*(b-1)):((blk.cols*(b-1))+blk.cols)) 
    } else{
      blk.list[(1+blk.cols*(b-1)):((blk.cols*(b-1))+blk.cols)] <- ((1+blk.cols*(b-1)):((blk.cols*(b-1))+blk.cols))
    }
  }
  
  ## Assign plots to blocks
  count <- 1
  for(b in 1:blk.rows){
    for(c in 1:blk.cols){
      blk <- blk.list[count]
      r1 <- (1+seq(0,1000,by=3))[b]
      r2 <- (seq(0,1000,by=3))[b+1]
      
      c1 <- (1+seq(0,250000,by=5))[c]
      c2 <- (seq(0,250000,by=5))[c+1]
      
      fld.dgn[which(fld.dgn$Row %in% r1:r2 & fld.dgn$Col %in% c1:c2), 4] <- blk
      
      count <- count+1
    } 
  }
  
  
  ## Selecting secondary blocks randomly, but ensuring that each blk.row and each blk.col is represented at least once

  if((num.sec.chk.blks > blk.cols)==T){
    satisfied <- F
    col.blk.list <- c(1:blk.cols)
    row.blk.list <- c(1:blk.rows)
    while(satisfied != T){
      blk.cols.rep <- NULL
      blk.rows.rep <- NULL
      sample.kept <- c()
      new.length <- c()
      while((length(blk.cols.rep) < blk.cols)==T){
        length <- new.length
        sample <- sample(1:(num.blks), 1, replace=F)
        blk.cols.rep <- c(blk.cols.rep, unique(fld.dgn[which(fld.dgn$Blk==sample), 6]))
        blk.cols.rep <- unique(blk.cols.rep)
        new.length <- length(blk.cols.rep)
        if(new.length == 1){
          sample.kept <- c(sample.kept, sample)
        }else{
          if(new.length == (length+1))
            sample.kept <- c(sample.kept, sample)
        }
      }
      
      for(s in sample.kept){
        blk.rows.rep <- c(blk.rows.rep, unique(fld.dgn[which(fld.dgn$Blk==s), 5]))
        blk.rows.rep <- unique(blk.rows.rep)
      } 
    
      if(all(col.blk.list %in% blk.cols.rep) & all(row.blk.list %in% blk.rows.rep)){
        satisfied <- T
      }   
      
    }
    
    ## Need to bring "sample" back up to the number of secondary check blocks with some randomly chosen blocks
    cat((num.sec.chk.blks - length(sample.kept)), "\n")
    sample2 <- sample(setdiff(1:num.blks, sample.kept), (num.sec.chk.blks - length(sample.kept)))
    sample <- c(sample.kept, sample2)
    
  }else{
    ## Selecting secondary blocks randomly, but ensuring that if sec.chk.blk < blk.cols then >1 sec.chk.block does not end up in a column
    satisfied <- F
    col.blk.list <- c(1:blk.cols)
    row.blk.list <- c(1:blk.rows)
    while(satisfied != T){
      blk.cols.rep <- NULL
      blk.rows.rep <- NULL
      #sample <- sample(1:(num.blks-(ceiling(num.fill/5))), num.sec.chk.blks, replace=F) 
      # Use this line instead of below line if secondary checks are not wanted in partial plots due to Filler
      sample <- sample(1:(num.blks), num.sec.chk.blks, replace=F) # Using this line will allow secondary blocks to contain fill plots
      for(s in sample){
        blk.cols.rep <- c(blk.cols.rep, unique(fld.dgn[which(fld.dgn$Blk==s), 6]))
        blk.rows.rep <- c(blk.rows.rep, unique(fld.dgn[which(fld.dgn$Blk==s), 5]))
      }
      if(length(unique(blk.cols.rep))==length(blk.cols.rep) & all(row.blk.list %in% blk.rows.rep)){
        satisfied <- T
      }   
    }
  }
  
  ## Assign primary checks to field design
  for(b in 1:num.blks){
    blk <- fld.dgn[which(fld.dgn$Blk==b), ]
    row <- which(fld.dgn$Row == mean(blk$Row))
    col <- which(fld.dgn$Col == mean(blk$Col))
    fld.dgn[row[which(row  %in% col ==T)], 7] <- 1
  }
  
  ## Assign secondary checks to field
  for(s in sample){
    sec.blk <- fld.dgn[which((fld.dgn$Blk==s) & is.na(fld.dgn$Line.Code)),][,1]
    sec.plots <- sec.blk[sample(1:length(sec.blk), num.sec.chk)]
    for(i in 1:length(sec.plots)){
      plot <- sec.plots[i]
      fld.dgn[which(fld.dgn$Plot==plot), 7] <- (i+1)
    }
  }

  
  fld.dgn[which(is.na(fld.dgn$Line.Code)), 7] <- 0
  
  options(warn=-1) ## If no fill plots then the lines below will throw an error
  ## Assign entry names and check names
  fld.dgn[which(fld.dgn$Line.Code == 0), 8] <- entries[order(sample(1:length(entries), length(entries)))]
  if(num.fill>0){
    fld.dgn[which(fld.dgn$Line.Code == "F"), 8] <- "Fill"
  }
  fld.dgn[which(fld.dgn$Line.Code == "F"), 7] <- 0 # Change the fill lines back to experimental entries for purposes of MADIIadj
  options(warn=0) # Turn warnings back on
 
  
  for(c in 1:length(chk.names)){
    chk <- chk.names[c]
    fld.dgn[which(fld.dgn$Line.Code==c), 8] <- chk
  }
  
  # Instead of re-working code, just re-order fld.dgn df before reading out
  
  
  fld.dgn.mod <- cbind(matrix(enviro, nrow=num.rows, ncol=1), fld.dgn) ; colnames(fld.dgn.mod)[c(1,8)] <- c("Enviro", "Check")
  fld.dgn.mod <- fld.dgn.mod[,c(1,2,9,8, 3:7)]
  
  if(is.null(designID)==F){
    assign(designID, fld.dgn.mod, envir=.GlobalEnv)
    cat("\nYour MADII design is available in your working directory and R environment; named per ID provided.")
    write.csv(get(designID), paste(designID,"/",designID, ".csv", sep=""), row.names=F)
  } else{
    assign("YourMADIIdgn", fld.dgn.mod, envir=.GlobalEnv)
    cat("\nYour MADII design is available in your working directory and R environment; named 'YourMADIIdgn'.")
    write.csv(YourMADIIdgn, "YourMADIIdgn.csv", row.names=F)
  }
  
  ########## Generating Visual Field Map ##########
  
  ## First will generate a series of .csv files for excel
  ### Plots
  for.fld.plot <- fld.dgn[order(fld.dgn$Row, fld.dgn$Col),1:3]
  fld.plot <- apply(t(matrix(for.fld.plot$Plot, nrow=num.rows, ncol=num.cols, byrow=T)), 1, rev) 
  # transposes matrix then flips all rows horizontally
  fld.plot <- cbind(matrix(num.rows:1, nrow=num.rows, ncol=1), fld.plot)
  fld.plot <- rbind(fld.plot, matrix(c(" ", 1:num.cols), nrow=1, ncol=ncol(fld.plot)))
  
  ### Line codes
  for.line.code <- fld.dgn[order(fld.dgn$Row, fld.dgn$Col), c(2,3,7)]
  line.code <- apply(t(matrix(for.line.code$Line.Code, nrow=num.rows, ncol=num.cols, byrow=T)), 1, rev) 
  #transposes matrix then flips all rows horizontally
  line.code <- cbind(matrix(num.rows:1, nrow=num.rows, ncol=1), line.code)
  line.code <- rbind(line.code, matrix(c(" ", 1:num.cols), nrow=1, ncol=ncol(line.code)))
  
  ### Write out the design .csv files
  if(is.null(designID)==F){
    write.table(fld.plot, paste(designID,"/",designID, "_plot.lay.csv", sep=""), row.names=F, col.names=F, sep=",")
    write.table(line.code, paste(designID, "/", designID, "_line.codes.lay.csv", sep=""), row.names=F, col.names=F, sep=",")
  }else{
    write.table(fld.plot, paste(designID, "plot.lay.csv", sep="."), row.names=F, col.names=F, sep=",")
    write.table(line.code, paste(designID, "line.codes.lay.csv", sep="."), row.names=F, col.names=F, sep=",")
  }
  
  
  ###### Now a .png image ######
  options(warn=-1)
  plot.new()
  
  if(is.null(designID)==F){
    dev.copy(png, paste(designID, "/", designID, "_plot.png", sep=""))
  }else{
    dev.copy(png, "YourMADIIdgn.plog.png")
  }
  
  
  field.plot <- matrix(nrow=num.rows, ncol=num.cols)
  field.NA.plot <- t(matrix(NA, nrow=num.rows, ncol=num.cols))
  for(r in 1:num.rows){
    for(c in 1:num.cols){
      field.plot[r,c] <- fld.dgn[which(fld.dgn$Row==r & fld.dgn$Col==c), 1]
    }
  }
  field.plot <- t(field.plot)
  
  for(i in 1:(num.sec.chk+1)){
    chk.plots <- as.list(fld.dgn$Plot[which(fld.dgn$Line.Code==i)])
    field.NA.plot[which(field.plot %in% chk.plots)] <- i
  }
  
  fill.plots <- as.list(fld.dgn$Plot[which(fld.dgn$Entry=="Fill")])
  field.NA.plot[which(field.plot %in% fill.plots)] <- (i+1)
  
  colors <- c("red", "blue", "green", "orange", "gray", "brown", "yellow", "purple", "cyan")
  par(new=T,mar=c(4.5,2,.5,.5), srt=0, xpd=T, font=2, bg="white")
  s
  image(field.plot, add=F, col=0, xaxt='n', yaxt='n' ,xlab="Columns", ylab="Rows", line=0.5)
  image(field.NA.plot, add=T, col=colors[1:sum(length(chk.names),(num.fill/num.fill), na.rm=T)])
  
  box(lwd=3)
  
  if(num.fill>0){
    legend("bottom",legend=c(chk.names, "Fill"), bty="n", horiz=T, cex=.75, inset=c(0,-.125), 
           xjust=0.5, text.col=colors[1:sum(length(chk.names),(num.fill/num.fill), na.rm=T)])}
  else{
    legend("bottom",legend=c(chk.names), bty="n", horiz=T, cex=.75, inset=c(0,-.125), 
           xjust=0.5, text.col=colors[1:sum(length(chk.names),(num.fill/num.fill), na.rm=T)])
  }
  
  
  par(xpd=F)
  grid(ny=num.rows, nx=num.cols, col=1, lty=1 )
  grid(ny=blk.rows, nx=blk.cols, col=1, lty=1, lwd=3) 
  
  dev.off()
  
  cat("\n\nA graphic of the design can also be found in the project's folder.\n ")
  
  options(warn=0)
  
} # End of MADIIdgn loop

test <- MADIIdgn(num.entries=330, num.rows=9, num.cols=NULL, num.sec.chk=3, designID="tester1", annoy=T)

#test2 <- MADIIdgn(num.entries=100, num.rows=6, num.cols=5, num.sec.chk=3, designID="tester1", annoy=T)

#layoutParameters <- function(num.entries=330, num.rows=9, num.cols=NULL, num.sec.chk=3, designID="tester1", annoy=T){
#  minBlks <- ceiling(num.entries / 14)
#  
#}
