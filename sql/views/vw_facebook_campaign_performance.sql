/*
================================================================================
VIEW: vw_facebook_campaign_performance
DESCRIPTION: Campaign-level performance metrics with trend analysis capabilities.
             Includes campaign details and calculated KPIs for PowerBI dashboards.
             Facebook Ads campaigns have unique metrics like reach and frequency.
SCHEMA TABLES:
  - facebook_ads.basic_ad: Daily ad-level performance metrics aggregated to campaign
    Columns: ad_id, adset_id, campaign_id, account_id, date, spend, impressions, 
             clicks, reach, frequency, actions, action_values, inline_link_clicks,
             inline_link_click_ctr, cost_per_inline_link_click, cpc, cpm, cpp, ctr,
             unique_clicks, unique_ctr, _fivetran_synced
  - facebook_ads.campaign_history: Campaign metadata with change history
    Columns: campaign_id, account_id, name, status, objective, buying_type,
             daily_budget, lifetime_budget, budget_remaining, start_time, stop_time,
             _fivetran_synced, _fivetran_deleted
  - facebook_ads.account_history: Account metadata with change history
    Columns: account_id, name, currency, timezone_name, _fivetran_synced
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_campaign_performance]
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
    ch.objective AS campaign_objective,
    ch.buying_type,
    ch.start_time AS campaign_start_time,
    ch.stop_time AS campaign_stop_time,
    
    -- Budget Information
    ch.daily_budget,
    ch.lifetime_budget,
    ch.budget_remaining,
    
    -- Account Information
    ah.name AS account_name,
    ah.currency AS currency_code,
    
    -- Raw Metrics
    CAST(c.spend AS DECIMAL(18, 2)) AS spend,
    c.impressions,
    c.clicks,
    c.reach,
    c.unique_clicks,
    
    -- Frequency (impressions per reach)
    CASE 
        WHEN c.reach > 0 
        THEN CAST((c.impressions * 1.0 / c.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS frequency,
    
    -- Link and Action Metrics
    COALESCE(c.inline_link_clicks, 0) AS link_clicks,
    COALESCE(c.actions, 0) AS total_actions,
    COALESCE(c.action_values, 0) AS total_action_value,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN c.impressions > 0 
        THEN CAST((c.clicks * 100.0 / c.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Unique CTR
    CASE 
        WHEN c.reach > 0 
        THEN CAST((c.unique_clicks * 100.0 / c.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS unique_ctr_percent,
    
    -- Calculated Metrics - Link Click Through Rate
    CASE 
        WHEN c.impressions > 0 
        THEN CAST((COALESCE(c.inline_link_clicks, 0) * 100.0 / c.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS link_ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN c.clicks > 0 
        THEN CAST((c.spend / c.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Cost Per Link Click
    CASE 
        WHEN COALESCE(c.inline_link_clicks, 0) > 0 
        THEN CAST((c.spend / c.inline_link_clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_link_click,
    
    -- Calculated Metrics - Cost Per Action
    CASE 
        WHEN COALESCE(c.actions, 0) > 0 
        THEN CAST((c.spend / c.actions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_action,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN c.spend > 0 
        THEN CAST((COALESCE(c.action_values, 0) / c.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Calculated Metrics - Average CPM
    CASE 
        WHEN c.impressions > 0 
        THEN CAST((c.spend * 1000.0 / c.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- Calculated Metrics - Cost Per 1000 People Reached (CPP)
    CASE 
        WHEN c.reach > 0 
        THEN CAST((c.spend * 1000.0 / c.reach) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cpp,
    
    -- Budget Utilization (daily)
    CASE 
        WHEN ch.daily_budget > 0 
        THEN CAST((c.spend * 100.0 / ch.daily_budget) AS DECIMAL(10, 2))
        ELSE 0 
    END AS budget_utilization_percent,
    
    -- Metadata
    c._fivetran_synced AS last_synced_at

FROM (
    -- Aggregate basic_ad to campaign level
    SELECT 
        campaign_id,
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
    GROUP BY campaign_id, account_id, date
) c
LEFT JOIN (
    SELECT 
        campaign_id,
        account_id,
        name,
        status,
        objective,
        buying_type,
        daily_budget,
        lifetime_budget,
        budget_remaining,
        start_time,
        stop_time,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.campaign_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ch ON c.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT 
        account_id,
        name,
        currency,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.account_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ah ON c.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_facebook_campaign_trend_analysis
DESCRIPTION: Facebook campaign performance with trend analysis including moving averages,
             week-over-week and month-over-month comparisons.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_campaign_trend_analysis]
AS
WITH CampaignDailyMetrics AS (
    SELECT 
        campaign_id,
        date,
        campaign_name,
        campaign_status,
        campaign_objective,
        spend,
        impressions,
        clicks,
        reach,
        total_actions,
        total_action_value,
        ctr_percent,
        avg_cpc,
        frequency,
        roas
    FROM [dbo].[vw_facebook_campaign_performance]
)
SELECT 
    cdm.campaign_id,
    cdm.date,
    cdm.campaign_name,
    cdm.campaign_status,
    cdm.campaign_objective,
    
    -- Current day metrics
    cdm.spend,
    cdm.impressions,
    cdm.clicks,
    cdm.reach,
    cdm.total_actions,
    cdm.total_action_value,
    cdm.ctr_percent,
    cdm.avg_cpc,
    cdm.frequency,
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
    AVG(cdm.reach) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS reach_7day_ma,
    AVG(cdm.total_actions) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS actions_7day_ma,
    AVG(cdm.ctr_percent) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS ctr_7day_ma,
    AVG(cdm.frequency) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS frequency_7day_ma,
    
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
    AVG(cdm.total_actions) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS actions_30day_ma,
    
    -- Week over Week comparison
    LAG(cdm.spend, 7) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date
    ) AS spend_last_week,
    LAG(cdm.reach, 7) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date
    ) AS reach_last_week,
    LAG(cdm.total_actions, 7) OVER (
        PARTITION BY cdm.campaign_id 
        ORDER BY cdm.date
    ) AS actions_last_week,
    
    -- Week over Week change percentage
    CASE 
        WHEN LAG(cdm.spend, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date) > 0 
        THEN CAST(((cdm.spend - LAG(cdm.spend, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) * 100.0 
             / LAG(cdm.spend, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) AS DECIMAL(10, 2))
        ELSE NULL 
    END AS spend_wow_change_percent,
    
    CASE 
        WHEN LAG(cdm.reach, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date) > 0 
        THEN CAST(((cdm.reach - LAG(cdm.reach, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) * 100.0 
             / LAG(cdm.reach, 7) OVER (PARTITION BY cdm.campaign_id ORDER BY cdm.date)) AS DECIMAL(10, 2))
        ELSE NULL 
    END AS reach_wow_change_percent,
    
    -- Cumulative metrics for the period
    SUM(cdm.spend) OVER (
        PARTITION BY cdm.campaign_id, YEAR(cdm.date), MONTH(cdm.date) 
        ORDER BY cdm.date
    ) AS mtd_spend,
    SUM(cdm.total_actions) OVER (
        PARTITION BY cdm.campaign_id, YEAR(cdm.date), MONTH(cdm.date) 
        ORDER BY cdm.date
    ) AS mtd_actions,
    
    -- Rank campaigns by daily performance
    DENSE_RANK() OVER (
        PARTITION BY cdm.date 
        ORDER BY cdm.spend DESC
    ) AS daily_spend_rank,
    DENSE_RANK() OVER (
        PARTITION BY cdm.date 
        ORDER BY cdm.total_actions DESC
    ) AS daily_actions_rank,
    DENSE_RANK() OVER (
        PARTITION BY cdm.date 
        ORDER BY cdm.reach DESC
    ) AS daily_reach_rank

FROM CampaignDailyMetrics cdm;
GO

/*
================================================================================
VIEW: vw_facebook_campaign_performance_summary
DESCRIPTION: Aggregated Facebook campaign performance summary for dashboard cards
             and KPI displays.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_campaign_performance_summary]
AS
SELECT 
    cp.campaign_id,
    cp.campaign_name,
    cp.campaign_status,
    cp.campaign_objective,
    cp.account_name,
    cp.currency_code,
    
    -- Aggregated metrics (last 30 days)
    SUM(cp.spend) AS total_spend,
    SUM(cp.impressions) AS total_impressions,
    SUM(cp.clicks) AS total_clicks,
    SUM(cp.reach) AS total_reach,
    SUM(cp.link_clicks) AS total_link_clicks,
    SUM(cp.total_actions) AS total_actions,
    SUM(cp.total_action_value) AS total_action_value,
    
    -- Calculated Frequency (overall for period)
    CASE WHEN SUM(cp.reach) > 0 
         THEN CAST((SUM(cp.impressions) * 1.0 / SUM(cp.reach)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_frequency,
    
    -- Calculated KPIs
    CASE WHEN SUM(cp.impressions) > 0 
         THEN CAST((SUM(cp.clicks) * 100.0 / SUM(cp.impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(cp.clicks) > 0 
         THEN CAST((SUM(cp.spend) / SUM(cp.clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(cp.link_clicks) > 0 
         THEN CAST((SUM(cp.spend) / SUM(cp.link_clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_link_click,
    CASE WHEN SUM(cp.total_actions) > 0 
         THEN CAST((SUM(cp.spend) / SUM(cp.total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_action,
    CASE WHEN SUM(cp.spend) > 0 
         THEN CAST((SUM(cp.total_action_value) / SUM(cp.spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    CASE WHEN SUM(cp.reach) > 0 
         THEN CAST((SUM(cp.spend) * 1000.0 / SUM(cp.reach)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpp,
    
    -- Date range
    MIN(cp.date) AS first_date,
    MAX(cp.date) AS last_date,
    COUNT(DISTINCT cp.date) AS active_days

FROM [dbo].[vw_facebook_campaign_performance] cp
WHERE cp.date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY 
    cp.campaign_id,
    cp.campaign_name,
    cp.campaign_status,
    cp.campaign_objective,
    cp.account_name,
    cp.currency_code;
GO

/*
================================================================================
VIEW: vw_facebook_campaign_objective_analysis
DESCRIPTION: Campaign performance analysis grouped by objective type.
             Helps compare performance across different campaign objectives.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_campaign_objective_analysis]
AS
SELECT 
    campaign_objective,
    account_name,
    
    -- Counts
    COUNT(DISTINCT campaign_id) AS campaign_count,
    
    -- Aggregated metrics
    SUM(total_spend) AS total_spend,
    SUM(total_impressions) AS total_impressions,
    SUM(total_clicks) AS total_clicks,
    SUM(total_reach) AS total_reach,
    SUM(total_link_clicks) AS total_link_clicks,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- Average metrics per campaign
    CAST(SUM(total_spend) / NULLIF(COUNT(DISTINCT campaign_id), 0) AS DECIMAL(18, 2)) AS avg_spend_per_campaign,
    CAST(SUM(total_actions) / NULLIF(COUNT(DISTINCT campaign_id), 0) AS DECIMAL(10, 2)) AS avg_actions_per_campaign,
    
    -- KPIs
    CASE WHEN SUM(total_impressions) > 0 
         THEN CAST((SUM(total_clicks) * 100.0 / SUM(total_impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS ctr_percent,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS cost_per_action,
    CASE WHEN SUM(total_spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(total_spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS roas,
    CASE WHEN SUM(total_reach) > 0 
         THEN CAST((SUM(total_impressions) * 1.0 / SUM(total_reach)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_frequency,
    
    -- Percentage of total
    CAST((SUM(total_spend) * 100.0 / 
          NULLIF(SUM(SUM(total_spend)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_spend,
    CAST((SUM(total_actions) * 100.0 / 
          NULLIF(SUM(SUM(total_actions)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_actions

FROM [dbo].[vw_facebook_campaign_performance_summary]
GROUP BY 
    campaign_objective,
    account_name;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily Facebook campaign-level performance metrics with calculated KPIs including reach and frequency.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_campaign_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook campaign performance with trend analysis including moving averages and period comparisons.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_campaign_trend_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Aggregated Facebook campaign performance summary for dashboard displays.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_campaign_performance_summary';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook campaign performance analysis grouped by campaign objective.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_campaign_objective_analysis';
GO
