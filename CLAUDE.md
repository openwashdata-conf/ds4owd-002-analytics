# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an R-based data collection pipeline for course analytics. It automatically collects data from multiple sources (surveys, Posit Cloud, Zoom, GitHub) using tidyverse principles, stores data in PostgreSQL, and runs on automated schedules via GitHub Actions.

## Core Architecture

### Data Collection Pipeline
The system follows a modular pipeline architecture:
1. **Credential Management** → keyring-based secure storage
2. **Data Collection** → Source-specific scripts with API pagination
3. **Data Processing** → Tidyverse transformations with standardized timestamps  
4. **Storage** → PostgreSQL with upsert operations
5. **Automation** → GitHub Actions with custom schedules

### Key Entry Points
- `main.R`: Primary interface with convenience functions
- `run_analytics_pipeline()`: Complete collection + storage
- `collect_only()`: Data collection without storage
- `store_only()`: Storage of existing data

### Script Organization
- **Collection scripts**: `collect_*.R` - One per data source (surveys, Posit Cloud, Zoom, GitHub)
- **Orchestration**: `orchestrate_collection.R` - Manages collection from multiple sources
- **Storage**: `store_to_postgres.R` - Database operations with upsert logic
- **Utils**: `utils.R` - API helpers, pagination, error handling

## Essential Commands

### Local Development
```bash
# Setup credentials (one-time)
source("scripts/setup_credentials.R")
setup_course_analytics_credentials()

# Setup database schema
source("scripts/setup_database.R") 
setup_database_schema()

# Run full pipeline
source("main.R")
run_analytics_pipeline()

# Collect specific sources
collect_only(c("pre_survey", "github_commits"))

# Test individual collection script
source("scripts/collect_github_commits.R")
github_commits_df <- collect_github_commits()
```

### GitHub Actions (Automated)
- **Daily (2 AM UTC)**: Posit Cloud, GitHub commits, Zoom recordings
- **Weekly (Fridays 3 AM UTC)**: Zoom sessions
- **Manual dispatch**: All collection types via workflow_dispatch

## Data Source Architecture

### Collection Schedule Design
Each data source has optimized collection frequency:
- **Continuous sources** (Posit Cloud, GitHub, Zoom recordings): Daily collection
- **Session-based** (Zoom live sessions): Weekly collection on Fridays
- **Milestone-based** (surveys): Manual collection only

### Data Frame Naming Convention
Each collection script produces a standardized data frame:
- `pre_course_survey_df`, `post_course_survey_df`
- `posit_usage_df`
- `zoom_live_sessions_df`, `zoom_recordings_df`  
- `github_commits_df`

### Database Mapping
Data frames map to PostgreSQL tables via `table_mapping` in `store_to_postgres.R`. Uses upsert operations to handle reprocessing without duplicates.

## Credential Management System

### Local Development
Uses system keyring with interactive setup via `setup_course_analytics_credentials()`. Credentials stored as `course_analytics_<service>_<key>` format.

### CI/CD Environment  
Uses `setup_credentials_ci.R` to map GitHub secrets to keyring. Environment variables follow pattern `<SERVICE>_<KEY>` (e.g., `ZOOM_API_KEY`).

### Service Requirements
- **Enketo/Kobo**: username, password, base_url, form_ids
- **Posit Cloud**: api_key, base_url, workspace_id
- **Zoom**: api_key, api_secret, base_url, account_id
- **GitHub**: token, base_url, organization
- **Database**: host, port, dbname, user, password

## API Integration Patterns

### Request Handling
- Uses `httr2` with `req_auth_basic()` for Basic Auth (surveys)
- Bearer token auth for other APIs
- Comprehensive error handling with `safe_api_request()` functions

### Pagination Strategy
- `paginate_api_requests()` handles different pagination patterns
- Configurable page parameters and limits
- Automatic detection of pagination end

### Data Processing Flow
1. **API Response** → Raw JSON from API calls
2. **Normalization** → `map_dfr()` to flatten nested structures  
3. **Standardization** → `case_when()` for consistent column mapping
4. **Validation** → `clean_dataframe()` for required fields
5. **Timestamps** → `standardize_timestamps()` converts to UTC

## Database Architecture

### Schema Design
Each data source has a dedicated table with:
- Primary key (auto-increment)
- Source-specific identifier columns  
- Timestamp columns (properly typed)
- JSONB for flexible data (surveys)
- Created_at audit trail

### Storage Operations
- **Upsert mode**: Prevents duplicates during reprocessing
- **Identifier-based**: Uses source-specific IDs for conflict resolution
- **Transaction handling**: Proper rollback on failures

## GitHub Actions Integration

### Workflow Structure
- **Service container**: PostgreSQL 13 for testing
- **Environment setup**: R 4.1.0+ with dependencies
- **Credential mapping**: GitHub secrets → environment variables → keyring
- **Collection logic**: Dynamic source selection based on trigger type

### Manual Triggers
Supports `workflow_dispatch` with collection type options:
- `daily`: Posit Cloud, GitHub, Zoom recordings
- `weekly`: Zoom sessions
- `manual_surveys`: Pre/post surveys  
- `full`: All sources

## Modern R Patterns Used

### Native Pipes
Uses `|>` throughout instead of `%>%` (requires R >= 4.1.0)

### Tidyverse Integration
- `dplyr` for data manipulation
- `purrr` for functional programming patterns
- `lubridate` for timestamp handling
- `cli` for progress tracking and user feedback

### Error Handling
- `tryCatch()` blocks with detailed logging
- `rlang` for better error messages
- `cli_alert_*()` for user-friendly output

## Configuration Management

### Development vs Production
- **Local**: Uses `config.yml` as reference, keyring for actual credentials
- **CI/CD**: Environment variables only, no config files
- **Security**: No credentials ever committed to repository

### Flexible Collection
The `orchestrate_collection.R` supports partial collection via `sources` parameter, enabling targeted data collection for debugging or specific analysis needs.