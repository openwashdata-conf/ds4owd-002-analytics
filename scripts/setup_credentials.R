library(keyring)
library(cli)

# Setup credentials in keyring
# This script helps set up all necessary credentials securely

setup_course_analytics_credentials <- function() {
  cli_h1("Setting up Course Analytics Credentials")
  
  # Service identifiers
  services <- list(
    enketo = list(
      name = "Enketo/Kobo Toolbox",
      keys = c("username", "password", "base_url", "pre_survey_form_id", "post_survey_form_id")
    ),
    posit_cloud = list(
      name = "Posit Cloud",
      keys = c("api_key", "base_url", "workspace_id")
    ),
    zoom = list(
      name = "Zoom",
      keys = c("api_key", "api_secret", "base_url", "account_id")
    ),
    github = list(
      name = "GitHub",
      keys = c("token", "base_url", "organization")
    ),
    database = list(
      name = "PostgreSQL Database",
      keys = c("host", "port", "dbname", "user", "password")
    )
  )
  
  # Set up credentials for each service
  for (service_name in names(services)) {
    service_info <- services[[service_name]]
    
    cli_h2("Setting up {service_info$name}")
    
    for (key in service_info$keys) {
      keyring_key <- paste0("course_analytics_", service_name, "_", key)
      
      # Check if credential already exists
      if (keyring_key %in% key_list(service = "course_analytics")$service) {
        cli_alert_info("Credential {keyring_key} already exists")
        update <- readline(prompt = "Update? (y/n): ")
        if (tolower(update) != "y") {
          next
        }
      }
      
      # Prompt for credential
      if (key == "password" || key == "api_secret" || key == "token") {
        value <- getPass::getPass(prompt = paste0("Enter ", service_info$name, " ", key, ": "))
      } else {
        value <- readline(prompt = paste0("Enter ", service_info$name, " ", key, ": "))
      }
      
      # Store in keyring
      key_set(keyring_key, value = value, service = "course_analytics")
      cli_alert_success("Stored {keyring_key}")
    }
  }
  
  cli_alert_success("All credentials set up successfully!")
}

# Get credential from keyring
get_credential <- function(service, key) {
  keyring_key <- paste0("course_analytics_", service, "_", key)
  
  tryCatch({
    key_get(keyring_key, service = "course_analytics")
  }, error = function(e) {
    cli_alert_danger("Credential not found: {keyring_key}")
    cli_alert_info("Run setup_course_analytics_credentials() to set up credentials")
    return(NULL)
  })
}

# List all stored credentials
list_credentials <- function() {
  cli_h1("Stored Course Analytics Credentials")
  
  tryCatch({
    keys <- key_list(service = "course_analytics")
    if (nrow(keys) > 0) {
      cli_alert_info("Found {nrow(keys)} stored credentials:")
      for (i in 1:nrow(keys)) {
        cli_li(keys$service[i])
      }
    } else {
      cli_alert_warning("No credentials found in keyring")
    }
  }, error = function(e) {
    cli_alert_danger("Error accessing keyring: {e$message}")
  })
}

# Delete all credentials (for cleanup)
delete_all_credentials <- function() {
  cli_h1("Deleting Course Analytics Credentials")
  
  confirm <- readline(prompt = "Are you sure you want to delete ALL credentials? (yes/no): ")
  if (tolower(confirm) == "yes") {
    keys <- key_list(service = "course_analytics")
    for (i in 1:nrow(keys)) {
      key_delete(keys$service[i], service = "course_analytics")
      cli_alert_info("Deleted {keys$service[i]}")
    }
    cli_alert_success("All credentials deleted")
  } else {
    cli_alert_info("Operation cancelled")
  }
}

# Run setup if script is executed directly
if (interactive()) {
  cli_alert_info("Course Analytics Credentials Setup")
  cli_alert_info("Available functions:")
  cli_ul(c(
    "setup_course_analytics_credentials() - Set up all credentials",
    "get_credential(service, key) - Get a specific credential",
    "list_credentials() - List all stored credentials",
    "delete_all_credentials() - Delete all credentials"
  ))
}