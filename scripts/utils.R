library(httr2)
library(dplyr)
library(purrr)
library(lubridate)
library(rlang)
library(cli)

# Utility functions for data collection

# Safe API request with error handling
safe_api_request <- function(url, headers = NULL, query = NULL, method = "GET") {
  tryCatch({
    req <- request(url)
    
    if (!is.null(headers)) {
      req <- req_headers(req, !!!headers)
    }
    
    if (!is.null(query)) {
      req <- req_url_query(req, !!!query)
    }
    
    if (method == "GET") {
      resp <- req_perform(req)
    } else {
      resp <- req_method(req, method) %>% req_perform()
    }
    
    resp_body_json(resp)
  }, error = function(e) {
    cli_alert_danger("API request failed: {e$message}")
    return(NULL)
  })
}

# Safe API request with Basic Auth
safe_api_request_with_auth <- function(url, username, password, query = NULL, method = "GET") {
  tryCatch({
    req <- request(url) %>%
      req_auth_basic(username, password)
    
    if (!is.null(query)) {
      req <- req_url_query(req, !!!query)
    }
    
    if (method == "GET") {
      resp <- req_perform(req)
    } else {
      resp <- req_method(req, method) %>% req_perform()
    }
    
    resp_body_json(resp)
  }, error = function(e) {
    cli_alert_danger("API request failed: {e$message}")
    return(NULL)
  })
}

# Standardize timestamp columns
standardize_timestamps <- function(df, timestamp_cols) {
  df %>%
    mutate(
      across(all_of(timestamp_cols), ~ as.POSIXct(.x, tz = "UTC"))
    )
}

# Clean and validate data frame
clean_dataframe <- function(df, required_cols = NULL) {
  if (!is.null(required_cols)) {
    missing_cols <- setdiff(required_cols, names(df))
    if (length(missing_cols) > 0) {
      cli_alert_warning("Missing required columns: {missing_cols}")
    }
  }
  
  df %>%
    # Remove completely empty rows
    filter(if_all(everything(), ~ !is.na(.x) | .x != "")) %>%
    # Add collection timestamp
    mutate(collected_at = now("UTC"))
}

# Pagination helper for APIs
paginate_api_requests <- function(base_url, headers, initial_params = list(), 
                                  page_param = "page", per_page_param = "per_page", 
                                  per_page = 100, max_pages = 50) {
  
  all_data <- list()
  page <- 1
  
  while (page <= max_pages) {
    cli_progress_step("Fetching page {page}")
    
    params <- c(initial_params, 
                setNames(list(page, per_page), c(page_param, per_page_param)))
    
    response <- safe_api_request(base_url, headers = headers, query = params)
    
    if (is.null(response) || length(response) == 0) {
      break
    }
    
    all_data <- append(all_data, list(response))
    
    # Check if we've reached the end
    if (length(response) < per_page) {
      break
    }
    
    page <- page + 1
  }
  
  cli_progress_done()
  return(all_data)
}

# Pagination helper for APIs with Basic Auth
paginate_api_requests_with_auth <- function(base_url, username, password, initial_params = list(), 
                                            page_param = "page", per_page_param = "per_page", 
                                            per_page = 100, max_pages = 50) {
  
  all_data <- list()
  page <- 1
  
  while (page <= max_pages) {
    cli_progress_step("Fetching page {page}")
    
    params <- c(initial_params, 
                setNames(list(page, per_page), c(page_param, per_page_param)))
    
    response <- safe_api_request_with_auth(base_url, username, password, query = params)
    
    if (is.null(response) || length(response) == 0) {
      break
    }
    
    all_data <- append(all_data, list(response))
    
    # Check if we've reached the end
    if (length(response) < per_page) {
      break
    }
    
    page <- page + 1
  }
  
  cli_progress_done()
  return(all_data)
}

# Retry mechanism for failed requests
retry_request <- function(request_func, max_retries = 3, delay = 1) {
  for (attempt in 1:max_retries) {
    result <- request_func()
    
    if (!is.null(result)) {
      return(result)
    }
    
    if (attempt < max_retries) {
      cli_alert_info("Retrying request (attempt {attempt + 1}/{max_retries}) in {delay} seconds...")
      Sys.sleep(delay)
      delay <- delay * 2  # Exponential backoff
    }
  }
  
  cli_alert_danger("Request failed after {max_retries} attempts")
  return(NULL)
}