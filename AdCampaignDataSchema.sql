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
