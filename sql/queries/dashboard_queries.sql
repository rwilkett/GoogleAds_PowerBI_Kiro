/*
================================================================================
QUERY: qry_executive_dashboard_metrics
DESCRIPTION: Executive summary metrics for high-level dashboard displays.
             Provides overall account health and key performance indicators.
================================================================================
*/

-- Overall Account Performance Summary
SELECT 
    account_name,
    currency_code,
    
    -- Current Period (Last 30 Days)
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN spend ELSE 0 END) AS current_spend,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN impressions ELSE 0 END) AS current_impressions,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN clicks ELSE 0 END) AS current_clicks,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN conversions ELSE 0 END) AS current_conversions,
    SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN conversions_value ELSE 0 END) AS current_revenue,
    
    -- Previous Period (30-60 Days Ago)
    SUM(CASE WHEN date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE)) 
              AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN spend ELSE 0 END) AS previous_spend,
    SUM(CASE WHEN date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE)) 
              AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
             THEN conversions ELSE 0 END) AS previous_conversions,
    
    -- Period over Period Change %
    CASE WHEN SUM(CASE WHEN date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE)) 
                        AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
                       THEN spend ELSE 0 END) > 0
         THEN CAST((
             (SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN spend ELSE 0 END) -
              SUM(CASE WHEN date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE)) 
                        AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN spend ELSE 0 END))
             * 100.0 / 
             SUM(CASE WHEN date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE)) 
                       AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN spend ELSE 0 END)
         ) AS DECIMAL(10,2))
         ELSE NULL 
    END AS spend_change_pct,
    
    -- Calculated KPIs (Current Period)
    CASE WHEN SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
                       THEN impressions ELSE 0 END) > 0
         THEN CAST((
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN clicks ELSE 0 END) * 100.0 /
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN impressions ELSE 0 END)
         ) AS DECIMAL(10,4))
         ELSE 0 
    END AS current_ctr,
    
    CASE WHEN SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
                       THEN clicks ELSE 0 END) > 0
         THEN CAST((
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN spend ELSE 0 END) /
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN clicks ELSE 0 END)
         ) AS DECIMAL(18,4))
         ELSE 0 
    END AS current_cpc,
    
    CASE WHEN SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
                       THEN clicks ELSE 0 END) > 0
         THEN CAST((
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN conversions ELSE 0 END) * 100.0 /
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN clicks ELSE 0 END)
         ) AS DECIMAL(10,4))
         ELSE 0 
    END AS current_conversion_rate,
    
    CASE WHEN SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
                       THEN spend ELSE 0 END) > 0
         THEN CAST((
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN conversions_value ELSE 0 END) /
             SUM(CASE WHEN date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN spend ELSE 0 END)
         ) AS DECIMAL(10,4))
         ELSE 0 
    END AS current_roas

FROM [dbo].[vw_account_performance]
WHERE date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
GROUP BY account_name, currency_code;
GO

/*
================================================================================
QUERY: qry_daily_trend_analysis
DESCRIPTION: Daily trend data for line charts and time series analysis.
             Supports date range filtering in PowerBI.
================================================================================
*/

-- Daily metrics trend (parametrized for PowerBI)
SELECT 
    d.date,
    d.day_name,
    d.week_of_year,
    d.month_name,
    d.year_month,
    
    -- Account level aggregation
    COALESCE(SUM(a.spend), 0) AS daily_spend,
    COALESCE(SUM(a.impressions), 0) AS daily_impressions,
    COALESCE(SUM(a.clicks), 0) AS daily_clicks,
    COALESCE(SUM(a.conversions), 0) AS daily_conversions,
    COALESCE(SUM(a.conversions_value), 0) AS daily_revenue,
    
    -- Daily KPIs
    CASE WHEN COALESCE(SUM(a.impressions), 0) > 0 
         THEN CAST((SUM(a.clicks) * 100.0 / SUM(a.impressions)) AS DECIMAL(10,4)) 
         ELSE 0 END AS daily_ctr,
    CASE WHEN COALESCE(SUM(a.clicks), 0) > 0 
         THEN CAST((SUM(a.spend) / SUM(a.clicks)) AS DECIMAL(18,4)) 
         ELSE 0 END AS daily_cpc,
    CASE WHEN COALESCE(SUM(a.clicks), 0) > 0 
         THEN CAST((SUM(a.conversions) * 100.0 / SUM(a.clicks)) AS DECIMAL(10,4)) 
         ELSE 0 END AS daily_conversion_rate,
    
    -- Running totals
    SUM(SUM(a.spend)) OVER (ORDER BY d.date ROWS UNBOUNDED PRECEDING) AS cumulative_spend,
    SUM(SUM(a.conversions)) OVER (ORDER BY d.date ROWS UNBOUNDED PRECEDING) AS cumulative_conversions

FROM [dbo].[vw_date_dimension] d
LEFT JOIN [dbo].[vw_account_performance] a ON d.date = a.date
WHERE d.date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
  AND d.date < CAST(GETDATE() AS DATE)
GROUP BY 
    d.date,
    d.day_name,
    d.week_of_year,
    d.month_name,
    d.year_month
ORDER BY d.date;
GO

/*
================================================================================
QUERY: qry_campaign_performance_matrix
DESCRIPTION: Campaign comparison matrix for identifying top/bottom performers.
             Useful for scatter plots and performance quadrant analysis.
================================================================================
*/

SELECT 
    campaign_name,
    campaign_status,
    advertising_channel_type,
    
    -- Core metrics
    total_spend,
    total_clicks,
    total_conversions,
    total_conversions_value,
    
    -- KPIs
    ctr_percent,
    avg_cpc,
    conversion_rate_percent,
    cost_per_conversion,
    roas,
    
    -- Efficiency score (composite metric)
    CASE 
        WHEN total_conversions > 0 AND total_spend > 0
        THEN CAST((
            (conversion_rate_percent / NULLIF(AVG(conversion_rate_percent) OVER (), 0)) +
            (roas / NULLIF(AVG(roas) OVER (), 0)) +
            ((1 - cost_per_conversion / NULLIF(AVG(cost_per_conversion) OVER (), 1)))
        ) / 3 * 100 AS DECIMAL(10,2))
        ELSE 0 
    END AS efficiency_score,
    
    -- Quadrant classification (for scatter plot visualization)
    CASE 
        WHEN conversion_rate_percent >= AVG(conversion_rate_percent) OVER () 
         AND roas >= AVG(roas) OVER ()
        THEN 'Stars (High CVR, High ROAS)'
        WHEN conversion_rate_percent >= AVG(conversion_rate_percent) OVER () 
         AND roas < AVG(roas) OVER ()
        THEN 'Question Marks (High CVR, Low ROAS)'
        WHEN conversion_rate_percent < AVG(conversion_rate_percent) OVER () 
         AND roas >= AVG(roas) OVER ()
        THEN 'Cash Cows (Low CVR, High ROAS)'
        ELSE 'Dogs (Low CVR, Low ROAS)'
    END AS performance_quadrant,
    
    -- Percentile rankings
    PERCENT_RANK() OVER (ORDER BY total_conversions) AS conversions_percentile,
    PERCENT_RANK() OVER (ORDER BY roas) AS roas_percentile,
    PERCENT_RANK() OVER (ORDER BY cost_per_conversion DESC) AS efficiency_percentile

FROM (
    SELECT 
        campaign_name,
        campaign_status,
        advertising_channel_type,
        SUM(spend) AS total_spend,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value,
        CASE WHEN SUM(impressions) > 0 
             THEN CAST((SUM(clicks) * 100.0 / SUM(impressions)) AS DECIMAL(10,4)) 
             ELSE 0 END AS ctr_percent,
        CASE WHEN SUM(clicks) > 0 
             THEN CAST((SUM(spend) / SUM(clicks)) AS DECIMAL(18,4)) 
             ELSE 0 END AS avg_cpc,
        CASE WHEN SUM(clicks) > 0 
             THEN CAST((SUM(conversions) * 100.0 / SUM(clicks)) AS DECIMAL(10,4)) 
             ELSE 0 END AS conversion_rate_percent,
        CASE WHEN SUM(conversions) > 0 
             THEN CAST((SUM(spend) / SUM(conversions)) AS DECIMAL(18,4)) 
             ELSE 999999 END AS cost_per_conversion,
        CASE WHEN SUM(spend) > 0 
             THEN CAST((SUM(conversions_value) / SUM(spend)) AS DECIMAL(10,4)) 
             ELSE 0 END AS roas
    FROM [dbo].[vw_campaign_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY campaign_name, campaign_status, advertising_channel_type
) campaigns
WHERE total_spend > 0;
GO

/*
================================================================================
QUERY: qry_budget_pacing
DESCRIPTION: Budget utilization and pacing analysis for campaigns.
             Helps identify over/under-spending campaigns.
================================================================================
*/

WITH DailyBudget AS (
    SELECT 
        campaign_id,
        campaign_name,
        budget_amount AS daily_budget,
        date,
        spend,
        impressions,
        clicks,
        conversions
    FROM [dbo].[vw_campaign_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
      AND budget_amount > 0
)
SELECT 
    campaign_name,
    daily_budget,
    
    -- Monthly budget (assuming daily budget)
    daily_budget * 30.4 AS estimated_monthly_budget,
    
    -- Actual spending
    SUM(spend) AS total_spend_30d,
    AVG(spend) AS avg_daily_spend,
    
    -- Budget utilization
    CAST((SUM(spend) / (daily_budget * COUNT(DISTINCT date))) * 100 AS DECIMAL(10,2)) AS budget_utilization_pct,
    
    -- Days data
    COUNT(DISTINCT date) AS days_with_data,
    COUNT(CASE WHEN spend >= daily_budget * 0.9 THEN 1 END) AS days_near_budget,
    COUNT(CASE WHEN spend >= daily_budget THEN 1 END) AS days_at_or_over_budget,
    COUNT(CASE WHEN spend < daily_budget * 0.5 THEN 1 END) AS days_underspending,
    
    -- Performance at different spend levels
    AVG(CASE WHEN spend >= daily_budget * 0.9 THEN conversions END) AS avg_conversions_high_spend,
    AVG(CASE WHEN spend < daily_budget * 0.5 THEN conversions END) AS avg_conversions_low_spend,
    
    -- Recommendation
    CASE 
        WHEN CAST((SUM(spend) / (daily_budget * COUNT(DISTINCT date))) * 100 AS DECIMAL(10,2)) > 95
        THEN 'Consider increasing budget'
        WHEN CAST((SUM(spend) / (daily_budget * COUNT(DISTINCT date))) * 100 AS DECIMAL(10,2)) < 50
        THEN 'Budget underutilized - check targeting/bids'
        ELSE 'Budget pacing is healthy'
    END AS budget_recommendation

FROM DailyBudget
GROUP BY campaign_name, daily_budget
ORDER BY budget_utilization_pct DESC;
GO

/*
================================================================================
QUERY: qry_conversion_funnel
DESCRIPTION: Conversion funnel analysis showing drop-off rates at each stage.
             Useful for identifying optimization opportunities.
================================================================================
*/

SELECT 
    account_name,
    campaign_name,
    
    -- Funnel stages
    SUM(impressions) AS stage_1_impressions,
    SUM(clicks) AS stage_2_clicks,
    SUM(conversions) AS stage_3_conversions,
    
    -- Drop-off rates
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((1 - (SUM(clicks) * 1.0 / SUM(impressions))) * 100 AS DECIMAL(10,2))
         ELSE 0 END AS impressions_to_clicks_dropoff_pct,
    CASE WHEN SUM(clicks) > 0 
         THEN CAST((1 - (SUM(conversions) * 1.0 / SUM(clicks))) * 100 AS DECIMAL(10,2))
         ELSE 0 END AS clicks_to_conversions_dropoff_pct,
    
    -- Overall funnel conversion
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(conversions) * 100.0 / SUM(impressions)) AS DECIMAL(10,6))
         ELSE 0 END AS overall_conversion_rate_pct,
    
    -- Value metrics
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(conversions_value) / SUM(impressions) * 1000) AS DECIMAL(18,4))
         ELSE 0 END AS value_per_1000_impressions,
    CASE WHEN SUM(clicks) > 0 
         THEN CAST((SUM(conversions_value) / SUM(clicks)) AS DECIMAL(18,4))
         ELSE 0 END AS value_per_click

FROM [dbo].[vw_campaign_performance]
WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY account_name, campaign_name
HAVING SUM(impressions) > 0
ORDER BY SUM(spend) DESC;
GO
