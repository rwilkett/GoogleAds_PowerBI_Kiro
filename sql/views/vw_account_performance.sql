/*
================================================================================
VIEW: vw_account_performance
DESCRIPTION: Account-level performance metrics aggregated from Google Ads data.
             Provides daily account stats with calculated KPIs for PowerBI.
FIVETRAN TABLES: google_ads.account_stats, google_ads.account_history
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_account_performance]
AS
SELECT 
    -- Dimension Keys
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    
    -- Account Information (from history table - latest values)
    ah.descriptive_name AS account_name,
    ah.currency_code,
    ah.time_zone AS account_timezone,
    
    -- Raw Metrics
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    COALESCE(a.conversions, 0) AS conversions,
    COALESCE(a.conversions_value, 0) AS conversions_value,
    COALESCE(a.view_through_conversions, 0) AS view_through_conversions,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN a.clicks > 0 
        THEN CAST((a.spend / a.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Conversion Rate
    CASE 
        WHEN a.clicks > 0 
        THEN CAST((COALESCE(a.conversions, 0) * 100.0 / a.clicks) AS DECIMAL(10, 4))
        ELSE 0 
    END AS conversion_rate_percent,
    
    -- Calculated Metrics - Cost Per Conversion
    CASE 
        WHEN COALESCE(a.conversions, 0) > 0 
        THEN CAST((a.spend / a.conversions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_conversion,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN a.spend > 0 
        THEN CAST((COALESCE(a.conversions_value, 0) / a.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Calculated Metrics - Average Cost Per Mille (CPM)
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.spend * 1000.0 / a.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- Engagement Rate (clicks per 1000 impressions)
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.clicks * 1000.0 / a.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS engagement_rate,
    
    -- Metadata
    a._fivetran_synced AS last_synced_at

FROM google_ads.account_stats a
LEFT JOIN (
    -- Get the latest account information
    SELECT 
        account_id,
        descriptive_name,
        currency_code,
        time_zone,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.account_history
) ah ON a.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_account_performance_summary
DESCRIPTION: Aggregated account performance summary with period comparisons.
             Useful for account-level dashboards and trend analysis.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_account_performance_summary]
AS
WITH CurrentPeriod AS (
    SELECT 
        account_id,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value,
        MIN(date) AS period_start,
        MAX(date) AS period_end,
        COUNT(DISTINCT date) AS days_in_period
    FROM [dbo].[vw_account_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
      AND date < CAST(GETDATE() AS DATE)
    GROUP BY account_id
),
PreviousPeriod AS (
    SELECT 
        account_id,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value
    FROM [dbo].[vw_account_performance]
    WHERE date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
      AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY account_id
)
SELECT 
    -- Account info
    cp.account_id,
    ah.descriptive_name AS account_name,
    ah.currency_code,
    
    -- Current period metrics
    cp.total_spend AS current_spend,
    cp.total_impressions AS current_impressions,
    cp.total_clicks AS current_clicks,
    cp.total_conversions AS current_conversions,
    cp.total_conversions_value AS current_conversions_value,
    
    -- Current period KPIs
    CASE WHEN cp.total_impressions > 0 
         THEN CAST((cp.total_clicks * 100.0 / cp.total_impressions) AS DECIMAL(10, 4)) 
         ELSE 0 END AS current_ctr,
    CASE WHEN cp.total_clicks > 0 
         THEN CAST((cp.total_spend / cp.total_clicks) AS DECIMAL(18, 4)) 
         ELSE 0 END AS current_cpc,
    CASE WHEN cp.total_clicks > 0 
         THEN CAST((cp.total_conversions * 100.0 / cp.total_clicks) AS DECIMAL(10, 4)) 
         ELSE 0 END AS current_conversion_rate,
    CASE WHEN cp.total_conversions > 0 
         THEN CAST((cp.total_spend / cp.total_conversions) AS DECIMAL(18, 4)) 
         ELSE 0 END AS current_cost_per_conversion,
    CASE WHEN cp.total_spend > 0 
         THEN CAST((cp.total_conversions_value / cp.total_spend) AS DECIMAL(10, 4)) 
         ELSE 0 END AS current_roas,
    
    -- Previous period metrics
    COALESCE(pp.total_spend, 0) AS previous_spend,
    COALESCE(pp.total_impressions, 0) AS previous_impressions,
    COALESCE(pp.total_clicks, 0) AS previous_clicks,
    COALESCE(pp.total_conversions, 0) AS previous_conversions,
    
    -- Change percentages
    CASE WHEN COALESCE(pp.total_spend, 0) > 0 
         THEN CAST(((cp.total_spend - pp.total_spend) * 100.0 / pp.total_spend) AS DECIMAL(10, 2)) 
         ELSE NULL END AS spend_change_percent,
    CASE WHEN COALESCE(pp.total_impressions, 0) > 0 
         THEN CAST(((cp.total_impressions - pp.total_impressions) * 100.0 / pp.total_impressions) AS DECIMAL(10, 2)) 
         ELSE NULL END AS impressions_change_percent,
    CASE WHEN COALESCE(pp.total_clicks, 0) > 0 
         THEN CAST(((cp.total_clicks - pp.total_clicks) * 100.0 / pp.total_clicks) AS DECIMAL(10, 2)) 
         ELSE NULL END AS clicks_change_percent,
    CASE WHEN COALESCE(pp.total_conversions, 0) > 0 
         THEN CAST(((cp.total_conversions - pp.total_conversions) * 100.0 / pp.total_conversions) AS DECIMAL(10, 2)) 
         ELSE NULL END AS conversions_change_percent,
    
    -- Period information
    cp.period_start,
    cp.period_end,
    cp.days_in_period

FROM CurrentPeriod cp
LEFT JOIN PreviousPeriod pp ON cp.account_id = pp.account_id
LEFT JOIN (
    SELECT 
        account_id,
        descriptive_name,
        currency_code,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.account_history
) ah ON cp.account_id = ah.account_id AND ah.rn = 1;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily account-level performance metrics with calculated KPIs from Google Ads.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_account_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Aggregated account performance summary with 30-day period comparisons.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_account_performance_summary';
GO
