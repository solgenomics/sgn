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

shinyUI(dashboardPage(skin="yellow",
                      dashboardHeader(title = "Banana Crosses"),
                      dashboardSidebar(
                        sidebarMenu(#style = "position: fixed; overflow: visible;",
                          menuItem("Introduction", tabName = "Introduction", icon = icon("star-o")),
                          menuItem("Dashboard", tabName = "dashboard", icon = icon("bar-chart-o")),
                          menuItem("Tables", tabName = "tables", icon = icon("table")),
                          menuItem("Explorer", tabName = "explorer",icon = icon("list-alt")),
                          menuItem("Feedback", tabName = "feedback",icon = icon("question")),
                          br(),
                          br(),br(),br(),br(),br(),br(),br()
                          )
                        ),

                      dashboardBody(
                        
                        tags$head(
                          tags$style(type="text/css", "select { max-width: 360px; }"),
                          tags$style(type="text/css", ".span4 { max-width: 360px; }"),
                          tags$style(type="text/css",  ".well { max-width: 360px; }"),
                         # tags$head(tags$style(HTML('.info-box" {min-height: 45px;} .info-box-icon {height: 45px; line-heigt: 45px;} .info-box-content {padding-top: 0px; padding-bottom:}'))),
                        # add external JS and CSS
                          singleton(
                            tags$head(includeScript(file.path('www', 'message-handler.js')),
                                      includeCSS(file.path('www', 'style.css'))
                            )
                          )
                        ),
                        
              tabItems(
                          
                  tabItem(tabName = "dashboard",
                        fluidRow(
                          box(width = 12, infoBox(width = 3, "no. crosses", length(Firstpollination$crossnumber),icon = icon("desktop")))),
                        fluidRow(
                          box(title = "Submissions", width=8,  status = "warning", collapsible=T, plotOutput("submissions", height = 150),
                              hr(), h4("Average number of days between activities"),hr(),plotOutput("average_days", height = 150)),
                          box(title = "Summary Table", status = "warning", collapsible=T,
                          width=12, DT::dataTableOutput("summary"), DT::dataTableOutput("drilldown"), downloadButton("downloaddDrill","Download data"))
                        ),hr(),
                        fluidRow(
                          box(title = "Today activities: This section displays the most recent records",width = 12,status = "warning"),
                          box(width = 10, column(4,tableOutput("dsumTable")),
                          column(6, tableOutput("dTable")),
                          column(2,"" ),
                          htmlOutput("text"))
                          )
                        ),
                  tabItem(tabName = "explorer",
                        fluidRow(
                          box(title = "Description", background = "olive", width=2, collapsible = TRUE,
                                "This data explorer offers a quick way of exploring all data sets based on locations, 
                                activities and date range. Select one or more locations in order to display activity select input as well as the date range "
                        ),
                          box(width = 10,column(4,selectInput("locations", "locations", c("All locations"="", unique(cleantable$location)), multiple=TRUE)),
                              column(4,conditionalPanel("input.locations",selectInput("activities", "Activities", c("Activities"=""), multiple=TRUE))),
                              column(4,conditionalPanel("input.locations",sliderInput("dateRange","Date range", min = min(ymd(cleantable$date)),
                                     max = max(ymd(cleantable$date)),2,value = c(min(ymd(cleantable$date)),max(ymd(cleantable$date))),step = 1))),
                                      hr(),column(12, DT::dataTableOutput("dataExplorer"))))
                        ),
                  
                  tabItem(tabName = "tables",
                      fluidRow(
                        box(title = "Crosses", width = 12, background = "olive", height=50), hr(),
                        box(status = "warning", width=12,collapsible=T,
                            column(3,selectInput("select_activity", "Choose datasets", 
                                          choices = c("All crosses data","Flowering","Firstpollination","RepeatPollination","Harvested",
                                            "Ripened","Seed_extraction","Embryorescue","Germinating_two_weeks","Germinating_6weeks"))),
                            column(3, offset = 3, downloadButton('downloadcrosses', 'Download data')),
                            hr(),
                            column(12, div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                              DT::dataTableOutput("crossesTable"))
                                              ))
                        ),
                      fluidRow(
                        box(title = "Plantlets", width = 12, background = "yellow", height=50), hr(),  
                        box(status = "success",width = 12,collapsible=T,
                            column(3,selectInput("plantlets","Plantlets datasets", 
                                               choices = c("All plantlets data","Rooting","Screenhouse","Hardening","Openfield"))),
                            column(3, offset = 3, downloadButton('downloadplantlets', 'Download data')),
                            hr(),
                        column(12, div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                     DT::dataTableOutput("plantletsTable"))
                                 )
                        )),
                      fluidRow(
                        box(title = "Status and contamination", width = 12, background = "olive", height=50), hr(),
                        box(status = "warning", width=12,collapsible=T,
                            column(3,selectInput("statusCont","Status and contamination", choices = c("Status","Contamination"))),
                            column(3, offset = 3, downloadButton('downloadstatusCont', 'Download data')),
                            hr(),
                            column(12, div(style = c('overflow-x: scroll', "font-size: 75%; width: 75%"),
                                           DT::dataTableOutput("statusConTable"))
                            ))
                      )
                      
            ),
            #### Introduction Tab ----
            tabItem(tabName = "Introduction",  
                    fluidRow(
                      box(
                        title = " ", solidHeader = T,
                        img(src="banana.png", height = 200, width = 150, align="left", position="absolute"),
                        h1("Banana pipeline analysis"),
                        #h4("Margaret Karanja - 2017"),
                        br(),
                        p("Banana pipeline analysis is a reporting tool of banana cross management from breeding programs in Uganda (NARO Kawanda, IITA Sendusu), Tanzania (IITA Arusha - Nelson Mandela University) as well as Nigeria (Ibadan).
                          "),
                        br(),
                        br(),
                        br(),
                        br(),
                        br(),
                        p("The tool aims at improving data management by proving live reports on project stage, status as well as accomplishments. Data used are collected, compiled and updated on daily basis and hence ensuring up to date reports."), 
                        br(),br(),br(),br(),br(),
                        h4(strong("Contact")),
                        p("For feedback, suggestions or queries please leave a message on the feedback section. Thank you"),
                        
                        width=10),
                      box(background = "olive", width = 12, height = 62,
                          column(10, img(src="iita.png", height = 50, width = 100, align="right")),
                          column(2, img(src="betterBanana.png",height = 50, width = 100, align="right"))
                          )
                        )
                    
            ), #close intro tab no comma.
            tabItem(tabName = "feedback",
                    fluidRow(
                      box(title = "Please leave us a message on feedback, queries or suggestions",width = 12, background = "olive"),
                      box( width = 10,
                        # admin panel will only be shown to users with sufficient privileges
                        uiOutput("adminPanel"),
                        
                        conditionalPanel(
                          # only show this form before the form is submitted
                          condition = "!output.formSubmitted",
                          
                          # form fields
                          textInput(inputId = "fullName", label = "Your name"),
                          textInput(inputId = "email", label = "Email address"),
                          textAreaInput(inputId = "message", label = "Message", width = '100%', height = '150px', resize = "both"),
                          
                         # inputId, label, value = "", width = NULL, height = NULL,
                        #  cols = NULL, rows = NULL, placeholder = NULL, resize = NULL
                          
                          
                          br(),
                          actionButton(inputId = "submitBtn", label = "Submit")
                          
                          # the following lines use a confirmation dialog before submitting
                          #modalTriggerButton("submitBtn", "#submitConfirmDlg", "Submit"),
                          #modalDialog(id="submitConfirmDlg", body = "Are you sure you want to submit?",
                          #            footer=list(
                          #  modalTriggerButton("submitConfirmDlg", "#submitConfirmDlg", "Submit"),
                          #  tags$button(type = "button", class = "btn btn-primary", 'data-dismiss' = "modal", "Cancel")
                          #))
                        ),
                        
                        conditionalPanel(
                          # thank you screen after form is submitted
                          condition = "output.formSubmitted",
                          
                          h3(textOutput("thanksName"))
                        )
                      )
                          
                      )
                      
                    ))
        )
)
)
