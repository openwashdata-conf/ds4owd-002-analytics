# Course Analytics Data Collection Pipeline

A comprehensive R-based system for collecting and storing data from various sources associated with an online data science course.

## Overview

This project provides automated data collection from:
- **Enketo/Kobo Toolbox** surveys (pre and post course)
- **Posit Cloud** workspace usage analytics
- **Zoom** live sessions and recordings
- **GitHub** commits from course organization

All data is processed using tidyverse principles and stored in PostgreSQL.

## Project Structure

```
ds4owd-002-analytics/
├── main.R                          # Main entry point
├── config/
│   └── config.yml                  # API credentials and settings
├── scripts/
│   ├── utils.R                     # Utility functions
│   ├── setup_database.R            # Database schema setup
│   ├── collect_pre_survey.R        # Pre-course survey collection
│   ├── collect_post_survey.R       # Post-course survey collection
│   ├── collect_posit_cloud.R       # Posit Cloud usage collection
│   ├── collect_zoom_sessions.R     # Zoom sessions collection
│   ├── collect_zoom_recordings.R   # Zoom recordings collection
│   ├── collect_github_commits.R    # GitHub commits collection
│   ├── orchestrate_collection.R    # Data collection orchestration
│   └── store_to_postgres.R         # Database storage
└── data/                           # CSV backups and summaries
```

## Quick Start

### 1. Setup

```r
# Install required packages
install.packages(c("dplyr", "httr2", "purrr", "readr", "lubridate", 
                   "rlang", "cli", "config", "DBI", "RPostgres", 
                   "dbplyr", "jsonlite", "glue", "base64enc"))

# Load main script
source("main.R")
```

### 2. Configure Credentials

Edit `config/config.yml` with your API credentials:

```yaml
default:
  enketo:
    username: "your_username"
    password: "your_password"
  posit_cloud:
    api_key: "your_api_key"
  zoom:
    api_key: "your_api_key"
  github:
    token: "your_token"
  database:
    host: "localhost"
    user: "your_db_user"
    password: "your_db_password"
```

### 3. Setup Database

```r
# Create PostgreSQL tables
setup_database_only()
```

### 4. Run Pipeline

```r
# Complete pipeline (collect + store)
results <- run_analytics_pipeline()

# Or collect data only
data <- collect_only()

# Or store existing data
store_only(data$data)
```

## Data Frames Created

Each collection script creates a meaningfully named data frame:

- `pre_course_survey_df` - Pre-course survey responses
- `post_course_survey_df` - Post-course survey responses  
- `posit_usage_df` - Posit Cloud usage sessions
- `zoom_live_sessions_df` - Zoom live session attendance
- `zoom_recordings_df` - Zoom recording view statistics
- `github_commits_df` - GitHub commit activity

## Database Schema

Data is stored in PostgreSQL with tables:
- `pre_course_survey`
- `post_course_survey`
- `posit_cloud_usage`
- `zoom_live_sessions`
- `zoom_recordings`
- `github_commits`

## Features

- **Tidyverse-based**: All data processing uses dplyr, purrr, etc.
- **Error handling**: Comprehensive error catching and logging
- **API pagination**: Handles paginated API responses
- **Data validation**: Standardized timestamps and required fields
- **CSV backups**: All data saved as CSV files
- **Flexible collection**: Can collect from specific sources only
- **Progress tracking**: Real-time progress with cli package

## Usage Examples

```r
# Collect only survey data
survey_results <- collect_only(c("pre_survey", "post_survey"))

# Run with different storage method
results <- run_analytics_pipeline(storage_method = "replace")

# Access individual data frames
results$collection$data$pre_course_survey_df
results$collection$data$github_commits_df
```

## Requirements

- R >= 4.0.0
- PostgreSQL database
- API access to all services
- Network connectivity for API calls

## License

MIT License