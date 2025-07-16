source("scripts/utils.R")
source("scripts/setup_credentials.R")

library(httr2)
library(dplyr)
library(purrr)
library(lubridate)
library(jsonlite)
library(keyring)

# Collect Posit Cloud usage data
collect_posit_cloud_data <- function() {
  cli_alert_info("Starting Posit Cloud usage data collection...")
  
  # Get credentials from keyring
  base_url <- get_credential("posit_cloud", "base_url")
  workspace_id <- get_credential("posit_cloud", "workspace_id")
  api_key <- get_credential("posit_cloud", "api_key")
  
  # Check if all credentials are available
  if (is.null(base_url) || is.null(workspace_id) || is.null(api_key)) {
    cli_alert_danger("Posit Cloud credentials not found in keyring")
    cli_alert_info("Run setup_course_analytics_credentials() to set them up")
    return(tibble())
  }
  
  # API endpoint for workspace usage
  usage_url <- paste0(base_url, "/workspaces/", workspace_id, "/usage")
  
  # Authentication headers
  headers <- list(
    Authorization = paste0("Bearer ", api_key),
    "Content-Type" = "application/json"
  )
  
  # Calculate date range (last 30 days by default)
  end_date <- today()
  start_date <- end_date - days(30)
  
  # Fetch usage data with pagination
  all_usage_data <- paginate_api_requests(
    base_url = usage_url,
    headers = headers,
    initial_params = list(
      start_date = format(start_date, "%Y-%m-%d"),
      end_date = format(end_date, "%Y-%m-%d"),
      include_sessions = "true",
      include_projects = "true"
    ),
    page_param = "page",
    per_page_param = "per_page",
    per_page = 100
  )
  
  if (length(all_usage_data) == 0) {
    cli_alert_warning("No Posit Cloud usage data found")
    return(tibble())
  }
  
  # Process usage data into a data frame
  posit_usage_df <- all_usage_data |>
    map_dfr(~ {
      if (is.list(.x) && "sessions" %in% names(.x)) {
        .x$sessions
      } else if (is.list(.x) && length(.x) > 0) {
        .x
      } else {
        list()
      }
    }) |>
    # Standardize column names and structure
    mutate(
      user_id = case_when(
        !is.null(user_id) ~ as.character(user_id),
        !is.null(owner_id) ~ as.character(owner_id),
        !is.null(username) ~ as.character(username),
        TRUE ~ paste0("user_", row_number())
      ),
      session_id = case_when(
        !is.null(session_id) ~ as.character(session_id),
        !is.null(id) ~ as.character(id),
        TRUE ~ paste0("session_", row_number())
      ),
      start_time = case_when(
        !is.null(start_time) ~ ymd_hms(start_time),
        !is.null(started_at) ~ ymd_hms(started_at),
        !is.null(created_at) ~ ymd_hms(created_at),
        TRUE ~ now("UTC")
      ),
      end_time = case_when(
        !is.null(end_time) ~ ymd_hms(end_time),
        !is.null(ended_at) ~ ymd_hms(ended_at),
        !is.null(stopped_at) ~ ymd_hms(stopped_at),
        TRUE ~ as.POSIXct(NA)
      ),
      duration_minutes = case_when(
        !is.null(duration_seconds) ~ as.integer(duration_seconds / 60),
        !is.null(duration_minutes) ~ as.integer(duration_minutes),
        !is.na(end_time) & !is.na(start_time) ~ as.integer(difftime(end_time, start_time, units = "mins")),
        TRUE ~ as.integer(NA)
      ),
      project_name = case_when(
        !is.null(project_name) ~ as.character(project_name),
        !is.null(project_title) ~ as.character(project_title),
        !is.null(name) ~ as.character(name),
        TRUE ~ "Unknown Project"
      ),
      cpu_usage = case_when(
        !is.null(cpu_usage_percent) ~ as.numeric(cpu_usage_percent),
        !is.null(cpu_usage) ~ as.numeric(cpu_usage),
        !is.null(avg_cpu_usage) ~ as.numeric(avg_cpu_usage),
        TRUE ~ as.numeric(NA)
      ),
      memory_usage = case_when(
        !is.null(memory_usage_percent) ~ as.numeric(memory_usage_percent),
        !is.null(memory_usage) ~ as.numeric(memory_usage),
        !is.null(avg_memory_usage) ~ as.numeric(avg_memory_usage),
        TRUE ~ as.numeric(NA)
      )
    ) |>
    select(user_id, session_id, start_time, end_time, duration_minutes, 
           project_name, cpu_usage, memory_usage) |>
    standardize_timestamps(c("start_time", "end_time")) |>
    clean_dataframe(required_cols = c("user_id", "session_id", "start_time"))
  
  cli_alert_success("Collected {nrow(posit_usage_df)} Posit Cloud usage sessions")
  
  return(posit_usage_df)
}

# Main execution function
collect_posit_cloud <- function() {
  tryCatch({
    posit_usage_df <- collect_posit_cloud_data()
    
    # Save to CSV for backup
    if (nrow(posit_usage_df) > 0) {
      readr::write_csv(
        posit_usage_df, 
        "data/posit_cloud_usage.csv"
      )
      cli_alert_success("Posit Cloud usage data saved to data/posit_cloud_usage.csv")
    }
    
    return(posit_usage_df)
    
  }, error = function(e) {
    cli_alert_danger("Error collecting Posit Cloud usage data: {e$message}")
    return(tibble())
  })
}

# Run collection if script is executed directly
if (interactive()) {
  posit_usage_df <- collect_posit_cloud()
  message("Posit Cloud usage data collection completed!")
}