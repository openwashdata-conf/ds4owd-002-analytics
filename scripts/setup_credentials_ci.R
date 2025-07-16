library(keyring)
library(cli)

# Setup credentials for CI/CD environment
# This script sets up credentials from environment variables in GitHub Actions

setup_ci_credentials <- function() {
  cli_h1("Setting up CI/CD Credentials from Environment Variables")
  
  # Define credential mapping from environment variables
  credential_mapping <- list(
    # Enketo/Kobo Toolbox
    "course_analytics_enketo_username" = "ENKETO_USERNAME",
    "course_analytics_enketo_password" = "ENKETO_PASSWORD", 
    "course_analytics_enketo_base_url" = "ENKETO_BASE_URL",
    "course_analytics_enketo_pre_survey_form_id" = "ENKETO_PRE_SURVEY_FORM_ID",
    "course_analytics_enketo_post_survey_form_id" = "ENKETO_POST_SURVEY_FORM_ID",
    
    # Posit Cloud
    "course_analytics_posit_cloud_api_key" = "POSIT_CLOUD_API_KEY",
    "course_analytics_posit_cloud_base_url" = "POSIT_CLOUD_BASE_URL",
    "course_analytics_posit_cloud_workspace_id" = "POSIT_CLOUD_WORKSPACE_ID",
    
    # Zoom
    "course_analytics_zoom_api_key" = "ZOOM_API_KEY",
    "course_analytics_zoom_api_secret" = "ZOOM_API_SECRET",
    "course_analytics_zoom_base_url" = "ZOOM_BASE_URL",
    "course_analytics_zoom_account_id" = "ZOOM_ACCOUNT_ID",
    
    # GitHub
    "course_analytics_github_token" = "GITHUB_TOKEN",
    "course_analytics_github_base_url" = "GITHUB_BASE_URL",
    "course_analytics_github_organization" = "GITHUB_ORGANIZATION",
    
    # Database
    "course_analytics_database_host" = "DATABASE_HOST",
    "course_analytics_database_port" = "DATABASE_PORT",
    "course_analytics_database_dbname" = "DATABASE_DBNAME",
    "course_analytics_database_user" = "DATABASE_USER",
    "course_analytics_database_password" = "DATABASE_PASSWORD"
  )
  
  # Set up keyring to use environment variables in CI
  if (Sys.getenv("GITHUB_ACTIONS") == "true") {
    # Use environment variable backend for GitHub Actions
    keyring_backend <- "env"
    cli_alert_info("Using environment variable backend for GitHub Actions")
  } else {
    # Use default backend for local development
    keyring_backend <- keyring::default_backend()
    cli_alert_info("Using default keyring backend")
  }
  
  # Set credentials from environment variables
  for (keyring_key in names(credential_mapping)) {
    env_var <- credential_mapping[[keyring_key]]
    
    # Get value from environment variable
    env_value <- Sys.getenv(env_var)
    
    if (env_value != "") {
      # Store in keyring
      keyring::key_set(keyring_key, password = env_value, service = "course_analytics")
      cli_alert_success("Set {keyring_key} from {env_var}")
    } else {
      cli_alert_warning("Environment variable {env_var} not found for {keyring_key}")
    }
  }
  
  cli_alert_success("CI/CD credentials setup completed!")
}

# Verify credentials are accessible
verify_ci_credentials <- function() {
  cli_h1("Verifying CI/CD Credentials")
  
  # Test accessing each service's credentials
  services <- c("enketo", "posit_cloud", "zoom", "github", "database")
  
  for (service in services) {
    cli_h2("Testing {service} credentials")
    
    # Test basic credential access
    tryCatch({
      if (service == "enketo") {
        username <- get_credential("enketo", "username")
        base_url <- get_credential("enketo", "base_url")
        cli_alert_success("Enketo credentials accessible")
        
      } else if (service == "posit_cloud") {
        api_key <- get_credential("posit_cloud", "api_key")
        cli_alert_success("Posit Cloud credentials accessible")
        
      } else if (service == "zoom") {
        api_key <- get_credential("zoom", "api_key")
        cli_alert_success("Zoom credentials accessible")
        
      } else if (service == "github") {
        token <- get_credential("github", "token")
        cli_alert_success("GitHub credentials accessible")
        
      } else if (service == "database") {
        host <- get_credential("database", "host")
        cli_alert_success("Database credentials accessible")
      }
      
    }, error = function(e) {
      cli_alert_danger("Error accessing {service} credentials: {e$message}")
    })
  }
}

# Source the main credentials setup functions
source("scripts/setup_credentials.R")

# Run setup if script is executed directly
if (interactive() || Sys.getenv("GITHUB_ACTIONS") == "true") {
  setup_ci_credentials()
  verify_ci_credentials()
}