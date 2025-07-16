source("scripts/utils.R")
source("scripts/setup_credentials.R")

library(httr2)
library(dplyr)
library(purrr)
library(lubridate)
library(jsonlite)
library(keyring)

# Collect Zoom live sessions data
collect_zoom_sessions_data <- function() {
  cli_alert_info("Starting Zoom live sessions data collection...")
  
  # Get credentials from keyring
  base_url <- get_credential("zoom", "base_url")
  api_key <- get_credential("zoom", "api_key")
  
  # Check if all credentials are available
  if (is.null(base_url) || is.null(api_key)) {
    cli_alert_danger("Zoom credentials not found in keyring")
    cli_alert_info("Run setup_course_analytics_credentials() to set them up")
    return(tibble())
  }
  
  # First, get list of meetings
  meetings_url <- paste0(base_url, "/users/me/meetings")
  
  # Authentication headers (using JWT or OAuth)
  headers <- list(
    Authorization = paste0("Bearer ", api_key),
    "Content-Type" = "application/json"
  )
  
  # Get meetings from the last 30 days
  end_date <- today()
  start_date <- end_date - days(30)
  
  # Fetch meetings list
  all_meetings <- paginate_api_requests(
    base_url = meetings_url,
    headers = headers,
    initial_params = list(
      type = "live",
      from = format(start_date, "%Y-%m-%d"),
      to = format(end_date, "%Y-%m-%d")
    ),
    page_param = "page_number",
    per_page_param = "page_size",
    per_page = 100
  )
  
  if (length(all_meetings) == 0) {
    cli_alert_warning("No Zoom meetings found")
    return(tibble())
  }
  
  # Extract meeting IDs
  meeting_ids <- all_meetings %>%
    map_dfr(~ {
      if ("meetings" %in% names(.x)) {
        .x$meetings
      } else {
        .x
      }
    }) %>%
    pull(id)
  
  # Get participant data for each meeting
  all_participants <- meeting_ids %>%
    map_dfr(~ {
      meeting_id <- .x
      
      # Get participants for this meeting
      participants_url <- paste0(base_url, "/report/meetings/", meeting_id, "/participants")
      
      cli_progress_step("Fetching participants for meeting {meeting_id}")
      
      participants_data <- paginate_api_requests(
        base_url = participants_url,
        headers = headers,
        initial_params = list(),
        page_param = "page_number",
        per_page_param = "page_size",
        per_page = 100
      )
      
      if (length(participants_data) > 0) {
        participants_data %>%
          map_dfr(~ {
            if ("participants" %in% names(.x)) {
              .x$participants
            } else {
              .x
            }
          }) %>%
          mutate(meeting_id = meeting_id)
      } else {
        tibble()
      }
    })
  
  if (nrow(all_participants) == 0) {
    cli_alert_warning("No Zoom session participants found")
    return(tibble())
  }
  
  # Process participant data into standardized format
  zoom_live_sessions_df <- all_participants %>%
    # Standardize column names and structure
    mutate(
      meeting_id = as.character(meeting_id),
      participant_id = case_when(
        !is.null(user_id) ~ as.character(user_id),
        !is.null(id) ~ as.character(id),
        !is.null(participant_uuid) ~ as.character(participant_uuid),
        TRUE ~ paste0("participant_", row_number())
      ),
      participant_name = case_when(
        !is.null(name) ~ as.character(name),
        !is.null(user_name) ~ as.character(user_name),
        !is.null(display_name) ~ as.character(display_name),
        TRUE ~ "Unknown Participant"
      ),
      join_time = case_when(
        !is.null(join_time) ~ ymd_hms(join_time),
        !is.null(joined_at) ~ ymd_hms(joined_at),
        TRUE ~ as.POSIXct(NA)
      ),
      leave_time = case_when(
        !is.null(leave_time) ~ ymd_hms(leave_time),
        !is.null(left_at) ~ ymd_hms(left_at),
        TRUE ~ as.POSIXct(NA)
      ),
      duration_minutes = case_when(
        !is.null(duration) ~ as.integer(duration / 60),
        !is.na(leave_time) & !is.na(join_time) ~ as.integer(difftime(leave_time, join_time, units = "mins")),
        TRUE ~ as.integer(NA)
      ),
      meeting_topic = case_when(
        !is.null(topic) ~ as.character(topic),
        !is.null(meeting_topic) ~ as.character(meeting_topic),
        !is.null(subject) ~ as.character(subject),
        TRUE ~ "Unknown Topic"
      ),
      meeting_date = case_when(
        !is.na(join_time) ~ as.Date(join_time),
        !is.null(start_time) ~ as.Date(ymd_hms(start_time)),
        TRUE ~ as.Date(NA)
      )
    ) %>%
    select(meeting_id, participant_id, participant_name, join_time, leave_time, 
           duration_minutes, meeting_topic, meeting_date) %>%
    standardize_timestamps(c("join_time", "leave_time")) %>%
    clean_dataframe(required_cols = c("meeting_id", "participant_id"))
  
  cli_alert_success("Collected {nrow(zoom_live_sessions_df)} Zoom live session records")
  
  return(zoom_live_sessions_df)
}

# Main execution function
collect_zoom_sessions <- function() {
  tryCatch({
    zoom_live_sessions_df <- collect_zoom_sessions_data()
    
    # Save to CSV for backup
    if (nrow(zoom_live_sessions_df) > 0) {
      readr::write_csv(
        zoom_live_sessions_df, 
        "data/zoom_live_sessions.csv"
      )
      cli_alert_success("Zoom live sessions data saved to data/zoom_live_sessions.csv")
    }
    
    return(zoom_live_sessions_df)
    
  }, error = function(e) {
    cli_alert_danger("Error collecting Zoom live sessions data: {e$message}")
    return(tibble())
  })
}

# Run collection if script is executed directly
if (interactive()) {
  zoom_live_sessions_df <- collect_zoom_sessions()
  message("Zoom live sessions data collection completed!")
}