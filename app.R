source("R/global.R")

ui <- fluidPage(
  tags$head(
    tags$title("API Population"),
    tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
  ),
  div(class = "banner-container",
      img(src = "logoLeft.png", class = "banner-img fixed-img"),
      img(src = "logoMiddle.png", class = "banner-img flexible-img"),
      img(src = "logoRight.png", class = "banner-img fixed-img")
  ),
  
  # Call Module UI
  analysisUI("main_module")
)

server <- function(input, output, session) {
  
  # Pass gpkg_path explicitly here!
  # 'gpkg_path' should be defined in your global.R
  analysisServer("main_module", con = con, gpkg_path = gpkg_path)
  
  onStop(function() {
    if(!is.null(con)) DBI::dbDisconnect(con)
  })
}

shinyApp(ui = ui, server = server)