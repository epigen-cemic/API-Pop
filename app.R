source("global.R")

ui <- fluidPage(
  # Call the fully encapsulated main module
  analysisUI("main_module")
)

#' Run the Shiny application server
#'
#' Initialize the main application server and register its modules.
#'
#' @param input Shiny input object for the current module.
#' @param output Shiny output object for the current module.
#' @param session Active Shiny session.
#' @return The Shiny server side-effect result.
#' @keywords internal
server <- function(input, output, session) {
  # Initialize the main orchestrator module
  analysisServer("main_module", con = pool, gpkg_path = gpkg_path)
}

shinyApp(ui = ui, server = server)