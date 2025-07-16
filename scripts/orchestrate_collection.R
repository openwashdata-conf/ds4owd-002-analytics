source("scripts/utils.R")

library(purrr)
library(dplyr)
library(lubridate)
library(cli)
library(config)

# Load configuration
config <- config::get()

# Source all collection scripts
source("scripts/collect_pre_survey.R")
source("scripts/collect_post_survey.R")
source("scripts/collect_posit_cloud.R")
source("scripts/collect_zoom_sessions.R")
source("scripts/collect_zoom_recordings.R")
source("scripts/collect_github_commits.R")

# Main orchestration function
orchestrate_data_collection <- function(sources = "all", save_files = TRUE) {
  cli_h1("Starting Course Analytics Data Collection")
  
  # Define available data sources
  available_sources <- list(
    "pre_survey" = list(
      name = "Pre-Course Survey",
      func = collect_pre_survey,
      df_name = "pre_course_survey_df"
    ),
    "post_survey" = list(
      name = "Post-Course Survey", 
      func = collect_post_survey,
      df_name = "post_course_survey_df"
    ),
    "posit_cloud" = list(
      name = "Posit Cloud Usage",
      func = collect_posit_cloud,
      df_name = "posit_usage_df"
    ),
    "zoom_sessions" = list(
      name = "Zoom Live Sessions",
      func = collect_zoom_sessions,
      df_name = "zoom_live_sessions_df"
    ),
    "zoom_recordings" = list(
      name = "Zoom Recordings",
      func = collect_zoom_recordings,
      df_name = "zoom_recordings_df"
    ),
    "github_commits" = list(
      name = "GitHub Commits",
      func = collect_github_commits,
      df_name = "github_commits_df"
    )
  )
  
  # Determine which sources to collect
  if (sources == "all") {
    sources_to_collect <- available_sources
  } else {
    sources_to_collect <- available_sources[sources]
  }
  
  # Collection results storage
  collection_results <- list()
  collection_summary <- tibble(
    source = character(),
    status = character(),
    records_collected = integer(),
    duration_seconds = numeric(),
    error_message = character()
  )
  
  # Create data directory if it doesn't exist
  if (save_files && !dir.exists("data")) {
    dir.create("data", recursive = TRUE)
  }
  
  # Execute data collection for each source
  for (source_key in names(sources_to_collect)) {
    source_info <- sources_to_collect[[source_key]]
    
    cli_h2("Collecting: {source_info$name}")
    
    start_time <- Sys.time()
    
    tryCatch({
      # Execute collection function
      result_df <- source_info$func()
      
      # Store results
      collection_results[[source_info$df_name]] <- result_df
      
      # Record success
      end_time <- Sys.time()
      duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
      
      collection_summary <- collection_summary |>
        add_row(
          source = source_info$name,
          status = "success",
          records_collected = nrow(result_df),
          duration_seconds = duration,
          error_message = ""
        )
      
      cli_alert_success("✅ {source_info$name}: {nrow(result_df)} records collected in {round(duration, 2)} seconds")
      
    }, error = function(e) {
      # Record failure
      end_time <- Sys.time()
      duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
      
      collection_summary <<- collection_summary |>
        add_row(
          source = source_info$name,
          status = "error",
          records_collected = 0,
          duration_seconds = duration,
          error_message = as.character(e$message)
        )
      
      cli_alert_danger("❌ {source_info$name}: {e$message}")
      
      # Store empty result
      collection_results[[source_info$df_name]] <- tibble()
    })
  }
  
  # Summary report
  cli_h2("Collection Summary")
  
  successful_collections <- collection_summary |> filter(status == "success")
  failed_collections <- collection_summary |> filter(status == "error")
  
  cli_alert_info("Total sources attempted: {nrow(collection_summary)}")
  cli_alert_success("Successful collections: {nrow(successful_collections)}")
  cli_alert_danger("Failed collections: {nrow(failed_collections)}")
  
  if (nrow(successful_collections) > 0) {
    total_records <- sum(successful_collections$records_collected)
    cli_alert_info("Total records collected: {total_records}")
  }
  
  # Print detailed summary
  collection_summary |>
    mutate(
      duration_formatted = paste0(round(duration_seconds, 2), "s"),
      records_formatted = ifelse(status == "success", 
                                 paste0(records_collected, " records"), 
                                 "Failed")
    ) |>
    select(source, status, records_formatted, duration_formatted) |>
    print()
  
  # Save collection metadata
  if (save_files) {
    readr::write_csv(collection_summary, "data/collection_summary.csv")
    cli_alert_info("Collection summary saved to data/collection_summary.csv")
  }
  
  # Return results
  return(list(
    data = collection_results,
    summary = collection_summary
  ))
}

# Quick collection function for specific sources
collect_specific_sources <- function(sources) {
  orchestrate_data_collection(sources = sources, save_files = TRUE)
}

# Main execution function
main <- function() {
  cli_h1("Course Analytics Data Collection Pipeline")
  
  # Run full collection
  results <- orchestrate_data_collection()
  
  # Print final message
  cli_rule()
  cli_alert_success("Data collection orchestration completed!")
  cli_alert_info("Use the returned data frames for further analysis or database storage")
  cli_rule()
  
  return(results)
}

# Run orchestration if script is executed directly
if (interactive()) {
  collection_results <- main()
  
  # Extract data frames for easy access
  if (length(collection_results$data) > 0) {
    list2env(collection_results$data, envir = .GlobalEnv)
    cli_alert_info("Data frames available: {paste(names(collection_results$data), collapse = ', ')}")
  }
}