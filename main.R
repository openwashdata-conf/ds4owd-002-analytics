# Main script for Course Analytics Data Collection Pipeline
# This is the entry point for the entire data collection and storage process

library(cli)

# Source the main orchestration and storage scripts
source("scripts/orchestrate_collection.R")
source("scripts/store_to_postgres.R")

# Main function to run the complete pipeline
run_analytics_pipeline <- function(sources = "all", storage_method = "append") {
  cli_h1("📊 Course Analytics Data Collection Pipeline")
  cli_alert_info("Starting complete data collection and storage pipeline...")
  
  # Run the full pipeline
  results <- collect_and_store_all_data(
    sources = sources,
    storage_method = storage_method
  )
  
  return(results)
}

# Convenience functions for common operations
collect_only <- function(sources = "all") {
  cli_h1("📥 Data Collection Only")
  source("scripts/orchestrate_collection.R")
  orchestrate_data_collection(sources = sources, save_files = TRUE)
}

store_only <- function(data_list, storage_method = "append") {
  cli_h1("💾 Database Storage Only")
  source("scripts/store_to_postgres.R")
  store_all_data_to_postgres(data_list, storage_method)
}

setup_database_only <- function() {
  cli_h1("🔧 Database Setup Only")
  source("scripts/setup_database.R")
  setup_database_schema()
}

# Display usage instructions
show_usage <- function() {
  cli_h1("📖 Usage Instructions")
  cli_alert_info("Available functions:")
  cli_ul(c(
    "run_analytics_pipeline() - Complete pipeline (collect + store)",
    "collect_only() - Data collection only",
    "store_only(data_list) - Database storage only", 
    "setup_database_only() - Database setup only"
  ))
  
  cli_h2("Examples:")
  cli_code(c(
    "# Run complete pipeline",
    "results <- run_analytics_pipeline()",
    "",
    "# Collect specific sources only",
    "survey_data <- collect_only(c('pre_survey', 'post_survey'))",
    "",
    "# Setup database schema",
    "setup_database_only()"
  ))
}

# If script is run directly, show usage
if (interactive()) {
  show_usage()
  cli_alert_info("Ready to run! Use run_analytics_pipeline() to start.")
}