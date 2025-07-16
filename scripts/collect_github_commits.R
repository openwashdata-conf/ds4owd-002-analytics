source("scripts/utils.R")
source("scripts/setup_credentials.R")

library(httr2)
library(dplyr)
library(purrr)
library(lubridate)
library(jsonlite)
library(keyring)

# Collect GitHub commits data from course organization
collect_github_commits_data <- function() {
  cli_alert_info("Starting GitHub commits data collection...")
  
  # Get credentials from keyring
  base_url <- get_credential("github", "base_url")
  organization <- get_credential("github", "organization")
  token <- get_credential("github", "token")
  
  # Check if all credentials are available
  if (is.null(base_url) || is.null(organization) || is.null(token)) {
    cli_alert_danger("GitHub credentials not found in keyring")
    cli_alert_info("Run setup_course_analytics_credentials() to set them up")
    return(tibble())
  }
  
  # First, get list of repositories in the organization
  repos_url <- paste0(base_url, "/orgs/", organization, "/repos")
  
  # Authentication headers
  headers <- list(
    Authorization = paste0("Bearer ", token),
    "Accept" = "application/vnd.github.v3+json",
    "X-GitHub-Api-Version" = "2022-11-28"
  )
  
  # Fetch all repositories
  all_repos <- paginate_api_requests(
    base_url = repos_url,
    headers = headers,
    initial_params = list(
      type = "all",
      sort = "updated",
      direction = "desc"
    ),
    page_param = "page",
    per_page_param = "per_page",
    per_page = 100
  )
  
  if (length(all_repos) == 0) {
    cli_alert_warning("No repositories found in organization")
    return(tibble())
  }
  
  # Extract repository names
  repo_names <- all_repos |>
    map_dfr(~ {
      if (is.list(.x) && length(.x) > 0) {
        .x
      } else {
        list()
      }
    }) |>
    pull(name)
  
  cli_alert_info("Found {length(repo_names)} repositories")
  
  # For each repository, get commits from the last 30 days
  since_date <- (today() - days(30)) |> format("%Y-%m-%dT%H:%M:%SZ")
  
  all_commits <- repo_names |>
    map_dfr(~ {
      repo_name <- .x
      
      commits_url <- paste0(base_url, "/repos/", organization, "/", repo_name, "/commits")
      
      cli_progress_step("Fetching commits for repository {repo_name}")
      
      # Get commits for this repository
      repo_commits <- paginate_api_requests(
        base_url = commits_url,
        headers = headers,
        initial_params = list(
          since = since_date,
          per_page = 100
        ),
        page_param = "page",
        per_page_param = "per_page",
        per_page = 100
      )
      
      if (length(repo_commits) > 0) {
        repo_commits |>
          map_dfr(~ {
            if (is.list(.x) && length(.x) > 0) {
              .x
            } else {
              list()
            }
          }) |>
          mutate(repository_name = repo_name)
      } else {
        tibble()
      }
    })
  
  if (nrow(all_commits) == 0) {
    cli_alert_warning("No commits found in any repository")
    return(tibble())
  }
  
  # Process commits data into standardized format
  github_commits_df <- all_commits |>
    # Standardize column names and structure
    mutate(
      commit_sha = case_when(
        !is.null(sha) ~ as.character(sha),
        !is.null(id) ~ as.character(id),
        TRUE ~ paste0("commit_", row_number())
      ),
      repository_name = as.character(repository_name),
      author_username = case_when(
        !is.null(author) && !is.null(author$login) ~ as.character(author$login),
        !is.null(committer) && !is.null(committer$login) ~ as.character(committer$login),
        TRUE ~ "Unknown Author"
      ),
      author_email = case_when(
        !is.null(commit) && !is.null(commit$author) && !is.null(commit$author$email) ~ 
          as.character(commit$author$email),
        !is.null(commit) && !is.null(commit$committer) && !is.null(commit$committer$email) ~ 
          as.character(commit$committer$email),
        TRUE ~ "unknown@example.com"
      ),
      commit_message = case_when(
        !is.null(commit) && !is.null(commit$message) ~ as.character(commit$message),
        !is.null(message) ~ as.character(message),
        TRUE ~ "No message"
      ),
      commit_date = case_when(
        !is.null(commit) && !is.null(commit$author) && !is.null(commit$author$date) ~ 
          ymd_hms(commit$author$date),
        !is.null(commit) && !is.null(commit$committer) && !is.null(commit$committer$date) ~ 
          ymd_hms(commit$committer$date),
        TRUE ~ now("UTC")
      ),
      # Get additional stats for each commit (requires separate API call)
      commit_stats = map(commit_sha, ~ {
        stats_url <- paste0(base_url, "/repos/", organization, "/", repository_name[1], "/commits/", .x)
        
        stats_data <- safe_api_request(stats_url, headers = headers)
        
        if (!is.null(stats_data) && !is.null(stats_data$stats)) {
          list(
            additions = stats_data$stats$additions %||% 0,
            deletions = stats_data$stats$deletions %||% 0,
            total = stats_data$stats$total %||% 0
          )
        } else {
          list(additions = 0, deletions = 0, total = 0)
        }
      })
    ) |>
    # Extract commit statistics
    mutate(
      additions = map_int(commit_stats, ~ .x$additions),
      deletions = map_int(commit_stats, ~ .x$deletions),
      changed_files = map_int(commit_stats, ~ .x$total)
    ) |>
    select(commit_sha, repository_name, author_username, author_email, 
           commit_message, commit_date, additions, deletions, changed_files) |>
    standardize_timestamps(c("commit_date")) |>
    clean_dataframe(required_cols = c("commit_sha", "repository_name", "author_username"))
  
  cli_alert_success("Collected {nrow(github_commits_df)} GitHub commits")
  
  return(github_commits_df)
}

# Main execution function
collect_github_commits <- function() {
  tryCatch({
    github_commits_df <- collect_github_commits_data()
    
    # Save to CSV for backup
    if (nrow(github_commits_df) > 0) {
      readr::write_csv(
        github_commits_df, 
        "data/github_commits.csv"
      )
      cli_alert_success("GitHub commits data saved to data/github_commits.csv")
    }
    
    return(github_commits_df)
    
  }, error = function(e) {
    cli_alert_danger("Error collecting GitHub commits data: {e$message}")
    return(tibble())
  })
}

# Run collection if script is executed directly
if (interactive()) {
  github_commits_df <- collect_github_commits()
  message("GitHub commits data collection completed!")
}