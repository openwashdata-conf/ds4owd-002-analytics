source("scripts/utils.R")
source("scripts/setup_credentials.R")

library(httr2)
library(dplyr)
library(purrr)
library(lubridate)
library(jsonlite)
library(keyring)

# Collect post-course survey data from Enketo/Kobo Toolbox
collect_post_survey_data <- function() {
  cli_alert_info("Starting post-course survey data collection...")
  
  # Get credentials from keyring
  base_url <- get_credential("enketo", "base_url")
  form_id <- get_credential("enketo", "post_survey_form_id")
  username <- get_credential("enketo", "username")
  password <- get_credential("enketo", "password")
  
  # Check if all credentials are available
  if (is.null(base_url) || is.null(form_id) || is.null(username) || is.null(password)) {
    cli_alert_danger("Enketo credentials not found in keyring")
    cli_alert_info("Run setup_course_analytics_credentials() to set them up")
    return(tibble())
  }
  
  # API endpoint for submissions
  submissions_url <- paste0(base_url, "/data/", form_id)
  
  # Fetch submissions with pagination using httr2 Basic Auth
  all_submissions <- paginate_api_requests_with_auth(
    base_url = submissions_url,
    username = username,
    password = password,
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