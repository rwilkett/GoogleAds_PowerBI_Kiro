/*
================================================================================
VIEW: vw_campaign_performance
DESCRIPTION: Campaign-level performance metrics with trend analysis capabilities.
             Includes campaign details and calculated KPIs for PowerBI dashboards.
SCHEMA TABLES:
  - google_ads.campaign_stats: Daily campaign-level performance metrics
    Columns: campaign_id, account_id, date, spend, impressions, clicks, conversions,
             conversions_value, view_through_conversions, video_views,
             video_quartile_p25_rate, video_quartile_p50_rate, video_quartile_p75_rate,
             video_quartile_p100_rate, interactions, interaction_event_types, _fivetran_synced
  - google_ads.campaign_history: Campaign metadata with change history
    Columns: campaign_id, account_id, name, status, advertising_channel_type,
             advertising_channel_sub_type, bidding_strategy_type, start_date, end_date,
             budget_amount, budget_period, _fivetran_synced
  - google_ads.account_history: Account metadata with change history
    Columns: account_id, descriptive_name, currency_code, _fivetran_synced
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_campaign_performance]
AS
SELECT 
    -- Dimension Keys
    c.campaign_id,
    c.account_id,
    c.date,
    CONVERT(INT, FORMAT(c.date, 'yyyyMMdd')) AS date_id,
    
    -- Campaign Information (from history table - latest values)
    ch.name AS campaign_name,
    ch.status AS campaign_status,
    ch.advertising_channel_type,
    ch.advertising_channel_sub_type,
    ch.bidding_strategy_type,
    ch.start_date AS campaign_start_date,
    ch.end_date AS campaign_end_date,
    
    -- Budget Information
    ch.budget_amount,
    ch.budget_period,
    
    -- Account Information
    ah.descriptive_name AS account_name,
    ah.currency_code,
    
    -- Raw Metrics
    CAST(c.spend AS DECIMAL(18, 2)) AS spend,
    c.impressions,
    c.clicks,
    COALESCE(c.conversions, 0) AS conversions,
    COALESCE(c.conversions_value, 0) AS conversions_value,
    COALESCE(c.view_through_conversions, 0) AS view_through_conversions,
    
    -- Video Metrics (if applicable)
    COALESCE(c.video_views, 0) AS video_views,
    COALESCE(c.video_quartile_p25_rate, 0) AS video_quartile_25_rate,
    COALESCE(c.video_quartile_p50_rate, 0) AS video_quartile_50_rate,
    COALESCE(c.video_quartile_p75_rate, 0) AS video_quartile_75_rate,
    COALESCE(c.video_quartile_p100_rate, 0) AS video_quartile_100_rate,
    
    -- Interaction Metrics
    COALESCE(c.interactions, 0) AS interactions,
    COALESCE(c.interaction_event_types, '') AS interaction_event_types,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN c.impressions > 0 
        THEN CAST((c.clicks * 100.0 / c.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN c.clicks > 0 
        THEN CAST((c.spend / c.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Conversion Rate
    CASE 
        WHEN c.clicks > 0 
        THEN CAST((COALESCE(c.conversions, 0) * 100.0 / c.clicks) AS DECIMAL(10, 4))
        ELSE 0 
    END AS conversion_rate_percent,
    
    -- Calculated Metrics - Cost Per Conversion
    CASE 
        WHEN COALESCE(c.conversions, 0) > 0 
        THEN CAST((c.spend / c.conversions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_conversion,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN c.spend > 0 
        THEN CAST((COALESCE(c.conversions_value, 0) / c.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Calculated Metrics - Average CPM
    CASE 
        WHEN c.impressions > 0 
        THEN CAST((c.spend * 1000.0 / c.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- Budget Utilization (daily)
    CASE 
        WHEN ch.budget_amount > 0 
        THEN CAST((c.spend * 100.0 / ch.budget_amount) AS DECIMAL(10, 2))
        ELSE 0 
    END AS budget_utilization_percent,
    
    -- Metadata
    c._fivetran_synced AS last_synced_at

FROM google_ads.campaign_stats c
LEFT JOIN (
    SELECT 
        campaign_id,
        name,
        status,
        advertising_channel_type,
        advertising_channel_sub_type,
        bidding_strategy_type,
        start_date,
        end_date,
        budget_amount,
        budget_period,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.campaign_history
) ch ON c.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT 
        account_id,
        descriptive_name,
        currency_code,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.account_history
) ah ON c.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_campaign_trend_analysis
DESCRIPTION: Campaign performance with trend analysis including moving averages,
             week-over-week and month-over-month comparisons.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_campaign_trend_analysis]
AS
WITH CampaignDailyMetrics AS (
    SELECT 
        campaign_id,
        date,
        campaign_name,
        campaign_status,
        advertising_channel_type,
        spend,
        impressions,
        clicks,
        conversions,
        conversions_value,
        ctr_percent,
        avg_cpc,
        conversion_rate_percent,
        roas
    FROM [dbo].[vw_campaign_performance]
)
SELECT 
    cdm.campaign_id,
    cdm.date,
    cdm.campaign_name,
    cdm.campaign_status,
    cdm.advertising_channel_type,
    
    -- Current day metrics
    cdm.spend,
    cdm.impressions,
    cdm.clicks,
    cdm.conversions,
    cdm.conversions_value,
    cdm.ctr_percent,
    cdm.avg_cpc,
    cdm.conversion_rate_percent,
    cdm.roas,
    
    -- 7-Day Moving Averages
    AVG(cdm.spend) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS spend_7day_ma,
    AVG(cdm.impressions) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS impressions_7day_ma,
    AVG(cdm.clicks) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS clicks_7day_ma,
    AVG(cdm.conversions) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS conversions_7day_ma,
    AVG(cdm.ctr_percent) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS ctr_7day_ma,
    
    -- 30-Day Moving Averages
    AVG(cdm.spend) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS spend_30day_ma,
    AVG(cdm.impressions) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS impressions_30day_ma,
    AVG(cdm.conversions) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS conversions_30day_ma,
    
    -- Week over Week comparison
    LAG(cdm.spend, 7) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date
    ) AS spend_last_week,
    LAG(cdm.clicks, 7) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date
    ) AS clicks_last_week,
    LAG(cdm.conversions, 7) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date
    ) AS conversions_last_week,
    
    -- Week over Week change percentage
    CASE 
        WHEN LAG(cdm.spend, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date) > 0 
        THEN CAST(((cdm.spend - LAG(cdm.spend, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) * 100.0 
             / LAG(cdm.spend, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) AS DECIMAL(10, 2))
        ELSE NULL 
    END AS spend_wow_change_percent,
    
    CASE 
        WHEN LAG(cdm.clicks, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date) > 0 
        THEN CAST(((cdm.clicks - LAG(cdm.clicks, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) * 100.0 
             / LAG(cdm.clicks, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) AS DECIMAL(10, 2))
        ELSE NULL 
    END AS clicks_wow_change_percent,
    
    -- Cumulative metrics for the period
    SUM(cdm.spend) OVER (
        PARTITION BY cdm.campaign_id, YEAR(cdm.date), MONTH(cdm.date) 
        ORDER BY cdm.date
    ) AS mtd_spend,
    SUM(cdm.conversions) OVER (
        PARTITION BY cdm.campaign_id, YEAR(cdm.date), MONTH(cdm.date) 
        ORDER BY cdm.date
    ) AS mtd_conversions,
    
    -- Rank campaigns by daily performance
    DENSE_RANK() OVER (
        PARTITION BY cdm.date 
        ORDER BY cdm.spend DESC
    ) AS daily_spend_rank,
    DENSE_RANK() OVER (
        PARTITION BY cdm.date 
        ORDER BY cdm.conversions DESC
    ) AS daily_conversions_rank

FROM CampaignDailyMetrics cdm;
GO

/*
================================================================================
VIEW: vw_campaign_performance_summary
DESCRIPTION: Aggregated campaign performance summary for dashboard cards and KPI displays.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_campaign_performance_summary]
AS
SELECT 
    cp.campaign_id,
    cp.campaign_name,
    cp.campaign_status,
    cp.advertising_channel_type,
    cp.account_name,
    cp.currency_code,
    
    -- Aggregated metrics (last 30 days)
    SUM(cp.spend) AS total_spend,
    SUM(cp.impressions) AS total_impressions,
    SUM(cp.clicks) AS total_clicks,
    SUM(cp.conversions) AS total_conversions,
    SUM(cp.conversions_value) AS total_conversions_value,
    
    -- Calculated KPIs
    CASE WHEN SUM(cp.impressions) > 0 
         THEN CAST((SUM(cp.clicks) * 100.0 / SUM(cp.impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(cp.clicks) > 0 
         THEN CAST((SUM(cp.spend) / SUM(cp.clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(cp.clicks) > 0 
         THEN CAST((SUM(cp.conversions) * 100.0 / SUM(cp.clicks)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_conversion_rate,
    CASE WHEN SUM(cp.conversions) > 0 
         THEN CAST((SUM(cp.spend) / SUM(cp.conversions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_conversion,
    CASE WHEN SUM(cp.spend) > 0 
         THEN CAST((SUM(cp.conversions_value) / SUM(cp.spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    
    -- Date range
    MIN(cp.date) AS first_date,
    MAX(cp.date) AS last_date,
    COUNT(DISTINCT cp.date) AS active_days

FROM [dbo].[vw_campaign_performance] cp
WHERE cp.date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY 
    cp.campaign_id,
    cp.campaign_name,
    cp.campaign_status,
    cp.advertising_channel_type,
    cp.account_name,
    cp.currency_code;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily campaign-level performance metrics with calculated KPIs from Google Ads.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_campaign_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Campaign performance with trend analysis including moving averages and period comparisons.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_campaign_trend_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Aggregated campaign performance summary for dashboard displays.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_campaign_performance_summary';
GO
