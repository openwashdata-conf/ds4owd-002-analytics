source("scripts/utils.R")
source("scripts/setup_database.R")

library(DBI)
library(RPostgres)
library(dplyr)
library(purrr)
library(dbplyr)
library(lubridate)
library(cli)
library(keyring)

# Database table mapping
table_mapping <- list(
  "pre_course_survey_df" = "pre_course_survey",
  "post_course_survey_df" = "post_course_survey", 
  "posit_usage_df" = "posit_cloud_usage",
  "zoom_live_sessions_df" = "zoom_live_sessions",
  "zoom_recordings_df" = "zoom_recordings",
  "github_commits_df" = "github_commits"
)

# Store data frame to PostgreSQL table
store_dataframe_to_db <- function(df, table_name, connection, method = "append") {
  if (nrow(df) == 0) {
    cli_alert_warning("Skipping empty data frame for table {table_name}")
    return(list(status = "skipped", records = 0))
  }
  
  tryCatch({
    # Check if table exists
    table_exists <- DBI::dbExistsTable(connection, table_name)
    
    if (!table_exists) {
      cli_alert_danger("Table {table_name} does not exist. Run setup_database.R first.")
      return(list(status = "error", records = 0, message = "Table does not exist"))
    }
    
    # Store data using appropriate method
    if (method == "replace") {
      # Replace all existing data
      DBI::dbWriteTable(connection, table_name, df, overwrite = TRUE)
      cli_alert_info("Replaced all data in {table_name}")
    } else if (method == "append") {
      # Append new data
      DBI::dbAppendTable(connection, table_name, df)
      cli_alert_success("Appended {nrow(df)} records to {table_name}")
    } else if (method == "upsert") {
      # Upsert (insert or update) - more complex logic
      upsert_result <- upsert_data_to_table(df, table_name, connection)
      return(upsert_result)
    }
    
    return(list(status = "success", records = nrow(df)))
    
  }, error = function(e) {
    cli_alert_danger("Error storing data to {table_name}: {e$message}")
    return(list(status = "error", records = 0, message = e$message))
  })
}

# Upsert function (insert or update)
upsert_data_to_table <- function(df, table_name, connection) {
  # This is a simplified upsert - in production, you'd want more sophisticated logic
  # based on primary keys or unique constraints
  
  tryCatch({
    # For demonstration, we'll use a simple approach:
    # Delete existing records with same identifiers and insert new ones
    
    if (table_name == "pre_course_survey" || table_name == "post_course_survey") {
      # Use participant_id as identifier
      existing_ids <- df$participant_id
      if (length(existing_ids) > 0) {
        delete_query <- glue::glue_sql(
          "DELETE FROM {`table_name`} WHERE participant_id IN ({existing_ids*})",
          .con = connection
        )
        DBI::dbExecute(connection, delete_query)
      }
    } else if (table_name == "posit_cloud_usage") {
      # Use session_id as identifier
      existing_ids <- df$session_id
      if (length(existing_ids) > 0) {
        delete_query <- glue::glue_sql(
          "DELETE FROM {`table_name`} WHERE session_id IN ({existing_ids*})",
          .con = connection
        )
        DBI::dbExecute(connection, delete_query)
      }
    } else if (table_name == "github_commits") {
      # Use commit_sha as identifier
      existing_ids <- df$commit_sha
      if (length(existing_ids) > 0) {
        delete_query <- glue::glue_sql(
          "DELETE FROM {`table_name`} WHERE commit_sha IN ({existing_ids*})",
          .con = connection
        )
        DBI::dbExecute(connection, delete_query)
      }
    }
    
    # Insert new/updated records
    DBI::dbAppendTable(connection, table_name, df)
    
    cli_alert_success("Upserted {nrow(df)} records to {table_name}")
    return(list(status = "success", records = nrow(df)))
    
  }, error = function(e) {
    cli_alert_danger("Error upserting data to {table_name}: {e$message}")
    return(list(status = "error", records = 0, message = e$message))
  })
}

# Main storage function
store_all_data_to_postgres <- function(data_list, storage_method = "append") {
  cli_h1("Storing Course Analytics Data to PostgreSQL")
  
  # Connect to database
  con <- tryCatch({
    connect_to_db()
  }, error = function(e) {
    cli_alert_danger("Failed to connect to database: {e$message}")
    return(NULL)
  })
  
  if (is.null(con)) {
    cli_alert_danger("Cannot proceed without database connection")
    return(NULL)
  }
  
  # Ensure database schema exists
  tryCatch({
    setup_database_schema()
  }, error = function(e) {
    cli_alert_warning("Could not set up database schema: {e$message}")
  })
  
  # Storage results
  storage_results <- tibble(
    data_frame = character(),
    table_name = character(),
    status = character(),
    records_stored = integer(),
    duration_seconds = numeric(),
    error_message = character()
  )
  
  # Store each data frame
  for (df_name in names(data_list)) {
    if (df_name %in% names(table_mapping)) {
      table_name <- table_mapping[[df_name]]
      df <- data_list[[df_name]]
      
      cli_h2("Storing {df_name} → {table_name}")
      
      start_time <- Sys.time()
      
      # Store data
      result <- store_dataframe_to_db(df, table_name, con, method = storage_method)
      
      end_time <- Sys.time()
      duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
      
      # Record result
      storage_results <- storage_results %>%
        add_row(
          data_frame = df_name,
          table_name = table_name,
          status = result$status,
          records_stored = result$records,
          duration_seconds = duration,
          error_message = result$message %||% ""
        )
      
      if (result$status == "success") {
        cli_alert_success("✅ {df_name}: {result$records} records stored in {round(duration, 2)}s")
      } else {
        cli_alert_danger("❌ {df_name}: {result$status}")
      }
    } else {
      cli_alert_warning("Unknown data frame: {df_name}")
    }
  }
  
  # Close database connection
  DBI::dbDisconnect(con)
  
  # Summary report
  cli_h2("Storage Summary")
  
  successful_stores <- storage_results %>% filter(status == "success")
  failed_stores <- storage_results %>% filter(status == "error")
  
  cli_alert_info("Total tables attempted: {nrow(storage_results)}")
  cli_alert_success("Successful stores: {nrow(successful_stores)}")
  cli_alert_danger("Failed stores: {nrow(failed_stores)}")
  
  if (nrow(successful_stores) > 0) {
    total_records <- sum(successful_stores$records_stored)
    cli_alert_info("Total records stored: {total_records}")
  }
  
  # Print detailed summary
  storage_results %>%
    mutate(
      duration_formatted = paste0(round(duration_seconds, 2), "s"),
      records_formatted = ifelse(status == "success", 
                                 paste0(records_stored, " records"), 
                                 status)
    ) %>%
    select(data_frame, table_name, status, records_formatted, duration_formatted) %>%
    print()
  
  # Save storage metadata
  readr::write_csv(storage_results, "data/storage_summary.csv")
  cli_alert_info("Storage summary saved to data/storage_summary.csv")
  
  return(storage_results)
}

# Convenience function to collect and store data in one step
collect_and_store_all_data <- function(sources = "all", storage_method = "append") {
  cli_h1("Full Data Collection and Storage Pipeline")
  
  # Source orchestration script
  source("scripts/orchestrate_collection.R")
  
  # Collect data
  cli_alert_info("Step 1: Collecting data from all sources...")
  collection_results <- orchestrate_data_collection(sources = sources, save_files = TRUE)
  
  # Store data
  cli_alert_info("Step 2: Storing data to PostgreSQL...")
  storage_results <- store_all_data_to_postgres(collection_results$data, storage_method)
  
  cli_rule()
  cli_alert_success("Full pipeline completed!")
  cli_rule()
  
  return(list(
    collection = collection_results,
    storage = storage_results
  ))
}

# Run storage if script is executed directly
if (interactive()) {
  # Example usage - you would typically have data from orchestration
  cli_alert_info("To use this script, first run orchestrate_collection.R to get data")
  cli_alert_info("Then call: store_all_data_to_postgres(collection_results$data)")
  cli_alert_info("Or run: collect_and_store_all_data() for full pipeline")
}