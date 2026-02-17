/*
================================================================================
VIEW: vw_facebook_adset_performance
DESCRIPTION: Ad Set-level performance metrics including audience targeting effectiveness.
             Ad Sets in Facebook define targeting, budget, and schedule settings.
             Provides hierarchical data from Account > Campaign > Ad Set.
SCHEMA TABLES:
  - facebook_ads.basic_ad: Daily ad-level performance metrics aggregated to ad set
    Columns: ad_id, adset_id, campaign_id, account_id, date, spend, impressions, 
             clicks, reach, frequency, actions, action_values, inline_link_clicks,
             unique_clicks, _fivetran_synced
  - facebook_ads.adset_history: Ad Set metadata with change history
    Columns: adset_id, campaign_id, account_id, name, status, targeting, 
             optimization_goal, billing_event, bid_amount, daily_budget,
             lifetime_budget, start_time, end_time, _fivetran_synced, _fivetran_deleted
  - facebook_ads.campaign_history: Campaign metadata with change history
    Columns: campaign_id, name, status, objective, _fivetran_synced
  - facebook_ads.account_history: Account metadata with change history
    Columns: account_id, name, currency, _fivetran_synced
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_adset_performance]
AS
SELECT 
    -- Dimension Keys (for drill-down)
    ads.adset_id,
    ads.campaign_id,
    ads.account_id,
    ads.date,
    CONVERT(INT, FORMAT(ads.date, 'yyyyMMdd')) AS date_id,
    
    -- Ad Set Information (from history table - latest values)
    adsh.name AS adset_name,
    adsh.status AS adset_status,
    adsh.optimization_goal,
    adsh.billing_event,
    adsh.bid_amount,
    adsh.targeting AS targeting_spec,
    adsh.start_time AS adset_start_time,
    adsh.end_time AS adset_end_time,
    
    -- Budget Information
    adsh.daily_budget AS adset_daily_budget,
    adsh.lifetime_budget AS adset_lifetime_budget,
    
    -- Campaign Information (for drill-down context)
    ch.name AS campaign_name,
    ch.status AS campaign_status,
    ch.objective AS campaign_objective,
    
    -- Account Information
    ah.name AS account_name,
    ah.currency AS currency_code,
    
    -- Raw Metrics
    CAST(ads.spend AS DECIMAL(18, 2)) AS spend,
    ads.impressions,
    ads.clicks,
    ads.reach,
    ads.unique_clicks,
    
    -- Frequency (impressions per reach)
    CASE 
        WHEN ads.reach > 0 
        THEN CAST((ads.impressions * 1.0 / ads.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS frequency,
    
    -- Action Metrics
    COALESCE(ads.inline_link_clicks, 0) AS link_clicks,
    COALESCE(ads.actions, 0) AS total_actions,
    COALESCE(ads.action_values, 0) AS total_action_value,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN ads.impressions > 0 
        THEN CAST((ads.clicks * 100.0 / ads.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Unique CTR
    CASE 
        WHEN ads.reach > 0 
        THEN CAST((ads.unique_clicks * 100.0 / ads.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS unique_ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN ads.clicks > 0 
        THEN CAST((ads.spend / ads.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Cost Per Link Click
    CASE 
        WHEN COALESCE(ads.inline_link_clicks, 0) > 0 
        THEN CAST((ads.spend / ads.inline_link_clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_link_click,
    
    -- Calculated Metrics - Cost Per Action (Result)
    CASE 
        WHEN COALESCE(ads.actions, 0) > 0 
        THEN CAST((ads.spend / ads.actions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_action,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN ads.spend > 0 
        THEN CAST((COALESCE(ads.action_values, 0) / ads.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Calculated Metrics - Average CPM
    CASE 
        WHEN ads.impressions > 0 
        THEN CAST((ads.spend * 1000.0 / ads.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- Calculated Metrics - Cost Per 1000 People Reached (CPP)
    CASE 
        WHEN ads.reach > 0 
        THEN CAST((ads.spend * 1000.0 / ads.reach) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cpp,
    
    -- Budget Utilization (daily)
    CASE 
        WHEN adsh.daily_budget > 0 
        THEN CAST((ads.spend * 100.0 / adsh.daily_budget) AS DECIMAL(10, 2))
        ELSE 0 
    END AS budget_utilization_percent,
    
    -- Bid vs Actual CPA comparison
    CASE 
        WHEN COALESCE(ads.actions, 0) > 0 AND adsh.bid_amount > 0
        THEN CAST(((ads.spend / ads.actions) - adsh.bid_amount) AS DECIMAL(18, 4))
        ELSE NULL 
    END AS cpa_vs_bid_variance,
    
    -- Metadata
    ads._fivetran_synced AS last_synced_at

FROM (
    -- Aggregate basic_ad to ad set level
    SELECT 
        adset_id,
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
    GROUP BY adset_id, campaign_id, account_id, date
) ads
LEFT JOIN (
    SELECT 
        adset_id,
        campaign_id,
        account_id,
        name,
        status,
        targeting,
        optimization_goal,
        billing_event,
        bid_amount,
        daily_budget,
        lifetime_budget,
        start_time,
        end_time,
        ROW_NUMBER() OVER (PARTITION BY adset_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.adset_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) adsh ON ads.adset_id = adsh.adset_id AND adsh.rn = 1
LEFT JOIN (
    SELECT 
        campaign_id,
        name,
        status,
        objective,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.campaign_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ch ON ads.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT 
        account_id,
        name,
        currency,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.account_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ah ON ads.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_facebook_adset_drilldown
DESCRIPTION: Hierarchical ad set view optimized for drill-down from 
             Campaign to Ad Set in PowerBI visuals.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_adset_drilldown]
AS
WITH AdSetAggregated AS (
    SELECT 
        account_id,
        account_name,
        campaign_id,
        campaign_name,
        campaign_status,
        campaign_objective,
        adset_id,
        adset_name,
        adset_status,
        optimization_goal,
        currency_code,
        
        -- Aggregated metrics
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(reach) AS total_reach,
        SUM(link_clicks) AS total_link_clicks,
        SUM(total_actions) AS total_actions,
        SUM(total_action_value) AS total_action_value,
        
        -- Date range
        MIN(date) AS first_date,
        MAX(date) AS last_date,
        COUNT(DISTINCT date) AS active_days
    FROM [dbo].[vw_facebook_adset_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        account_id,
        account_name,
        campaign_id,
        campaign_name,
        campaign_status,
        campaign_objective,
        adset_id,
        adset_name,
        adset_status,
        optimization_goal,
        currency_code
)
SELECT 
    -- Hierarchy path for drill-down
    CONCAT(account_name, ' > ', campaign_name, ' > ', adset_name) AS full_hierarchy_path,
    
    -- Dimensions
    account_id,
    account_name,
    campaign_id,
    campaign_name,
    campaign_status,
    campaign_objective,
    adset_id,
    adset_name,
    adset_status,
    optimization_goal,
    currency_code,
    
    -- Metrics
    total_spend,
    total_impressions,
    total_clicks,
    total_reach,
    total_link_clicks,
    total_actions,
    total_action_value,
    
    -- Frequency
    CASE WHEN total_reach > 0 
         THEN CAST((total_impressions * 1.0 / total_reach) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_frequency,
    
    -- Calculated KPIs
    CASE WHEN total_impressions > 0 
         THEN CAST((total_clicks * 100.0 / total_impressions) AS DECIMAL(10, 4)) 
         ELSE 0 END AS ctr_percent,
    CASE WHEN total_clicks > 0 
         THEN CAST((total_spend / total_clicks) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN total_actions > 0 
         THEN CAST((total_spend / total_actions) AS DECIMAL(18, 4)) 
         ELSE 0 END AS cost_per_action,
    CASE WHEN total_spend > 0 
         THEN CAST((total_action_value / total_spend) AS DECIMAL(10, 4)) 
         ELSE 0 END AS roas,
    
    -- Percentage of campaign metrics
    CAST((total_spend * 100.0 / 
          NULLIF(SUM(total_spend) OVER (PARTITION BY campaign_id), 0)) AS DECIMAL(10, 2)) 
          AS pct_of_campaign_spend,
    CAST((total_clicks * 100.0 / 
          NULLIF(SUM(total_clicks) OVER (PARTITION BY campaign_id), 0)) AS DECIMAL(10, 2)) 
          AS pct_of_campaign_clicks,
    CAST((total_reach * 100.0 / 
          NULLIF(SUM(total_reach) OVER (PARTITION BY campaign_id), 0)) AS DECIMAL(10, 2)) 
          AS pct_of_campaign_reach,
    CAST((total_actions * 100.0 / 
          NULLIF(SUM(total_actions) OVER (PARTITION BY campaign_id), 0)) AS DECIMAL(10, 2)) 
          AS pct_of_campaign_actions,
    
    -- Rank within campaign
    DENSE_RANK() OVER (PARTITION BY campaign_id ORDER BY total_spend DESC) AS spend_rank_in_campaign,
    DENSE_RANK() OVER (PARTITION BY campaign_id ORDER BY total_actions DESC) AS actions_rank_in_campaign,
    DENSE_RANK() OVER (PARTITION BY campaign_id ORDER BY total_reach DESC) AS reach_rank_in_campaign,
    
    -- Performance indicators (targeting effectiveness)
    CASE 
        WHEN total_actions > 0 AND (total_spend / total_actions) < 
             AVG(CASE WHEN total_actions > 0 THEN total_spend / total_actions END) 
             OVER (PARTITION BY campaign_id)
        THEN 'Above Average (Efficient Targeting)'
        WHEN total_actions > 0 
        THEN 'Below Average'
        ELSE 'No Actions'
    END AS targeting_effectiveness,
    
    -- Frequency health indicator
    CASE 
        WHEN total_reach > 0 AND (total_impressions * 1.0 / total_reach) > 10
        THEN 'High Frequency - Consider expanding audience'
        WHEN total_reach > 0 AND (total_impressions * 1.0 / total_reach) > 5
        THEN 'Moderate Frequency - Monitor for fatigue'
        WHEN total_reach > 0 
        THEN 'Healthy Frequency'
        ELSE 'No Reach Data'
    END AS frequency_health,
    
    -- Date range info
    first_date,
    last_date,
    active_days

FROM AdSetAggregated;
GO

/*
================================================================================
VIEW: vw_facebook_adset_performance_summary
DESCRIPTION: Summary view for ad set performance with period comparisons.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_adset_performance_summary]
AS
WITH CurrentPeriod AS (
    SELECT 
        adset_id,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(reach) AS total_reach,
        SUM(total_actions) AS total_actions
    FROM [dbo].[vw_facebook_adset_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
      AND date < CAST(GETDATE() AS DATE)
    GROUP BY adset_id
),
PreviousPeriod AS (
    SELECT 
        adset_id,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(reach) AS total_reach,
        SUM(total_actions) AS total_actions
    FROM [dbo].[vw_facebook_adset_performance]
    WHERE date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
      AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY adset_id
)
SELECT 
    adsp.adset_id,
    adsp.adset_name,
    adsp.adset_status,
    adsp.optimization_goal,
    adsp.campaign_name,
    adsp.account_name,
    
    -- Current period
    cp.total_spend AS current_spend,
    cp.total_impressions AS current_impressions,
    cp.total_clicks AS current_clicks,
    cp.total_reach AS current_reach,
    cp.total_actions AS current_actions,
    
    -- Current period KPIs
    CASE WHEN cp.total_reach > 0 
         THEN CAST((cp.total_impressions * 1.0 / cp.total_reach) AS DECIMAL(10, 4)) 
         ELSE 0 END AS current_frequency,
    
    -- Previous period
    COALESCE(pp.total_spend, 0) AS previous_spend,
    COALESCE(pp.total_reach, 0) AS previous_reach,
    COALESCE(pp.total_actions, 0) AS previous_actions,
    
    -- Change percentages
    CASE WHEN COALESCE(pp.total_spend, 0) > 0 
         THEN CAST(((cp.total_spend - pp.total_spend) * 100.0 / pp.total_spend) AS DECIMAL(10, 2)) 
         ELSE NULL END AS spend_change_percent,
    CASE WHEN COALESCE(pp.total_reach, 0) > 0 
         THEN CAST(((cp.total_reach - pp.total_reach) * 100.0 / pp.total_reach) AS DECIMAL(10, 2)) 
         ELSE NULL END AS reach_change_percent,
    CASE WHEN COALESCE(pp.total_actions, 0) > 0 
         THEN CAST(((cp.total_actions - pp.total_actions) * 100.0 / pp.total_actions) AS DECIMAL(10, 2)) 
         ELSE NULL END AS actions_change_percent

FROM (
    SELECT DISTINCT 
        adset_id, 
        adset_name, 
        adset_status,
        optimization_goal,
        campaign_name,
        account_name
    FROM [dbo].[vw_facebook_adset_performance]
) adsp
INNER JOIN CurrentPeriod cp ON adsp.adset_id = cp.adset_id
LEFT JOIN PreviousPeriod pp ON adsp.adset_id = pp.adset_id;
GO

/*
================================================================================
VIEW: vw_facebook_adset_optimization_goal_analysis
DESCRIPTION: Ad Set performance analysis grouped by optimization goal.
             Helps compare targeting effectiveness across different goals.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_adset_optimization_goal_analysis]
AS
SELECT 
    optimization_goal,
    campaign_objective,
    
    -- Counts
    COUNT(DISTINCT adset_id) AS adset_count,
    
    -- Aggregated metrics
    SUM(total_spend) AS total_spend,
    SUM(total_impressions) AS total_impressions,
    SUM(total_clicks) AS total_clicks,
    SUM(total_reach) AS total_reach,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- KPIs
    CASE WHEN SUM(total_impressions) > 0 
         THEN CAST((SUM(total_clicks) * 100.0 / SUM(total_impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_action,
    CASE WHEN SUM(total_spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(total_spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    CASE WHEN SUM(total_reach) > 0 
         THEN CAST((SUM(total_impressions) * 1.0 / SUM(total_reach)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_frequency

FROM [dbo].[vw_facebook_adset_drilldown]
GROUP BY 
    optimization_goal,
    campaign_objective;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily Facebook Ad Set-level performance metrics with targeting and optimization context.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_adset_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Hierarchical Facebook Ad Set view optimized for drill-down functionality in PowerBI.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_adset_drilldown';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook Ad Set performance summary with 30-day period comparisons.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_adset_performance_summary';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook Ad Set performance grouped by optimization goal.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_adset_optimization_goal_analysis';
GO
