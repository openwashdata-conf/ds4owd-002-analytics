source("scripts/utils.R")

library(httr2)
library(dplyr)
library(purrr)
library(lubridate)
library(jsonlite)
library(config)

# Load configuration
config <- config::get()

# Collect post-course survey data from Enketo/Kobo Toolbox
collect_post_survey_data <- function() {
  cli_alert_info("Starting post-course survey data collection...")
  
  # API endpoint for submissions
  submissions_url <- paste0(
    config$enketo$base_url,
    "/data/", 
    config$enketo$post_survey_form_id
  )
  
  # Authentication headers
  headers <- list(
    Authorization = paste0("Basic ", 
                          base64enc::base64encode(
                            charToRaw(paste0(config$enketo$username, ":", config$enketo$password))
                          ))
  )
  
  # Fetch submissions with pagination
  all_submissions <- paginate_api_requests(
    base_url = submissions_url,
    headers = headers,
    initial_params = list(
      format = "json",
      sort = '{"_submission_time": -1}'
    ),
    page_param = "start",
    per_page_param = "limit",
    per_page = 100
  )
  
  if (length(all_submissions) == 0) {
    cli_alert_warning("No post-course survey submissions found")
    return(tibble())
  }
  
  # Process submissions into a data frame
  post_course_survey_df <- all_submissions %>%
    map_dfr(~ {
      if (is.list(.x) && length(.x) > 0) {
        # Handle different response structures
        if ("results" %in% names(.x)) {
          .x$results
        } else {
          .x
        }
      } else {
        list()
      }
    }) %>%
    # Standardize column names and structure
    mutate(
      participant_id = case_when(
        !is.null(participant_id) ~ as.character(participant_id),
        !is.null(`_uuid`) ~ as.character(`_uuid`),
        !is.null(uuid) ~ as.character(uuid),
        TRUE ~ paste0("participant_", row_number())
      ),
      submission_date = case_when(
        !is.null(`_submission_time`) ~ ymd_hms(`_submission_time`),
        !is.null(submission_time) ~ ymd_hms(submission_time),
        !is.null(submitted_at) ~ ymd_hms(submitted_at),
        TRUE ~ now("UTC")
      ),
      # Store all response data as JSON for flexibility
      response_data = map_chr(1:n(), ~ {
        row_data <- slice(., .x)
        # Remove system columns for cleaner JSON
        response_cols <- select(row_data, -any_of(c(
          "participant_id", "submission_date", "_uuid", "uuid", 
          "_submission_time", "submission_time", "submitted_at",
          "_id", "_xform_id_string", "_bamboo_dataset_id", "_attachments"
        )))
        toJSON(response_cols, auto_unbox = TRUE)
      })
    ) %>%
    select(participant_id, submission_date, response_data) %>%
    standardize_timestamps(c("submission_date")) %>%
    clean_dataframe(required_cols = c("participant_id", "submission_date", "response_data"))
  
  cli_alert_success("Collected {nrow(post_course_survey_df)} post-course survey responses")
  
  return(post_course_survey_df)
}

# Main execution function
collect_post_survey <- function() {
  tryCatch({
    post_course_survey_df <- collect_post_survey_data()
    
    # Save to CSV for backup
    if (nrow(post_course_survey_df) > 0) {
      readr::write_csv(
        post_course_survey_df, 
        "data/post_course_survey.csv"
      )
      cli_alert_success("Post-course survey data saved to data/post_course_survey.csv")
    }
    
    return(post_course_survey_df)
    
  }, error = function(e) {
    cli_alert_danger("Error collecting post-course survey data: {e$message}")
    return(tibble())
  })
}

# Run collection if script is executed directly
if (interactive()) {
  post_course_survey_df <- collect_post_survey()
  message("Post-course survey data collection completed!")
}