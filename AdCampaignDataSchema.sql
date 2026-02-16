/****** Object:  Database [AdCampaignData]    Script Date: 2/16/2026 1:27:08 PM ******/
CREATE DATABASE [AdCampaignData]  (EDITION = 'GeneralPurpose', SERVICE_OBJECTIVE = 'GP_S_Gen5_1', MAXSIZE = 32 GB) WITH CATALOG_COLLATION = SQL_Latin1_General_CP1_CI_AS, LEDGER = OFF;
GO

ALTER DATABASE [AdCampaignData] SET ANSI_NULL_DEFAULT OFF 
GO

ALTER DATABASE [AdCampaignData] SET ANSI_NULLS OFF 
GO

ALTER DATABASE [AdCampaignData] SET ANSI_PADDING OFF 
GO

ALTER DATABASE [AdCampaignData] SET ANSI_WARNINGS OFF 
GO

ALTER DATABASE [AdCampaignData] SET ARITHABORT OFF 
GO

ALTER DATABASE [AdCampaignData] SET AUTO_SHRINK OFF 
GO

ALTER DATABASE [AdCampaignData] SET AUTO_UPDATE_STATISTICS ON 
GO

ALTER DATABASE [AdCampaignData] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO

ALTER DATABASE [AdCampaignData] SET CONCAT_NULL_YIELDS_NULL OFF 
GO

ALTER DATABASE [AdCampaignData] SET NUMERIC_ROUNDABORT OFF 
GO

ALTER DATABASE [AdCampaignData] SET QUOTED_IDENTIFIER OFF 
GO

ALTER DATABASE [AdCampaignData] SET RECURSIVE_TRIGGERS OFF 
GO

ALTER DATABASE [AdCampaignData] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO

ALTER DATABASE [AdCampaignData] SET ALLOW_SNAPSHOT_ISOLATION ON 
GO

ALTER DATABASE [AdCampaignData] SET PARAMETERIZATION SIMPLE 
GO

ALTER DATABASE [AdCampaignData] SET READ_COMMITTED_SNAPSHOT ON 
GO

ALTER DATABASE [AdCampaignData] SET  MULTI_USER 
GO

ALTER DATABASE [AdCampaignData] SET ENCRYPTION ON
GO

ALTER DATABASE [AdCampaignData] SET QUERY_STORE = ON
GO

ALTER DATABASE [AdCampaignData] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 100, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO

/*** The scripts of database scoped configurations in Azure should be executed inside the target database connection. ***/
GO

-- ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 8;
GO

ALTER DATABASE [AdCampaignData] SET  READ_WRITE 
GO

/*
================================================================================
Schema: google_ads
Description: Schema for Google Ads data synced via Fivetran connector.
             Contains stats tables (daily metrics) and history tables (entity attributes).
================================================================================
*/

USE [AdCampaignData]
GO

-- Create google_ads schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'google_ads')
BEGIN
    EXEC('CREATE SCHEMA google_ads')
END
GO

/*
================================================================================
TABLE: google_ads.account_history
DESCRIPTION: Account metadata and attributes with change history.
             Use ROW_NUMBER() to get latest record per account_id.
================================================================================
*/

CREATE TABLE [google_ads].[account_history] (
    [account_id] BIGINT NOT NULL,
    [descriptive_name] NVARCHAR(255) NULL,
    [currency_code] NVARCHAR(10) NULL,
    [time_zone] NVARCHAR(100) NULL,
    [auto_tagging_enabled] BIT NULL,
    [manager] BIT NULL,
    [test_account] BIT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_account_history] PRIMARY KEY CLUSTERED ([account_id], [_fivetran_synced])
);
GO

CREATE INDEX [IX_account_history_account_id] ON [google_ads].[account_history] ([account_id], [_fivetran_synced] DESC);
GO

/*
================================================================================
TABLE: google_ads.account_stats
DESCRIPTION: Daily account-level performance metrics.
================================================================================
*/

CREATE TABLE [google_ads].[account_stats] (
    [account_id] BIGINT NOT NULL,
    [date] DATE NOT NULL,
    [spend] DECIMAL(18, 6) NULL,
    [impressions] BIGINT NULL,
    [clicks] BIGINT NULL,
    [conversions] DECIMAL(18, 6) NULL,
    [conversions_value] DECIMAL(18, 6) NULL,
    [view_through_conversions] DECIMAL(18, 6) NULL,
    [interactions] BIGINT NULL,
    [interaction_event_types] NVARCHAR(MAX) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_account_stats] PRIMARY KEY CLUSTERED ([account_id], [date])
);
GO

CREATE INDEX [IX_account_stats_date] ON [google_ads].[account_stats] ([date], [account_id]);
GO

/*
================================================================================
TABLE: google_ads.campaign_history
DESCRIPTION: Campaign metadata and attributes with change history.
             Use ROW_NUMBER() to get latest record per campaign_id.
================================================================================
*/

CREATE TABLE [google_ads].[campaign_history] (
    [campaign_id] BIGINT NOT NULL,
    [account_id] BIGINT NOT NULL,
    [name] NVARCHAR(255) NULL,
    [status] NVARCHAR(50) NULL,
    [advertising_channel_type] NVARCHAR(100) NULL,
    [advertising_channel_sub_type] NVARCHAR(100) NULL,
    [bidding_strategy_type] NVARCHAR(100) NULL,
    [start_date] DATE NULL,
    [end_date] DATE NULL,
    [budget_amount] DECIMAL(18, 6) NULL,
    [budget_period] NVARCHAR(50) NULL,
    [serving_status] NVARCHAR(50) NULL,
    [ad_serving_optimization_status] NVARCHAR(50) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_campaign_history] PRIMARY KEY CLUSTERED ([campaign_id], [_fivetran_synced])
);
GO

CREATE INDEX [IX_campaign_history_campaign_id] ON [google_ads].[campaign_history] ([campaign_id], [_fivetran_synced] DESC);
CREATE INDEX [IX_campaign_history_account_id] ON [google_ads].[campaign_history] ([account_id]);
GO

/*
================================================================================
TABLE: google_ads.campaign_stats
DESCRIPTION: Daily campaign-level performance metrics.
================================================================================
*/

CREATE TABLE [google_ads].[campaign_stats] (
    [campaign_id] BIGINT NOT NULL,
    [account_id] BIGINT NOT NULL,
    [date] DATE NOT NULL,
    [spend] DECIMAL(18, 6) NULL,
    [impressions] BIGINT NULL,
    [clicks] BIGINT NULL,
    [conversions] DECIMAL(18, 6) NULL,
    [conversions_value] DECIMAL(18, 6) NULL,
    [view_through_conversions] DECIMAL(18, 6) NULL,
    [video_views] BIGINT NULL,
    [video_quartile_p25_rate] DECIMAL(10, 6) NULL,
    [video_quartile_p50_rate] DECIMAL(10, 6) NULL,
    [video_quartile_p75_rate] DECIMAL(10, 6) NULL,
    [video_quartile_p100_rate] DECIMAL(10, 6) NULL,
    [interactions] BIGINT NULL,
    [interaction_event_types] NVARCHAR(MAX) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_campaign_stats] PRIMARY KEY CLUSTERED ([campaign_id], [date])
);
GO

CREATE INDEX [IX_campaign_stats_date] ON [google_ads].[campaign_stats] ([date], [campaign_id]);
CREATE INDEX [IX_campaign_stats_account_id] ON [google_ads].[campaign_stats] ([account_id], [date]);
GO

/*
================================================================================
TABLE: google_ads.ad_group_history
DESCRIPTION: Ad group metadata and attributes with change history.
             Use ROW_NUMBER() to get latest record per ad_group_id.
================================================================================
*/

CREATE TABLE [google_ads].[ad_group_history] (
    [ad_group_id] BIGINT NOT NULL,
    [campaign_id] BIGINT NOT NULL,
    [name] NVARCHAR(255) NULL,
    [status] NVARCHAR(50) NULL,
    [type] NVARCHAR(100) NULL,
    [cpc_bid_micros] BIGINT NULL,
    [cpm_bid_micros] BIGINT NULL,
    [target_cpa_micros] BIGINT NULL,
    [effective_target_cpa_micros] BIGINT NULL,
    [effective_target_roas] DECIMAL(10, 6) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_ad_group_history] PRIMARY KEY CLUSTERED ([ad_group_id], [_fivetran_synced])
);
GO

CREATE INDEX [IX_ad_group_history_ad_group_id] ON [google_ads].[ad_group_history] ([ad_group_id], [_fivetran_synced] DESC);
CREATE INDEX [IX_ad_group_history_campaign_id] ON [google_ads].[ad_group_history] ([campaign_id]);
GO

/*
================================================================================
TABLE: google_ads.ad_group_stats
DESCRIPTION: Daily ad group-level performance metrics.
================================================================================
*/

CREATE TABLE [google_ads].[ad_group_stats] (
    [ad_group_id] BIGINT NOT NULL,
    [campaign_id] BIGINT NOT NULL,
    [account_id] BIGINT NOT NULL,
    [date] DATE NOT NULL,
    [spend] DECIMAL(18, 6) NULL,
    [impressions] BIGINT NULL,
    [clicks] BIGINT NULL,
    [conversions] DECIMAL(18, 6) NULL,
    [conversions_value] DECIMAL(18, 6) NULL,
    [view_through_conversions] DECIMAL(18, 6) NULL,
    [interactions] BIGINT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_ad_group_stats] PRIMARY KEY CLUSTERED ([ad_group_id], [date])
);
GO

CREATE INDEX [IX_ad_group_stats_date] ON [google_ads].[ad_group_stats] ([date], [ad_group_id]);
CREATE INDEX [IX_ad_group_stats_campaign_id] ON [google_ads].[ad_group_stats] ([campaign_id], [date]);
CREATE INDEX [IX_ad_group_stats_account_id] ON [google_ads].[ad_group_stats] ([account_id], [date]);
GO

/*
================================================================================
TABLE: google_ads.ad_history
DESCRIPTION: Ad metadata and attributes with change history.
             Use ROW_NUMBER() to get latest record per ad_id.
================================================================================
*/

CREATE TABLE [google_ads].[ad_history] (
    [ad_id] BIGINT NOT NULL,
    [ad_group_id] BIGINT NOT NULL,
    [type] NVARCHAR(100) NULL,
    [status] NVARCHAR(50) NULL,
    [device_preference] NVARCHAR(50) NULL,
    [ad_strength] NVARCHAR(50) NULL,
    [display_url] NVARCHAR(2048) NULL,
    [final_urls] NVARCHAR(MAX) NULL,
    [final_mobile_urls] NVARCHAR(MAX) NULL,
    -- Responsive Search Ad fields
    [responsive_search_ad_headlines] NVARCHAR(MAX) NULL,
    [responsive_search_ad_descriptions] NVARCHAR(MAX) NULL,
    [responsive_search_ad_path1] NVARCHAR(255) NULL,
    [responsive_search_ad_path2] NVARCHAR(255) NULL,
    -- Expanded Text Ad fields (legacy)
    [expanded_text_ad_headline_part1] NVARCHAR(255) NULL,
    [expanded_text_ad_headline_part2] NVARCHAR(255) NULL,
    [expanded_text_ad_headline_part3] NVARCHAR(255) NULL,
    [expanded_text_ad_description] NVARCHAR(500) NULL,
    [expanded_text_ad_description2] NVARCHAR(500) NULL,
    [expanded_text_ad_path1] NVARCHAR(255) NULL,
    [expanded_text_ad_path2] NVARCHAR(255) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_ad_history] PRIMARY KEY CLUSTERED ([ad_id], [_fivetran_synced])
);
GO

CREATE INDEX [IX_ad_history_ad_id] ON [google_ads].[ad_history] ([ad_id], [_fivetran_synced] DESC);
CREATE INDEX [IX_ad_history_ad_group_id] ON [google_ads].[ad_history] ([ad_group_id]);
GO

/*
================================================================================
TABLE: google_ads.ad_stats
DESCRIPTION: Daily ad-level performance metrics.
================================================================================
*/

CREATE TABLE [google_ads].[ad_stats] (
    [ad_id] BIGINT NOT NULL,
    [ad_group_id] BIGINT NOT NULL,
    [campaign_id] BIGINT NOT NULL,
    [account_id] BIGINT NOT NULL,
    [date] DATE NOT NULL,
    [spend] DECIMAL(18, 6) NULL,
    [impressions] BIGINT NULL,
    [clicks] BIGINT NULL,
    [conversions] DECIMAL(18, 6) NULL,
    [conversions_value] DECIMAL(18, 6) NULL,
    [interactions] BIGINT NULL,
    [video_views] BIGINT NULL,
    [video_quartile_p100_rate] DECIMAL(10, 6) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_ad_stats] PRIMARY KEY CLUSTERED ([ad_id], [date])
);
GO

CREATE INDEX [IX_ad_stats_date] ON [google_ads].[ad_stats] ([date], [ad_id]);
CREATE INDEX [IX_ad_stats_ad_group_id] ON [google_ads].[ad_stats] ([ad_group_id], [date]);
CREATE INDEX [IX_ad_stats_campaign_id] ON [google_ads].[ad_stats] ([campaign_id], [date]);
CREATE INDEX [IX_ad_stats_account_id] ON [google_ads].[ad_stats] ([account_id], [date]);
GO

/*
================================================================================
TABLE: google_ads.ad_group_criterion_history
DESCRIPTION: Keyword and other targeting criteria metadata with change history.
             Filter by type = 'KEYWORD' for keyword-specific data.
             Use ROW_NUMBER() to get latest record per criterion_id.
================================================================================
*/

CREATE TABLE [google_ads].[ad_group_criterion_history] (
    [criterion_id] BIGINT NOT NULL,
    [ad_group_id] BIGINT NOT NULL,
    [type] NVARCHAR(50) NULL,
    [status] NVARCHAR(50) NULL,
    [keyword_text] NVARCHAR(500) NULL,
    [keyword_match_type] NVARCHAR(50) NULL,
    [system_serving_status] NVARCHAR(50) NULL,
    [approval_status] NVARCHAR(50) NULL,
    [quality_score] INT NULL,
    [creative_quality_score] NVARCHAR(50) NULL,
    [post_click_quality_score] NVARCHAR(50) NULL,
    [search_predicted_ctr] NVARCHAR(50) NULL,
    [cpc_bid_micros] BIGINT NULL,
    [effective_cpc_bid_micros] BIGINT NULL,
    [final_url_suffix] NVARCHAR(1024) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_ad_group_criterion_history] PRIMARY KEY CLUSTERED ([criterion_id], [_fivetran_synced])
);
GO

CREATE INDEX [IX_ad_group_criterion_history_criterion_id] ON [google_ads].[ad_group_criterion_history] ([criterion_id], [_fivetran_synced] DESC);
CREATE INDEX [IX_ad_group_criterion_history_ad_group_id] ON [google_ads].[ad_group_criterion_history] ([ad_group_id]);
CREATE INDEX [IX_ad_group_criterion_history_type] ON [google_ads].[ad_group_criterion_history] ([type]);
GO

/*
================================================================================
TABLE: google_ads.keyword_stats
DESCRIPTION: Daily keyword-level performance metrics.
================================================================================
*/

CREATE TABLE [google_ads].[keyword_stats] (
    [criterion_id] BIGINT NOT NULL,
    [ad_group_id] BIGINT NOT NULL,
    [campaign_id] BIGINT NOT NULL,
    [account_id] BIGINT NOT NULL,
    [date] DATE NOT NULL,
    [spend] DECIMAL(18, 6) NULL,
    [impressions] BIGINT NULL,
    [clicks] BIGINT NULL,
    [conversions] DECIMAL(18, 6) NULL,
    [conversions_value] DECIMAL(18, 6) NULL,
    [search_impression_share] DECIMAL(10, 6) NULL,
    [search_top_impression_share] DECIMAL(10, 6) NULL,
    [search_absolute_top_impression_share] DECIMAL(10, 6) NULL,
    [search_rank_lost_impression_share] DECIMAL(10, 6) NULL,
    [search_budget_lost_impression_share] DECIMAL(10, 6) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_keyword_stats] PRIMARY KEY CLUSTERED ([criterion_id], [date])
);
GO

CREATE INDEX [IX_keyword_stats_date] ON [google_ads].[keyword_stats] ([date], [criterion_id]);
CREATE INDEX [IX_keyword_stats_ad_group_id] ON [google_ads].[keyword_stats] ([ad_group_id], [date]);
CREATE INDEX [IX_keyword_stats_campaign_id] ON [google_ads].[keyword_stats] ([campaign_id], [date]);
CREATE INDEX [IX_keyword_stats_account_id] ON [google_ads].[keyword_stats] ([account_id], [date]);
GO

/*
================================================================================
Schema: hubspot
Description: Schema for HubSpot CRM data synced via Fivetran connector.
             Contains contacts, companies, deals, email events, and engagements.
================================================================================
*/

-- Create hubspot schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'hubspot')
BEGIN
    EXEC('CREATE SCHEMA hubspot')
END
GO

/*
================================================================================
TABLE: hubspot.contact
DESCRIPTION: HubSpot contact records with properties and lifecycle stage.
             Contains contact-level CRM data including marketing engagement.
================================================================================
*/

CREATE TABLE [hubspot].[contact] (
    [contact_id] BIGINT NOT NULL,
    [email] NVARCHAR(255) NULL,
    [first_name] NVARCHAR(255) NULL,
    [last_name] NVARCHAR(255) NULL,
    [phone] NVARCHAR(100) NULL,
    [company] NVARCHAR(255) NULL,
    [job_title] NVARCHAR(255) NULL,
    [lifecycle_stage] NVARCHAR(100) NULL,
    [lead_status] NVARCHAR(100) NULL,
    [owner_id] BIGINT NULL,
    [associated_company_id] BIGINT NULL,
    [created_at] DATETIME2 NULL,
    [updated_at] DATETIME2 NULL,
    [last_activity_date] DATE NULL,
    [last_contacted] DATETIME2 NULL,
    [num_associated_deals] INT NULL,
    [total_revenue] DECIMAL(18, 2) NULL,
    [hs_analytics_source] NVARCHAR(100) NULL,
    [hs_analytics_source_data_1] NVARCHAR(255) NULL,
    [hs_analytics_source_data_2] NVARCHAR(255) NULL,
    [hs_analytics_first_url] NVARCHAR(2048) NULL,
    [hs_analytics_num_page_views] INT NULL,
    [hs_analytics_num_visits] INT NULL,
    [hs_analytics_num_event_completions] INT NULL,
    [hs_email_optout] BIT NULL,
    [hs_email_bounce] BIT NULL,
    [hs_email_quarantined] BIT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_contact] PRIMARY KEY CLUSTERED ([contact_id])
);
GO

CREATE INDEX [IX_contact_email] ON [hubspot].[contact] ([email]);
CREATE INDEX [IX_contact_lifecycle_stage] ON [hubspot].[contact] ([lifecycle_stage]);
CREATE INDEX [IX_contact_owner_id] ON [hubspot].[contact] ([owner_id]);
CREATE INDEX [IX_contact_associated_company_id] ON [hubspot].[contact] ([associated_company_id]);
CREATE INDEX [IX_contact_created_at] ON [hubspot].[contact] ([created_at]);
GO

/*
================================================================================
TABLE: hubspot.contact_list_member
DESCRIPTION: Membership records linking contacts to HubSpot lists.
             Tracks which contacts belong to which marketing lists.
================================================================================
*/

CREATE TABLE [hubspot].[contact_list_member] (
    [contact_id] BIGINT NOT NULL,
    [contact_list_id] BIGINT NOT NULL,
    [added_at] DATETIME2 NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_contact_list_member] PRIMARY KEY CLUSTERED ([contact_id], [contact_list_id])
);
GO

CREATE INDEX [IX_contact_list_member_list_id] ON [hubspot].[contact_list_member] ([contact_list_id]);
GO

/*
================================================================================
TABLE: hubspot.contact_list
DESCRIPTION: HubSpot contact lists for segmentation and marketing campaigns.
================================================================================
*/

CREATE TABLE [hubspot].[contact_list] (
    [contact_list_id] BIGINT NOT NULL,
    [name] NVARCHAR(255) NULL,
    [dynamic] BIT NULL,
    [created_at] DATETIME2 NULL,
    [updated_at] DATETIME2 NULL,
    [list_size] INT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_contact_list] PRIMARY KEY CLUSTERED ([contact_list_id])
);
GO

/*
================================================================================
TABLE: hubspot.company
DESCRIPTION: HubSpot company records representing accounts/organizations.
             Contains company-level CRM data and analytics.
================================================================================
*/

CREATE TABLE [hubspot].[company] (
    [company_id] BIGINT NOT NULL,
    [name] NVARCHAR(255) NULL,
    [domain] NVARCHAR(255) NULL,
    [industry] NVARCHAR(255) NULL,
    [type] NVARCHAR(100) NULL,
    [phone] NVARCHAR(100) NULL,
    [city] NVARCHAR(255) NULL,
    [state] NVARCHAR(255) NULL,
    [country] NVARCHAR(255) NULL,
    [postal_code] NVARCHAR(50) NULL,
    [owner_id] BIGINT NULL,
    [lifecycle_stage] NVARCHAR(100) NULL,
    [lead_status] NVARCHAR(100) NULL,
    [num_employees] NVARCHAR(100) NULL,
    [annual_revenue] DECIMAL(18, 2) NULL,
    [total_revenue] DECIMAL(18, 2) NULL,
    [num_associated_contacts] INT NULL,
    [num_associated_deals] INT NULL,
    [created_at] DATETIME2 NULL,
    [updated_at] DATETIME2 NULL,
    [last_activity_date] DATE NULL,
    [last_contacted] DATETIME2 NULL,
    [hs_analytics_source] NVARCHAR(100) NULL,
    [hs_analytics_num_page_views] INT NULL,
    [hs_analytics_num_visits] INT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_company] PRIMARY KEY CLUSTERED ([company_id])
);
GO

CREATE INDEX [IX_company_domain] ON [hubspot].[company] ([domain]);
CREATE INDEX [IX_company_industry] ON [hubspot].[company] ([industry]);
CREATE INDEX [IX_company_owner_id] ON [hubspot].[company] ([owner_id]);
CREATE INDEX [IX_company_lifecycle_stage] ON [hubspot].[company] ([lifecycle_stage]);
CREATE INDEX [IX_company_created_at] ON [hubspot].[company] ([created_at]);
GO

/*
================================================================================
TABLE: hubspot.deal
DESCRIPTION: HubSpot deal records representing sales opportunities.
             Contains deal pipeline, stage, and value information.
================================================================================
*/

CREATE TABLE [hubspot].[deal] (
    [deal_id] BIGINT NOT NULL,
    [deal_name] NVARCHAR(255) NULL,
    [pipeline_id] NVARCHAR(100) NULL,
    [pipeline_stage_id] NVARCHAR(100) NULL,
    [deal_stage] NVARCHAR(100) NULL,
    [deal_type] NVARCHAR(100) NULL,
    [amount] DECIMAL(18, 2) NULL,
    [deal_currency_code] NVARCHAR(10) NULL,
    [close_date] DATE NULL,
    [create_date] DATETIME2 NULL,
    [owner_id] BIGINT NULL,
    [associated_company_id] BIGINT NULL,
    [associated_contact_id] BIGINT NULL,
    [is_closed] BIT NULL,
    [is_closed_won] BIT NULL,
    [days_to_close] INT NULL,
    [hs_analytics_source] NVARCHAR(100) NULL,
    [hs_deal_stage_probability] DECIMAL(5, 2) NULL,
    [hs_projected_amount] DECIMAL(18, 2) NULL,
    [hs_acv] DECIMAL(18, 2) NULL,
    [hs_arr] DECIMAL(18, 2) NULL,
    [hs_mrr] DECIMAL(18, 2) NULL,
    [hs_tcv] DECIMAL(18, 2) NULL,
    [num_contacted_notes] INT NULL,
    [num_notes] INT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_deal] PRIMARY KEY CLUSTERED ([deal_id])
);
GO

CREATE INDEX [IX_deal_pipeline_id] ON [hubspot].[deal] ([pipeline_id]);
CREATE INDEX [IX_deal_pipeline_stage_id] ON [hubspot].[deal] ([pipeline_stage_id]);
CREATE INDEX [IX_deal_owner_id] ON [hubspot].[deal] ([owner_id]);
CREATE INDEX [IX_deal_associated_company_id] ON [hubspot].[deal] ([associated_company_id]);
CREATE INDEX [IX_deal_close_date] ON [hubspot].[deal] ([close_date]);
CREATE INDEX [IX_deal_is_closed_won] ON [hubspot].[deal] ([is_closed_won], [close_date]);
GO

/*
================================================================================
TABLE: hubspot.deal_stage
DESCRIPTION: HubSpot deal stage definitions for each pipeline.
             Used to track deal progression through sales process.
================================================================================
*/

CREATE TABLE [hubspot].[deal_stage] (
    [stage_id] NVARCHAR(100) NOT NULL,
    [pipeline_id] NVARCHAR(100) NOT NULL,
    [label] NVARCHAR(255) NULL,
    [display_order] INT NULL,
    [probability] DECIMAL(5, 2) NULL,
    [is_closed] BIT NULL,
    [is_closed_won] BIT NULL,
    [created_at] DATETIME2 NULL,
    [updated_at] DATETIME2 NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_deal_stage] PRIMARY KEY CLUSTERED ([stage_id], [pipeline_id])
);
GO

CREATE INDEX [IX_deal_stage_pipeline_id] ON [hubspot].[deal_stage] ([pipeline_id]);
GO

/*
================================================================================
TABLE: hubspot.deal_pipeline
DESCRIPTION: HubSpot deal pipelines for organizing sales processes.
================================================================================
*/

CREATE TABLE [hubspot].[deal_pipeline] (
    [pipeline_id] NVARCHAR(100) NOT NULL,
    [label] NVARCHAR(255) NULL,
    [display_order] INT NULL,
    [created_at] DATETIME2 NULL,
    [updated_at] DATETIME2 NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_deal_pipeline] PRIMARY KEY CLUSTERED ([pipeline_id])
);
GO

/*
================================================================================
TABLE: hubspot.deal_stage_history
DESCRIPTION: Historical record of deal stage changes for conversion analysis.
             Tracks when deals moved between stages in the pipeline.
================================================================================
*/

CREATE TABLE [hubspot].[deal_stage_history] (
    [deal_id] BIGINT NOT NULL,
    [stage_id] NVARCHAR(100) NOT NULL,
    [pipeline_id] NVARCHAR(100) NOT NULL,
    [timestamp] DATETIME2 NOT NULL,
    [source] NVARCHAR(100) NULL,
    [source_id] NVARCHAR(255) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_deal_stage_history] PRIMARY KEY CLUSTERED ([deal_id], [stage_id], [timestamp])
);
GO

CREATE INDEX [IX_deal_stage_history_deal_id] ON [hubspot].[deal_stage_history] ([deal_id], [timestamp] DESC);
CREATE INDEX [IX_deal_stage_history_timestamp] ON [hubspot].[deal_stage_history] ([timestamp]);
GO

/*
================================================================================
TABLE: hubspot.owner
DESCRIPTION: HubSpot owner records representing sales reps and team members.
================================================================================
*/

CREATE TABLE [hubspot].[owner] (
    [owner_id] BIGINT NOT NULL,
    [email] NVARCHAR(255) NULL,
    [first_name] NVARCHAR(255) NULL,
    [last_name] NVARCHAR(255) NULL,
    [type] NVARCHAR(100) NULL,
    [created_at] DATETIME2 NULL,
    [updated_at] DATETIME2 NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_owner] PRIMARY KEY CLUSTERED ([owner_id])
);
GO

/*
================================================================================
TABLE: hubspot.email_campaign
DESCRIPTION: HubSpot marketing email campaign definitions.
             Contains campaign metadata and settings.
================================================================================
*/

CREATE TABLE [hubspot].[email_campaign] (
    [campaign_id] BIGINT NOT NULL,
    [app_id] BIGINT NULL,
    [app_name] NVARCHAR(255) NULL,
    [content_id] BIGINT NULL,
    [subject] NVARCHAR(500) NULL,
    [name] NVARCHAR(255) NULL,
    [type] NVARCHAR(100) NULL,
    [num_included] INT NULL,
    [num_queued] INT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_email_campaign] PRIMARY KEY CLUSTERED ([campaign_id])
);
GO

CREATE INDEX [IX_email_campaign_content_id] ON [hubspot].[email_campaign] ([content_id]);
GO

/*
================================================================================
TABLE: hubspot.email_event
DESCRIPTION: HubSpot email event records tracking email interactions.
             Includes sends, deliveries, opens, clicks, bounces, and unsubscribes.
================================================================================
*/

CREATE TABLE [hubspot].[email_event] (
    [event_id] NVARCHAR(255) NOT NULL,
    [email_campaign_id] BIGINT NULL,
    [recipient] NVARCHAR(255) NULL,
    [type] NVARCHAR(50) NOT NULL,
    [created_at] DATETIME2 NULL,
    [sent_by_created_at] DATETIME2 NULL,
    [app_id] BIGINT NULL,
    [portal_id] BIGINT NULL,
    [browser_name] NVARCHAR(100) NULL,
    [browser_version] NVARCHAR(50) NULL,
    [device_type] NVARCHAR(50) NULL,
    [location_city] NVARCHAR(255) NULL,
    [location_state] NVARCHAR(255) NULL,
    [location_country] NVARCHAR(255) NULL,
    [url] NVARCHAR(2048) NULL,
    [link_id] BIGINT NULL,
    [user_agent] NVARCHAR(1000) NULL,
    [ip_address] NVARCHAR(50) NULL,
    [duration] INT NULL,
    [response] NVARCHAR(500) NULL,
    [bounce_category] NVARCHAR(100) NULL,
    [drop_reason] NVARCHAR(255) NULL,
    [drop_message] NVARCHAR(500) NULL,
    [subscription_id] BIGINT NULL,
    [caused_by_event_id] NVARCHAR(255) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_email_event] PRIMARY KEY CLUSTERED ([event_id])
);
GO

CREATE INDEX [IX_email_event_campaign_id] ON [hubspot].[email_event] ([email_campaign_id]);
CREATE INDEX [IX_email_event_type] ON [hubspot].[email_event] ([type]);
CREATE INDEX [IX_email_event_created_at] ON [hubspot].[email_event] ([created_at]);
CREATE INDEX [IX_email_event_recipient] ON [hubspot].[email_event] ([recipient]);
GO

/*
================================================================================
TABLE: hubspot.email_event_sent
DESCRIPTION: Sent email event details with delivery status.
================================================================================
*/

CREATE TABLE [hubspot].[email_event_sent] (
    [event_id] NVARCHAR(255) NOT NULL,
    [from_email] NVARCHAR(255) NULL,
    [bcc] NVARCHAR(MAX) NULL,
    [cc] NVARCHAR(MAX) NULL,
    [reply_to] NVARCHAR(MAX) NULL,
    [subject] NVARCHAR(500) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_email_event_sent] PRIMARY KEY CLUSTERED ([event_id])
);
GO

/*
================================================================================
TABLE: hubspot.email_event_open
DESCRIPTION: Email open event details including device and location.
================================================================================
*/

CREATE TABLE [hubspot].[email_event_open] (
    [event_id] NVARCHAR(255) NOT NULL,
    [browser] NVARCHAR(255) NULL,
    [ip_address] NVARCHAR(50) NULL,
    [location] NVARCHAR(255) NULL,
    [user_agent] NVARCHAR(1000) NULL,
    [duration] INT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_email_event_open] PRIMARY KEY CLUSTERED ([event_id])
);
GO

/*
================================================================================
TABLE: hubspot.email_event_click
DESCRIPTION: Email click event details including clicked URL.
================================================================================
*/

CREATE TABLE [hubspot].[email_event_click] (
    [event_id] NVARCHAR(255) NOT NULL,
    [url] NVARCHAR(2048) NULL,
    [browser] NVARCHAR(255) NULL,
    [ip_address] NVARCHAR(50) NULL,
    [location] NVARCHAR(255) NULL,
    [user_agent] NVARCHAR(1000) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_email_event_click] PRIMARY KEY CLUSTERED ([event_id])
);
GO

/*
================================================================================
TABLE: hubspot.email_event_bounce
DESCRIPTION: Email bounce event details with bounce category.
================================================================================
*/

CREATE TABLE [hubspot].[email_event_bounce] (
    [event_id] NVARCHAR(255) NOT NULL,
    [category] NVARCHAR(100) NULL,
    [response] NVARCHAR(500) NULL,
    [status] NVARCHAR(100) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_email_event_bounce] PRIMARY KEY CLUSTERED ([event_id])
);
GO

/*
================================================================================
TABLE: hubspot.engagement
DESCRIPTION: HubSpot engagement records for all interaction types.
             Includes calls, meetings, emails, notes, and tasks.
================================================================================
*/

CREATE TABLE [hubspot].[engagement] (
    [engagement_id] BIGINT NOT NULL,
    [type] NVARCHAR(50) NOT NULL,
    [created_at] DATETIME2 NULL,
    [last_updated] DATETIME2 NULL,
    [timestamp] DATETIME2 NULL,
    [owner_id] BIGINT NULL,
    [portal_id] BIGINT NULL,
    [active] BIT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    [_fivetran_deleted] BIT DEFAULT 0,
    CONSTRAINT [PK_engagement] PRIMARY KEY CLUSTERED ([engagement_id])
);
GO

CREATE INDEX [IX_engagement_type] ON [hubspot].[engagement] ([type]);
CREATE INDEX [IX_engagement_owner_id] ON [hubspot].[engagement] ([owner_id]);
CREATE INDEX [IX_engagement_created_at] ON [hubspot].[engagement] ([created_at]);
CREATE INDEX [IX_engagement_timestamp] ON [hubspot].[engagement] ([timestamp]);
GO

/*
================================================================================
TABLE: hubspot.engagement_contact
DESCRIPTION: Association between engagements and contacts.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_contact] (
    [engagement_id] BIGINT NOT NULL,
    [contact_id] BIGINT NOT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_contact] PRIMARY KEY CLUSTERED ([engagement_id], [contact_id])
);
GO

CREATE INDEX [IX_engagement_contact_contact_id] ON [hubspot].[engagement_contact] ([contact_id]);
GO

/*
================================================================================
TABLE: hubspot.engagement_company
DESCRIPTION: Association between engagements and companies.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_company] (
    [engagement_id] BIGINT NOT NULL,
    [company_id] BIGINT NOT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_company] PRIMARY KEY CLUSTERED ([engagement_id], [company_id])
);
GO

CREATE INDEX [IX_engagement_company_company_id] ON [hubspot].[engagement_company] ([company_id]);
GO

/*
================================================================================
TABLE: hubspot.engagement_deal
DESCRIPTION: Association between engagements and deals.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_deal] (
    [engagement_id] BIGINT NOT NULL,
    [deal_id] BIGINT NOT NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_deal] PRIMARY KEY CLUSTERED ([engagement_id], [deal_id])
);
GO

CREATE INDEX [IX_engagement_deal_deal_id] ON [hubspot].[engagement_deal] ([deal_id]);
GO

/*
================================================================================
TABLE: hubspot.engagement_call
DESCRIPTION: Call engagement details including duration and outcome.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_call] (
    [engagement_id] BIGINT NOT NULL,
    [body] NVARCHAR(MAX) NULL,
    [disposition] NVARCHAR(100) NULL,
    [duration_milliseconds] BIGINT NULL,
    [external_account_id] NVARCHAR(255) NULL,
    [external_id] NVARCHAR(255) NULL,
    [from_number] NVARCHAR(100) NULL,
    [to_number] NVARCHAR(100) NULL,
    [recording_url] NVARCHAR(2048) NULL,
    [status] NVARCHAR(100) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_call] PRIMARY KEY CLUSTERED ([engagement_id])
);
GO

/*
================================================================================
TABLE: hubspot.engagement_meeting
DESCRIPTION: Meeting engagement details including attendees and outcome.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_meeting] (
    [engagement_id] BIGINT NOT NULL,
    [body] NVARCHAR(MAX) NULL,
    [title] NVARCHAR(500) NULL,
    [start_time] DATETIME2 NULL,
    [end_time] DATETIME2 NULL,
    [internal_meeting_notes] NVARCHAR(MAX) NULL,
    [external_url] NVARCHAR(2048) NULL,
    [meeting_outcome] NVARCHAR(100) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_meeting] PRIMARY KEY CLUSTERED ([engagement_id])
);
GO

/*
================================================================================
TABLE: hubspot.engagement_email
DESCRIPTION: Email engagement details sent through HubSpot CRM.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_email] (
    [engagement_id] BIGINT NOT NULL,
    [body] NVARCHAR(MAX) NULL,
    [subject] NVARCHAR(500) NULL,
    [from_email] NVARCHAR(255) NULL,
    [from_first_name] NVARCHAR(255) NULL,
    [from_last_name] NVARCHAR(255) NULL,
    [to_email] NVARCHAR(MAX) NULL,
    [cc_email] NVARCHAR(MAX) NULL,
    [bcc_email] NVARCHAR(MAX) NULL,
    [sender_email] NVARCHAR(255) NULL,
    [tracker_key] NVARCHAR(255) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_email] PRIMARY KEY CLUSTERED ([engagement_id])
);
GO

/*
================================================================================
TABLE: hubspot.engagement_note
DESCRIPTION: Note engagement details.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_note] (
    [engagement_id] BIGINT NOT NULL,
    [body] NVARCHAR(MAX) NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_note] PRIMARY KEY CLUSTERED ([engagement_id])
);
GO

/*
================================================================================
TABLE: hubspot.engagement_task
DESCRIPTION: Task engagement details including status and priority.
================================================================================
*/

CREATE TABLE [hubspot].[engagement_task] (
    [engagement_id] BIGINT NOT NULL,
    [body] NVARCHAR(MAX) NULL,
    [subject] NVARCHAR(500) NULL,
    [status] NVARCHAR(100) NULL,
    [for_object_type] NVARCHAR(100) NULL,
    [task_type] NVARCHAR(100) NULL,
    [priority] NVARCHAR(50) NULL,
    [completion_date] DATETIME2 NULL,
    [_fivetran_synced] DATETIME2 NOT NULL,
    CONSTRAINT [PK_engagement_task] PRIMARY KEY CLUSTERED ([engagement_id])
);
GO
