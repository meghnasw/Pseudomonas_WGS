#
library(shiny)
library(readr)
library(ggplot2)
library(plotly)
library(dplyr)
library(tidyr)

library(bslib)

custom_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly",
  base_font = font_google("Inter")
)
# Load metrics from CSV created by make_metrics.R
metrics <- read_csv("combined_metrics.csv", show_col_types = FALSE)

# Identify numeric metrics for plotting (everything numeric except 'sample')
numeric_cols <- names(metrics)[sapply(metrics, is.numeric)]
numeric_cols <- setdiff(numeric_cols, "sample")

ui <- navbarPage(
  theme = custom_theme, titlePanel("WGS QC dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      textInput("sample_filter", "Filter samples (substring or regex):", ""),
      selectInput("metric", "Metric to plot:", choices = numeric_cols, selected = "n50"),
      helpText("Tip: try filtering by '3A06' or 's3b'.")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Summary",
                 h3("Summary table"),
                 tableOutput("summary_table"),
                 h4("Clicked sample details"),
                 tableOutput("click_info")
        ),
        tabPanel("Metric plot",
                 h3("Interactive bar plot"),
                 plotlyOutput("metric_plot", height = "350px")
        ),
        tabPanel("Faceted metrics",
                 h3("Contigs, N50, and gene counts"),
                 plotlyOutput("facet_plot", height = "450px")
        ),
        tabPanel(
          "MultiQC report",
          h3("Embedded MultiQC HTML"),
          tags$iframe(
            src = "multiqc_report.html",
            style = "width:100%; height:800px; border:none;"
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  # Filtered metrics based on sample search box
  filtered_metrics <- reactive({
    df <- metrics
    if (nzchar(input$sample_filter)) {
      df <- df[grepl(input$sample_filter, df$sample, ignore.case = TRUE), ]
    }
    df
  })
  
  # Summary table
  output$summary_table <- renderTable({
    filtered_metrics()
  })
  
  # Interactive metric plot (dropdown metric)
  output$metric_plot <- renderPlotly({
    df <- filtered_metrics()
    req(nrow(df) > 0, input$metric)
    
    p <- ggplot(df, aes(x = sample, y = .data[[input$metric]])) +
      geom_col() +
      theme_bw() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(x = "Sample", y = input$metric)
    
    ggplotly(p, source = "metricplot")
  })
  
  # Clickable points: show metadata for clicked sample
  output$click_info <- renderTable({
    click <- event_data("plotly_click", source = "metricplot")
    if (is.null(click)) return(NULL)
    
    clicked_sample <- click$x
    filtered_metrics() %>%
      filter(sample == clicked_sample)
  })
  
  # Faceted plot for a few key metrics
  output$facet_plot <- renderPlotly({
    df <- filtered_metrics()
    req(nrow(df) > 0)
    
    key_metrics <- c("contigs", "n50", "gene_count")
    key_metrics <- intersect(key_metrics, names(df))
    
    long_df <- df %>%
      select(sample, all_of(key_metrics)) %>%
      pivot_longer(-sample, names_to = "metric", values_to = "value")
    
    p <- ggplot(long_df, aes(x = sample, y = value)) +
      geom_col() +
      facet_wrap(~ metric, scales = "free_y") +
      theme_bw() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(x = "Sample", y = "Value")
    
    ggplotly(p)
  })
}

shinyApp(ui, server)

