library(shiny)
library(DT)
library(knitr)
library(ggplot2)
library(leaflet)
library(shinythemes)
library(dplyr)
library(tidyr)
library(data.table)
library(lubridate)
# datasets
Overall <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\bananadata.csv")
plantlets <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\plantlets.csv") 
FloweringD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\all_flowering.csv")
FirstpollinationD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\firstpollination.csv")
RepeatPolln <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\repeatpollination.csv")
HarvestedD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\harvesting.csv")
RipenedD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\ripening.csv")
Plant_statusD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\status.csv")
Seed_extractionD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\extraction.csv")
EmbryorescueD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\rescued.csv")
Germinating_two_weeksD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\germinating2weeks.csv")
Germinating_6weeksD <-  read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\germinating6weeks.csv")
SubcultureD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\subculture.csv")
RootingD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\rooting.csv")
HardeningD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\hardening.csv")
ScreenhouseD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\screenhouse.csv")
OpenfieldD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\openfield.csv")
ContaminationD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\Contamination.csv")
StatusD <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\status.csv")

All_data <- Overall %>% 
  select("crossnumber","mother", "mother_accessionName", "father", "father_accessionName", "firstpollination_date",
         starts_with("Male"),starts_with("repeatPollinationDate"), starts_with("Male_accessionName"),"harvesting_date", "days_to_maturity","ripen_date",
         "days_harvest_ripening","seed_extraction_date","number_seeds", "good_seeds","badseeds", "days_ripening_extraction","number_rescued",
         "rescue_date", "days_extraction_rescue","germination_after_2weeks_date","actively_germination_after_two_weeks","days_rescue_2weeksGermination",
         "germination_after_6weeks_date","actively_germination_after_6weeks","days_2weeksGermination_6weeksGermination",
         "subculture_date", "subcultures", "days_6weeks_Germination_subculture")
all_plantlets = plantlets %>%
  select("crossnumber","plantletID","subculture_date","date_rooting","days_subculture_rooting","screenhse_transfer_date","days_rooting_screenhse",
         "hardening_date","days_scrnhse_hardening","date_of_transfer_to_openfield","days_hardening_openfield")
Flowering <- FloweringD[,5:8]
colnames(Flowering) <- c("plot_number","accession_name","flowering_date","sex")
FirstPollination <- FirstpollinationD[,8:13]
colnames(FirstPollination) <- c("mother_plotNumber","mother_acc_name","father_plotNumber","father_acc_name","crossnumber","firstpollination_date")
Firstpollination <- FirstPollination[,c(5,1,2,3,4,6)]
RepeatPollination <- RepeatPolln[,-1]
Harvested <- HarvestedD[,c(4,6:7,3)]
Ripened <- RipenedD[,c(4,6:7,3)]
Seed_extraction <- Seed_extractionD[,c(4,6:8,3)]
Embryorescue <- EmbryorescueD[,c(4,6:10,3)]
Germinating_two_weeks <- Germinating_two_weeksD[,c(4,6:8,3)] 
Germinating_6weeks <- Germinating_6weeksD[,c(4,6:8,3)]
Subculture <- SubcultureD[,c(4,6:8,3)]
Rooting <- RootingD[,c(4,6:7,3)]
Screenhouse <- ScreenhouseD[,c(4,6:7,3)]
Hardening <- HardeningD[,c(4,6:7,3)]
Openfield <- OpenfieldD[,c(4,6:7,3)]
Contamination <- ContaminationD[,c(4,6:7,3)]
Plant_status = StatusD[,c(5:7,3)]

# # NUMBER OF ACCESSION IN DIFFERENT STAGES OF PROJECT
nTable = read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\nTable.csv", stringsAsFactors = F)
# DATA EXPLORER
cleantable <- read.csv("D:\\github\\ODK_bananaCrossingTool\\Analysis\\cleantable.csv", stringsAsFactors = F)

# ui
library(shinyjs)

ui <- navbarPage("BP - TOOL", theme = shinytheme("united"),
                 tabPanel("DASHBOARD",
                          fluidRow(
                                   column(6,h4("Total submissions per day"),
                                          plotOutput("tsubs", height = 250),
                                          
                                       h5("Activities per contributor"),
                                              plotOutput("csubs", height = 300)),
                                   column(4,offset = 1, h4("Number of accessions in different stages of project"),
                                          hr(),
                                          DT::dataTableOutput("nAccessions"))
                          )),
                 tabPanel("TODAY'S REPORT",
                          fluidRow(
                            column(3, h4("Table: Today summary"), br(),tableOutput("dsumTable")),
                            column(6, h4("Table: Today's records"),br(), tableOutput("dTable"))
                            ),
                          fluidRow( column(10, offset = 1, htmlOutput("text")))
                          ),
                 navbarMenu("DATA TABLES",
                            tabPanel("Crosses datasets",
                                     fluidRow(
                                       column(2,offset=1, 
                                              selectInput("select_activity", "Crosses datasets", 
                                                          choices = c("All crosses data","Flowering","Firstpollination","RepeatPollination","Harvested",
                                                                      "Ripened","Seed_extraction","Embryorescue","Germinating_two_weeks",
                                                                      "Germinating_6weeks","Subculture")))),
                                      fluidRow(
                                        hr(),
                                        column(10,offset=1, 
                                              div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                                  DT::dataTableOutput("crossesTable")),
                                              downloadButton('downloadcrosses', 'Download data')))
                                     ),
                            tabPanel("Plantlets datasets",
                                     fluidRow(
                                       column(2, offset = 1,
                                              selectInput("plantlets","Plantlets datasets", 
                                                          choices = c("All plantlets data","Rooting","Screenhouse","Hardening","Openfield")))),
                                     hr(),
                                     fluidRow(
                                       column(10,offset=1, 
                                              div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                                  DT::dataTableOutput("plantletsTable")),
                                              downloadButton('downloadplantlets', 'Download data')))
                                     ),
                            tabPanel("Status and contamination",
                                      fluidRow(           
                                       column(2, offset = 1,
                                              selectInput("statusCont","Status and contamination", choices = c("Status","Contamination")))
                                     ),
                                     hr(),
                                     fluidRow(
                                       column(10,offset=1, 
                                              div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                                  DT::dataTableOutput("statusConTable")),
                                              downloadButton('downloadstatusCont', 'Download data')))
                                     )
                            ),
                  tabPanel("DATA EXPLORER",
                                     fluidRow(
                                       column(3,selectInput("locations", "locations", c("All locations"="", unique(cleantable$location)), multiple=TRUE)),
                                       column(3,conditionalPanel("input.locations",
                                                                 selectInput("activities", "Activities", c("Activities"=""), multiple=TRUE))),
                                       column(3,conditionalPanel("input.locations",
                                                                 selectInput("accessions", "Accessions", c("Accessions"=""), multiple=TRUE)))
                                     ),
                                     fluidRow(
                                       column(10, offset = 1,
                                              DT::dataTableOutput("dataExplorer"))
                                     )
                            )
                 
)

server <- function(input, output, session){
  output$tsubs <- renderPlot({
    qplot(data=cleantable, x=date) + ylab("Submission Count") + theme(legend.position = "bottom")
  })
 output$csubs <- renderPlot({
    qplot(data=cleantable, x=contributor, fill=activity) + theme(legend.position = "right") 
  })
 output$nAccessions <- DT::renderDataTable({
   nTable
 })
 
  crossesInput <- reactive({
    switch(input$select_activity, "All crosses data" = All_data,
           "Flowering" = Flowering,"Firstpollination" = Firstpollination,
           "RepeatPollination" = RepeatPollination,
           "Harvested" = Harvested,"Ripened" = Ripened,"Seed_extraction" = Seed_extraction,
           "Embryorescue" = Embryorescue,"Germinating_two_weeks" = Germinating_two_weeks,
           "Germinating_6weeks" = Germinating_6weeks,"Subculture" = Subculture)
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
    output$dsumTable <- renderTable(dtable)
    output$dTable <- renderTable(todaydata)
  }
  output$dPlot <- renderPlot({
    s<- ggplot(todaydata, aes(activity, fill=contributor))
    s + geom_bar(position = 'stack') +  theme(legend.position = "bottom") + coord_flip()
  })
  ggplot(todaydata, aes(x = reorder(activity, -accession), y = accession, fill = activity)) + 
    geom_bar(stat = "identity")
  
# Data explorer
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
    accessions <- if (is.null(input$locations)) character(0) else {
      cleantable %>%
        filter(location %in% input$locations,
               is.null(input$activities) | activity %in% input$activities) %>%
        `$`('accession') %>%
        unique() %>%
        sort()
    }
    stillSelected <- isolate(input$accessions[input$accessions %in% accessions])
    updateSelectInput(session, "accessions",choices = accessions,
                      selected = stillSelected)
  })
  
  output$dataExplorer <- DT::renderDataTable({
    df <- cleantable %>%
      filter(
        is.null(input$locations) | location %in% input$locations,
        is.null(input$activities) | activity %in% input$activities,
        is.null(input$accessions) | accession %in% input$accessions
      ) #%>%
    #mutate(Action = paste('<a class="go-map" href="" data-lat="', Lat, '" data-long="', Long, '" data-zip="', Zipcode, '"><i class="fa fa-crosshairs"></i></a>', sep=""))
    action <- DT::dataTableAjax(session, df)
    
    DT::datatable(df, options = list(ajax = list(url = action)), escape = FALSE)
  })
} 
shinyApp(ui = ui, server = server)