/*
================================================================================
VIEW: vw_facebook_account_performance
DESCRIPTION: Account-level performance metrics aggregated from Facebook Ads data.
             Provides daily account stats with calculated KPIs for PowerBI.
             Facebook Ads uses reach and frequency metrics in addition to standard
             digital advertising metrics.
SCHEMA TABLES:
  - facebook_ads.basic_ad: Daily ad-level performance metrics aggregated to account
    Columns: ad_id, adset_id, campaign_id, account_id, date, spend, impressions, 
             clicks, reach, frequency, actions, action_values, inline_link_clicks,
             inline_link_click_ctr, cost_per_inline_link_click, cpc, cpm, cpp, ctr,
             unique_clicks, unique_ctr, _fivetran_synced
  - facebook_ads.account_history: Account metadata with change history
    Columns: account_id, name, account_status, currency, timezone_name, 
             _fivetran_synced, _fivetran_deleted
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_account_performance]
AS
SELECT 
    -- Dimension Keys
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    
    -- Account Information (from history table - latest values)
    ah.name AS account_name,
    ah.currency AS currency_code,
    ah.timezone_name AS account_timezone,
    ah.account_status,
    
    -- Raw Metrics
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    a.reach,
    a.unique_clicks,
    
    -- Frequency (impressions per reach)
    CASE 
        WHEN a.reach > 0 
        THEN CAST((a.impressions * 1.0 / a.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS frequency,
    
    -- Action Metrics (converted from JSON where applicable)
    COALESCE(a.inline_link_clicks, 0) AS link_clicks,
    COALESCE(a.actions, 0) AS total_actions,
    COALESCE(a.action_values, 0) AS total_action_value,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Unique CTR (based on reach)
    CASE 
        WHEN a.reach > 0 
        THEN CAST((a.unique_clicks * 100.0 / a.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS unique_ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN a.clicks > 0 
        THEN CAST((a.spend / a.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Cost Per Link Click
    CASE 
        WHEN COALESCE(a.inline_link_clicks, 0) > 0 
        THEN CAST((a.spend / a.inline_link_clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_link_click,
    
    -- Calculated Metrics - Cost Per Result (using actions)
    CASE 
        WHEN COALESCE(a.actions, 0) > 0 
        THEN CAST((a.spend / a.actions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_action,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN a.spend > 0 
        THEN CAST((COALESCE(a.action_values, 0) / a.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Calculated Metrics - Average CPM (Cost Per 1000 Impressions)
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.spend * 1000.0 / a.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- Calculated Metrics - Cost Per 1000 People Reached (CPP)
    CASE 
        WHEN a.reach > 0 
        THEN CAST((a.spend * 1000.0 / a.reach) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cpp,
    
    -- Metadata
    a._fivetran_synced AS last_synced_at

FROM (
    -- Aggregate basic_ad to account level
    SELECT 
        account_id,
        date,
        SUM(spend) AS spend,
        SUM(impressions) AS impressions,
        SUM(clicks) AS clicks,
        SUM(reach) AS reach,
        SUM(unique_clicks) AS unique_clicks,
        SUM(inline_link_clicks) AS inline_link_clicks,
        SUM(actions) AS actions,
        SUM(action_values) AS action_values,
        MAX(_fivetran_synced) AS _fivetran_synced
    FROM facebook_ads.basic_ad
    GROUP BY account_id, date
) a
LEFT JOIN (
    -- Get the latest account information
    SELECT 
        account_id,
        name,
        currency,
        timezone_name,
        account_status,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.account_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ah ON a.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_facebook_account_performance_summary
DESCRIPTION: Aggregated Facebook account performance summary with period comparisons.
             Useful for account-level dashboards and trend analysis.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_account_performance_summary]
AS
WITH CurrentPeriod AS (
    SELECT 
        account_id,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(reach) AS total_reach,
        SUM(link_clicks) AS total_link_clicks,
        SUM(total_actions) AS total_actions,
        SUM(total_action_value) AS total_action_value,
        MIN(date) AS period_start,
        MAX(date) AS period_end,
        COUNT(DISTINCT date) AS days_in_period
    FROM [dbo].[vw_facebook_account_performance]
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
        SUM(reach) AS total_reach,
        SUM(total_actions) AS total_actions,
        SUM(total_action_value) AS total_action_value
    FROM [dbo].[vw_facebook_account_performance]
    WHERE date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
      AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY account_id
)
SELECT 
    -- Account info
    cp.account_id,
    ah.name AS account_name,
    ah.currency AS currency_code,
    
    -- Current period metrics
    cp.total_spend AS current_spend,
    cp.total_impressions AS current_impressions,
    cp.total_clicks AS current_clicks,
    cp.total_reach AS current_reach,
    cp.total_link_clicks AS current_link_clicks,
    cp.total_actions AS current_actions,
    cp.total_action_value AS current_action_value,
    
    -- Current period KPIs
    CASE WHEN cp.total_impressions > 0 
         THEN CAST((cp.total_clicks * 100.0 / cp.total_impressions) AS DECIMAL(10, 4)) 
         ELSE 0 END AS current_ctr,
    CASE WHEN cp.total_clicks > 0 
         THEN CAST((cp.total_spend / cp.total_clicks) AS DECIMAL(18, 4)) 
         ELSE 0 END AS current_cpc,
    CASE WHEN cp.total_reach > 0 
         THEN CAST((cp.total_impressions * 1.0 / cp.total_reach) AS DECIMAL(10, 4)) 
         ELSE 0 END AS current_frequency,
    CASE WHEN cp.total_actions > 0 
         THEN CAST((cp.total_spend / cp.total_actions) AS DECIMAL(18, 4)) 
         ELSE 0 END AS current_cost_per_action,
    CASE WHEN cp.total_spend > 0 
         THEN CAST((cp.total_action_value / cp.total_spend) AS DECIMAL(10, 4)) 
         ELSE 0 END AS current_roas,
    
    -- Previous period metrics
    COALESCE(pp.total_spend, 0) AS previous_spend,
    COALESCE(pp.total_impressions, 0) AS previous_impressions,
    COALESCE(pp.total_clicks, 0) AS previous_clicks,
    COALESCE(pp.total_reach, 0) AS previous_reach,
    COALESCE(pp.total_actions, 0) AS previous_actions,
    
    -- Change percentages
    CASE WHEN COALESCE(pp.total_spend, 0) > 0 
         THEN CAST(((cp.total_spend - pp.total_spend) * 100.0 / pp.total_spend) AS DECIMAL(10, 2)) 
         ELSE NULL END AS spend_change_percent,
    CASE WHEN COALESCE(pp.total_impressions, 0) > 0 
         THEN CAST(((cp.total_impressions - pp.total_impressions) * 100.0 / pp.total_impressions) AS DECIMAL(10, 2)) 
         ELSE NULL END AS impressions_change_percent,
    CASE WHEN COALESCE(pp.total_reach, 0) > 0 
         THEN CAST(((cp.total_reach - pp.total_reach) * 100.0 / pp.total_reach) AS DECIMAL(10, 2)) 
         ELSE NULL END AS reach_change_percent,
    CASE WHEN COALESCE(pp.total_actions, 0) > 0 
         THEN CAST(((cp.total_actions - pp.total_actions) * 100.0 / pp.total_actions) AS DECIMAL(10, 2)) 
         ELSE NULL END AS actions_change_percent,
    
    -- Period information
    cp.period_start,
    cp.period_end,
    cp.days_in_period

FROM CurrentPeriod cp
LEFT JOIN PreviousPeriod pp ON cp.account_id = pp.account_id
LEFT JOIN (
    SELECT 
        account_id,
        name,
        currency,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.account_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ah ON cp.account_id = ah.account_id AND ah.rn = 1;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily Facebook Ads account-level performance metrics with calculated KPIs including reach and frequency.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_account_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Aggregated Facebook Ads account performance summary with 30-day period comparisons.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_account_performance_summary';
GO
