library(DBI)
library(RPostgres)
library(dplyr)
library(keyring)

# Source credentials setup
source("scripts/setup_credentials.R")

# Database connection function using keyring
connect_to_db <- function() {
  # Get credentials from keyring
  host <- get_credential("database", "host")
  port <- as.integer(get_credential("database", "port"))
  dbname <- get_credential("database", "dbname")
  user <- get_credential("database", "user")
  password <- get_credential("database", "password")
  
  # Check if all credentials are available
  if (is.null(host) || is.null(port) || is.null(dbname) || is.null(user) || is.null(password)) {
    cli_alert_danger("Database credentials not found in keyring")
    cli_alert_info("Run setup_course_analytics_credentials() to set them up")
    return(NULL)
  }
  
  DBI::dbConnect(
    RPostgres::Postgres(),
    host = host,
    port = port,
    dbname = dbname,
    user = user,
    password = password
  )
}

# Create database tables
setup_database_schema <- function() {
  con <- connect_to_db()
  
  # Pre-course survey table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS pre_course_survey (
      id SERIAL PRIMARY KEY,
      participant_id VARCHAR(255),
      submission_date TIMESTAMP,
      response_data JSONB,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")
  
  # Post-course survey table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS post_course_survey (
      id SERIAL PRIMARY KEY,
      participant_id VARCHAR(255),
      submission_date TIMESTAMP,
      response_data JSONB,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")
  
  # Posit Cloud usage table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS posit_cloud_usage (
      id SERIAL PRIMARY KEY,
      user_id VARCHAR(255),
      session_id VARCHAR(255),
      start_time TIMESTAMP,
      end_time TIMESTAMP,
      duration_minutes INTEGER,
      project_name VARCHAR(255),
      cpu_usage DECIMAL,
      memory_usage DECIMAL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")
  
  # Zoom live sessions table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS zoom_live_sessions (
      id SERIAL PRIMARY KEY,
      meeting_id VARCHAR(255),
      participant_id VARCHAR(255),
      participant_name VARCHAR(255),
      join_time TIMESTAMP,
      leave_time TIMESTAMP,
      duration_minutes INTEGER,
      meeting_topic VARCHAR(255),
      meeting_date DATE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")
  
  # Zoom recordings table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS zoom_recordings (
      id SERIAL PRIMARY KEY,
      recording_id VARCHAR(255),
      meeting_id VARCHAR(255),
      viewer_id VARCHAR(255),
      viewer_name VARCHAR(255),
      view_start_time TIMESTAMP,
      view_duration_minutes INTEGER,
      recording_topic VARCHAR(255),
      recording_date DATE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")
  
  # GitHub commits table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS github_commits (
      id SERIAL PRIMARY KEY,
      commit_sha VARCHAR(255),
      repository_name VARCHAR(255),
      author_username VARCHAR(255),
      author_email VARCHAR(255),
      commit_message TEXT,
      commit_date TIMESTAMP,
      additions INTEGER,
      deletions INTEGER,
      changed_files INTEGER,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")
  
  DBI::dbDisconnect(con)
  message("Database schema created successfully!")
}

# Run schema setup
if (interactive()) {
  setup_database_schema()
}