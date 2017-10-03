library(grid)
library(reshape2)
library(ggplot2)
library(compete)
library(shiny)
library(shinydashboard)
library(dplyr)
library(DT)
library(knitr)
library(tidyr)
library(data.table)
library(lubridate)
library(digest) # digest() Create hash function digests for R objects

####################
# DATASETS
########################

nTable <- nTable
cleantable <- cleantable
Flowering <- Flowering
FirstPollination <- Firstpollination
RepeatPollination <- RepeatPollination
Harvested <- Harvested
Ripened <- Ripened
Seed_extraction <- Seed_extraction
Embryorescue <- Embryorescue
Germinating_two_weeks <- Germinating_two_weeks
Germinating_6weeks <- Germinating_6weeks
#seeds_germinating_after_6weeks = seeds_germinating_after_6weeks
#Subculture <- Subculture
Rooting <- Rooting
Screenhouse <- Screenhouse
Hardening <- Hardening
Openfield <- Openfield
Contamination <- Contamination
Plant_status = Plant_status



##################
# Feedback message
###################
formName <- paste0(Sys.Date(),"-feedback-info")
resultsDir <- file.path("data", formName)
dir.create(resultsDir, recursive = TRUE, showWarnings = FALSE)

# names of the fields on the form we want to save
fieldNames <- c("fullName",
                "email",
                "message"
)

# names of users that have admin power and can view all submitted responses
adminUsers <- c("staff", "admin")

shinyServer(function(input, output,session) {
  
  ### plotting theme
  mytheme <-  theme(
    plot.title = element_text(hjust=0,vjust=1, size=rel(2.3)),
    panel.background = element_blank(),
    panel.grid.major.y = element_line(color="gray85"),
    panel.grid.major.x = element_line(color="gray85"),
    panel.grid.minor = element_blank(),
    plot.background  = element_blank(),
    text = element_text(color="gray20", size=10),
    axis.text = element_text(size=rel(1.0)),
    axis.text.x = element_text(color="gray20",size=rel(1.5)),
    axis.text.y = element_text(color="gray20", size=rel(1.5)),
    axis.title.x = element_text(size=rel(1.5), vjust=0),
    axis.title.y = element_text(size=rel(1.5), vjust=1),
    axis.ticks.y = element_blank(),
    axis.ticks.x = element_blank(),
    legend.position = "none"
  )
  
  
  ### dashboard tab
  output$submissions <- renderPlot({
    #qplot(data=cleantable, x=date) + ylab("Submission Count") + theme(legend.position = "bottom") + geom_line()
    Date <- as.Date(submission$Date)
    Number <- as.numeric(levels(submission$Number))[submission$Number]
    ggplot(submission, aes(Date, Number, group = 1)) + geom_line() + geom_point()
    
  })
  
  output$average_days <- renderPlot({
    qplot(cleantable, x=x, fill=activity) + theme(legend.position = "right") 
  })

  # display the data that is available to be drilled down
  output$summary <- DT::renderDataTable(summary_cleantable)
  
  # subset the records to the row that was clicked
  drilldata <- reactive({
    shiny::validate(
      need(length(input$summary_rows_selected) > 0, "Select rows to drill down!")
    )    
    
    # subset the summary table and extract the column to subset on
    # if you have more than one column, consider a merge instead
    # NOTE: the selected row indices will be character type so they
    #   must be converted to numeric or integer before subsetting
    selected_activity <- summary_cleantable[as.integer(input$summary_rows_selected), ]$activity
    cleantable[cleantable$activity %in% selected_activity, ]
  })
  
  # display the subsetted data
  output$drilldown <- DT::renderDataTable(drilldata())
  
  #output$downloadDrill <- downloadHandler(
  #  filename = function() { paste(input$datasets, '.csv', sep='') },
  #  content = function(file) {
  #    write.csv(datasetInput(), file)
  #  })
  

  crossesInput <- reactive({
    switch(input$select_activity, "All crosses data" = All_data,
           "Flowering" = Flowering,"Firstpollination" = Firstpollination,
           "RepeatPollination" = RepeatPollination,
           "Harvested" = Harvested,"Ripened" = Ripened,"Seed_extraction" = Seed_extraction,
           "Embryorescue" = Embryorescue,"Germinating_two_weeks" = Germinating_two_weeks,
           "Germinating_6weeks" = Germinating_6weeks)
  })
  
  plantletsInput <- reactive({
    switch(input$plantlets, "All plantlets data" = all_plantlets,
           "Rooting" = Rooting,"Screenhouse" = Screenhouse,"Hardening" = Hardening,"Openfield" = Openfield)
  })
  statusConInput <- reactive({
    switch(input$statusCont,"Status" = Plant_status,"Contamination" = Contamination)
  })
  
  output$crossesTable <- DT::renderDataTable({
    crossesInput()
  })
  output$plantletsTable <- DT::renderDataTable({
    plantletsInput()
  })
  output$statusConTable <- DT::renderDataTable({
    statusConInput ()
  })
  
  
  output$downloadData <- downloadHandler(
    filename = function() { paste(input$datasets, '.csv', sep='') },
    content = function(file) {
      write.csv(datasetInput(), file)
    })
  
  todaydata = dplyr::filter(cleantable, cleantable$date==Sys.Date())
  
  if (dim(todaydata)[1]==0)
  {
    output$text <- renderText({paste("No activity was recorded today")})
  }
  else{
    mytable = table(todaydata$location,todaydata$activity)
    dtable = as.data.frame(mytable)
    names(dtable) = c("location","Activity","N")
    output$dsumTable <- renderTable({
      dtable})
    output$dTable <- renderTable({todaydata})
  }
  output$dPlot <- renderPlot({
    s<- ggplot(todaydata, aes(activity, fill=contributor))
    s + geom_bar(position = 'stack') +  theme(legend.position = "bottom") + coord_flip()
  })
  ggplot(todaydata, aes(x = reorder(activity, -accession), y = accession, fill = activity)) + 
    geom_bar(stat = "identity")
  
  # explorer
  
  observe({
    activities <- if (is.null(input$locations)) character(0) else {
      filter(cleantable, location %in% input$locations) %>%
        `$`('activity') %>%
        unique() %>%
        sort()
    }
    stillSelected <- isolate(input$activities[input$activities %in% activities])
    updateSelectInput(session, "activities", choices = activities,
                      selected = stillSelected)
  })
  
  
  observe({
    dateRange <- if (is.null(input$locations)) character(0) else {
      filter(cleantable, location %in% input$locations) %>%
        `$`('date') %>%
        unique() %>%
        sort()
    }
    stillSelected <- isolate(input$dateRange[input$dateRange %between% c(input$dateRange[1],input$dateRange[2])])
    updateSliderInput(session, "dateRange", value = c(input$dateRange[1],input$dateRange[2]))
  })  
  
  output$dataExplorer <- DT::renderDataTable({
    df <- cleantable %>%
      filter(
        is.null(input$locations) | location %in% input$locations,
        is.null(input$activities) | activity %in% input$activities,
        is.null(input$dateRange) | date %between% c(input$dateRange[1],input$dateRange[2])
        
      ) 
    action <- DT::dataTableAjax(session, df)
    DT::datatable(df, options = list(ajax = list(url = action)), escape = FALSE)
  })
 
  ##### Admin panel#####
  
  # if logged in user is admin, show a table aggregating all the data
  isAdmin <- reactive({
    !is.null(session$user) && session$user %in% adminUsers
  })
  infoTable <- reactive({
    if (!isAdmin()) return(NULL)
    
    ### This code chunk reads all submitted responses and will have to change
    ### based on where we store persistent data
    infoFiles <- list.files(resultsDir)
    allInfo <- lapply(infoFiles, function(x) {
      read.csv(file.path(resultsDir, x))
    })
    ### End of reading data
    
    #allInfo <- data.frame(rbind_all(allInfo)) # dplyr version
    #allInfo <- data.frame(rbindlist(allInfo)) # data.table version
    allInfo <- data.frame(do.call(rbind, allInfo))
    if (nrow(allInfo) == 0) {
      allInfo <- data.frame(matrix(nrow = 1, ncol = length(fieldNames),
                                   dimnames = list(list(), fieldNames)))
    }
    return(allInfo)
  })
  output$adminPanel <- renderUI({
    if (!isAdmin()) return(NULL)
    
    div(id = "adminPanelInner",
        h3("This table is only visible to admins",
           style = "display: inline-block;"),
        a("Show/Hide",
          href = "javascript:toggleVisibility('adminTableSection');",
          class = "left-space"),
        div(id = "adminTableSection",
            dataTableOutput("adminTable"),
            downloadButton("downloadSummary", "Download results")
        )
    )
  })
  output$downloadSummary <- downloadHandler(
    filename = function() { 
      paste0(formName, "_", getFormattedTimestamp(), '.csv')  
    },
    content = function(file) {
      write.csv(infoTable(), file, row.names = FALSE)
    }
  )
  output$adminTable <- renderDataTable({
    infoTable()
  })
  
  ##### End admin panel #####
  ##########################################
  
  # only enable the Submit button when the mandatory fields are validated
  observe({
    if (input$fullName == '' || input$email == '' ||
        input$message == '') {
      session$sendCustomMessage(type = "disableBtn", list(id = "submitBtn"))
    } else {
      session$sendCustomMessage(type = "enableBtn", list(id = "submitBtn"))
    }
  })
  
  # the name to show in the Thank you confirmation page
  output$thanksName <- renderText({
    paste0("Thank you ", input$fullName, "!")
  })
  
  # we need to have a quasi-variable flag to indicate when the form was submitted
  output$formSubmitted <- reactive({
    FALSE
  })
  outputOptions(output, 'formSubmitted', suspendWhenHidden = FALSE)
  
  
  # submit the form  
  observe({
    #if (input$submitConfirmDlg < 1) return(NULL)
    if (input$submitBtn < 1) return(NULL)
    
    # read the info into a dataframe
    isolate(
      infoList <- t(sapply(fieldNames, function(x) x = input[[x]]))
    )
    
    # generate a file name based on timestamp, user name, and form contents
    isolate(
      fileName <- paste0(
        paste(
          getFormattedTimestamp(),
          input$fullName,
          digest(infoList, algo = "md5"),
          sep = "_"
        ),
        ".csv"
      )
    )
    
    # write out the results
    ### This code chunk writes a response and will have to change
    ### based on where we store persistent data
    write.csv(x = infoList, file = file.path(resultsDir, fileName),
              row.names = FALSE)
    ### End of writing data
    
    # indicate the the form was submitted to show a thank you page so that the
    # user knows they're done
    output$formSubmitted <- reactive({ TRUE })
  }) 
  
}
)