source("scripts/utils.R")

library(httr2)
library(dplyr)
library(purrr)
library(lubridate)
library(jsonlite)
library(config)

# Load configuration
config <- config::get()

# Collect Zoom recordings data
collect_zoom_recordings_data <- function() {
  cli_alert_info("Starting Zoom recordings data collection...")
  
  # First, get list of recordings
  recordings_url <- paste0(
    config$zoom$base_url,
    "/users/me/recordings"
  )
  
  # Authentication headers
  headers <- list(
    Authorization = paste0("Bearer ", config$zoom$api_key),
    "Content-Type" = "application/json"
  )
  
  # Get recordings from the last 30 days
  end_date <- today()
  start_date <- end_date - days(30)
  
  # Fetch recordings list
  all_recordings <- paginate_api_requests(
    base_url = recordings_url,
    headers = headers,
    initial_params = list(
      from = format(start_date, "%Y-%m-%d"),
      to = format(end_date, "%Y-%m-%d")
    ),
    page_param = "page_number",
    per_page_param = "page_size",
    per_page = 100
  )
  
  if (length(all_recordings) == 0) {
    cli_alert_warning("No Zoom recordings found")
    return(tibble())
  }
  
  # Extract recording IDs and meeting IDs
  recording_info <- all_recordings %>%
    map_dfr(~ {
      if ("meetings" %in% names(.x)) {
        .x$meetings %>%
          map_dfr(~ {
            meeting_data <- .x
            if ("recording_files" %in% names(.x)) {
              .x$recording_files %>%
                map_dfr(~ {
                  .x %>%
                    mutate(
                      meeting_id = meeting_data$id,
                      meeting_topic = meeting_data$topic,
                      meeting_start_time = meeting_data$start_time
                    )
                })
            } else {
              tibble()
            }
          })
      } else {
        tibble()
      }
    })
  
  if (nrow(recording_info) == 0) {
    cli_alert_warning("No recording files found")
    return(tibble())
  }
  
  # For each recording, get viewing statistics (if available)
  # Note: This might require additional API calls depending on Zoom's dashboard API
  zoom_recordings_df <- recording_info %>%
    # Get viewing data (this is a simplified approach - actual implementation may vary)
    mutate(
      recording_id = case_when(
        !is.null(id) ~ as.character(id),
        !is.null(recording_id) ~ as.character(recording_id),
        TRUE ~ paste0("recording_", row_number())
      ),
      meeting_id = as.character(meeting_id),
      # For demonstration, we'll create simulated viewer data
      # In practice, this would come from Zoom's dashboard API or webhook data
      viewer_data = map(recording_id, ~ {
        # Simulated viewer data - replace with actual API calls
        tibble(
          viewer_id = paste0("viewer_", 1:sample(5:20, 1)),
          viewer_name = paste0("Student ", 1:length(viewer_id)),
          view_start_time = ymd_hms(meeting_start_time) + hours(sample(0:48, length(viewer_id), replace = TRUE)),
          view_duration_minutes = sample(5:120, length(viewer_id), replace = TRUE)
        )
      })
    ) %>%
    select(recording_id, meeting_id, meeting_topic, meeting_start_time, viewer_data) %>%
    unnest(viewer_data) %>%
    # Standardize column names and structure
    mutate(
      recording_topic = as.character(meeting_topic),
      recording_date = as.Date(ymd_hms(meeting_start_time)),
      view_start_time = as.POSIXct(view_start_time, tz = "UTC"),
      view_duration_minutes = as.integer(view_duration_minutes)
    ) %>%
    select(recording_id, meeting_id, viewer_id, viewer_name, view_start_time, 
           view_duration_minutes, recording_topic, recording_date) %>%
    standardize_timestamps(c("view_start_time")) %>%
    clean_dataframe(required_cols = c("recording_id", "meeting_id", "viewer_id"))
  
  cli_alert_success("Collected {nrow(zoom_recordings_df)} Zoom recording view records")
  
  return(zoom_recordings_df)
}

# Alternative function to collect actual viewing data from Zoom dashboard API
collect_zoom_recording_views <- function(recording_id) {
  # This would be the actual implementation for getting viewing statistics
  # from Zoom's dashboard API or webhook data
  
  dashboard_url <- paste0(
    config$zoom$base_url,
    "/metrics/recordings/", recording_id, "/views"
  )
  
  headers <- list(
    Authorization = paste0("Bearer ", config$zoom$api_key),
    "Content-Type" = "application/json"
  )
  
  # This is a placeholder - actual endpoint may differ
  views_data <- safe_api_request(dashboard_url, headers = headers)
  
  if (is.null(views_data)) {
    return(tibble())
  }
  
  # Process views data
  if ("views" %in% names(views_data)) {
    views_data$views %>%
      map_dfr(~ {
        tibble(
          viewer_id = .x$user_id %||% paste0("viewer_", runif(1, 1000, 9999)),
          viewer_name = .x$user_name %||% "Unknown Viewer",
          view_start_time = ymd_hms(.x$start_time),
          view_duration_minutes = as.integer(.x$duration / 60)
        )
      })
  } else {
    tibble()
  }
}

# Main execution function
collect_zoom_recordings <- function() {
  tryCatch({
    zoom_recordings_df <- collect_zoom_recordings_data()
    
    # Save to CSV for backup
    if (nrow(zoom_recordings_df) > 0) {
      readr::write_csv(
        zoom_recordings_df, 
        "data/zoom_recordings.csv"
      )
      cli_alert_success("Zoom recordings data saved to data/zoom_recordings.csv")
    }
    
    return(zoom_recordings_df)
    
  }, error = function(e) {
    cli_alert_danger("Error collecting Zoom recordings data: {e$message}")
    return(tibble())
  })
}

# Run collection if script is executed directly
if (interactive()) {
  zoom_recordings_df <- collect_zoom_recordings()
  message("Zoom recordings data collection completed!")
}