# GitHub Actions Setup Guide

This guide explains how to set up automated data collection using GitHub Actions.

## Overview

The GitHub Actions workflow automatically collects data from various sources on the following schedule:

- **Daily (2 AM UTC)**: Posit Cloud, GitHub commits, Zoom recordings
- **Weekly (Fridays 3 AM UTC)**: Zoom sessions  
- **Manual**: Surveys (triggered manually when needed)

## Prerequisites

1. **GitHub Repository**: This code must be in a GitHub repository
2. **Database**: PostgreSQL database accessible from GitHub Actions
3. **API Access**: Valid credentials for all services

## GitHub Secrets Setup

You need to configure the following secrets in your GitHub repository:

### 1. Go to Repository Settings

1. Navigate to your repository on GitHub
2. Go to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**

### 2. Add Required Secrets

Add each of the following secrets:

#### Enketo/Kobo Toolbox
```
ENKETO_USERNAME=your_enketo_username
ENKETO_PASSWORD=your_enketo_password
ENKETO_BASE_URL=https://kc.kobotoolbox.org/api/v1
ENKETO_PRE_SURVEY_FORM_ID=your_pre_survey_form_id
ENKETO_POST_SURVEY_FORM_ID=your_post_survey_form_id
```

#### Posit Cloud
```
POSIT_CLOUD_API_KEY=your_posit_cloud_api_key
POSIT_CLOUD_BASE_URL=https://api.rstudiocloud.com/v1
POSIT_CLOUD_WORKSPACE_ID=your_workspace_id
```

#### Zoom
```
ZOOM_API_KEY=your_zoom_api_key
ZOOM_API_SECRET=your_zoom_api_secret
ZOOM_BASE_URL=https://api.zoom.us/v2
ZOOM_ACCOUNT_ID=your_zoom_account_id
```

#### GitHub
```
GITHUB_TOKEN=your_github_token
GITHUB_BASE_URL=https://api.github.com
GITHUB_ORGANIZATION=your_github_organization
```

#### Database (if using external database)
```
DATABASE_HOST=your_database_host
DATABASE_PORT=5432
DATABASE_DBNAME=course_analytics
DATABASE_USER=your_database_user
DATABASE_PASSWORD=your_database_password
```

**Note**: The workflow includes a PostgreSQL service container, so database secrets are optional if you want to use the built-in database.

## Workflow Configuration

### Schedule Configuration

The workflow is configured with these schedules:

```yaml
schedule:
  # Daily at 2 AM UTC
  - cron: '0 2 * * *'
  # Weekly on Fridays at 3 AM UTC  
  - cron: '0 3 * * 5'
```

### Manual Execution

You can manually trigger the workflow:

1. Go to **Actions** tab in your repository
2. Click on **Course Analytics Data Collection**
3. Click **Run workflow**
4. Select collection type:
   - `daily`: Posit Cloud, GitHub, Zoom recordings
   - `weekly`: Zoom sessions
   - `manual_surveys`: Pre/post surveys
   - `full`: All sources

## Data Storage

### Database
- Uses PostgreSQL (either service container or external)
- Automatically creates required tables
- Uses upsert mode to avoid duplicates

### Artifacts
- CSV files are uploaded as GitHub artifacts
- Retained for 30 days
- Includes collection and storage summaries

## Monitoring

### Workflow Status
- Check **Actions** tab for workflow runs
- View logs for detailed execution information
- Receive notifications on failures

### Data Verification
- Download artifacts to verify collected data
- Check database for stored records
- Review summary CSV files

## Troubleshooting

### Common Issues

1. **Missing Secrets**: Ensure all required secrets are configured
2. **API Rate Limits**: Workflows might need retry logic for rate-limited APIs
3. **Database Connection**: Verify database credentials and network access
4. **Authentication**: Check API tokens and permissions

### Debug Steps

1. Check workflow logs in Actions tab
2. Verify secret names match exactly
3. Test API endpoints manually
4. Check database connectivity

### Manual Testing

Run the workflow manually to test:

```bash
# In repository root
source("scripts/setup_credentials_ci.R")
source("main.R")
run_analytics_pipeline()
```

## Security Considerations

- **Secrets**: Never commit API keys or passwords to the repository
- **Permissions**: Use minimal required permissions for API tokens
- **Access**: Limit repository access to authorized users
- **Rotation**: Regularly rotate API keys and credentials

## Scaling Considerations

- **Rate Limits**: Add delays between API calls if needed
- **Data Volume**: Monitor storage costs for large datasets
- **Concurrency**: Adjust workflow concurrency if needed
- **Resources**: Increase GitHub Actions limits if required

## Support

If you encounter issues:

1. Check workflow logs for error messages
2. Verify all secrets are correctly configured
3. Test API endpoints manually
4. Review database connection settings