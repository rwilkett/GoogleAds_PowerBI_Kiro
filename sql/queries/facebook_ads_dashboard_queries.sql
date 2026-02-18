/*
================================================================================
Facebook Ads Dashboard Queries
DESCRIPTION: SQL queries for Facebook Ads PowerBI dashboard analytics.
             Updated to use only columns available in the documented schema.
================================================================================
*/

-- Executive Dashboard Metrics (Last 30 Days)
SELECT 
    account_name,
    currency_code,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN spend ELSE 0 END) AS current_spend,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN impressions ELSE 0 END) AS current_impressions,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN reach ELSE 0 END) AS current_reach,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN total_actions ELSE 0 END) AS current_actions
FROM [dbo].[vw_facebook_account_performance]
WHERE date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
GROUP BY account_name, currency_code;
GO

-- Daily Trend Analysis
SELECT 
    date, DATENAME(WEEKDAY, date) AS day_name,
    SUM(spend) AS daily_spend, SUM(impressions) AS daily_impressions,
    SUM(reach) AS daily_reach, SUM(total_actions) AS daily_actions,
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(clicks) * 100.0 / SUM(impressions)) AS DECIMAL(10,4)) 
         ELSE 0 END AS daily_ctr
FROM [dbo].[vw_facebook_account_performance]
WHERE date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY date ORDER BY date;
GO

-- Campaign Performance Matrix
SELECT campaign_name, campaign_status, campaign_objective,
    total_spend, total_reach, total_actions, total_action_value,
    avg_ctr, avg_cpc, avg_cost_per_action, avg_roas, avg_frequency
FROM [dbo].[vw_facebook_campaign_performance_summary]
WHERE total_spend > 0;
GO

-- Ad Set Performance Overview
SELECT adset_name, campaign_name, optimization_goal,
    total_spend, total_reach, total_actions,
    avg_frequency, ctr_percent, cost_per_action, roas
FROM [dbo].[vw_facebook_adset_drilldown]
WHERE total_spend > 0;
GO

-- Creative Performance Analysis
SELECT ad_name, creative_type_label, call_to_action_type,
    total_spend, total_clicks, total_actions, ctr_percent,
    cost_per_action, roas
FROM [dbo].[vw_facebook_ad_creative_effectiveness]
WHERE total_impressions > 100;
GO

-- Note: Demographic and Placement queries require optional breakdown columns
-- Uncomment if your Fivetran connector includes demographic/placement breakdowns
/*
-- Demographic Performance Summary
SELECT age_range, gender, total_spend, total_actions,
    avg_ctr, avg_cost_per_action, avg_roas, cost_efficiency_rank
FROM [dbo].[vw_facebook_demographic_summary];
GO

-- Placement Performance Summary
SELECT publisher_platform, platform_position, total_spend,
    total_impressions, total_actions, avg_ctr, avg_cpm,
    avg_cost_per_action, placement_recommendation
FROM [dbo].[vw_facebook_placement_summary];
GO
*/
