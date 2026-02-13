/*
================================================================================
QUERY: qry_woy_wow_comparison
DESCRIPTION: Week-over-Week and Year-over-Year comparison metrics.
             Enables time period comparison in PowerBI slicers.
================================================================================
*/

-- Weekly comparison data
WITH WeeklyMetrics AS (
    SELECT 
        d.year,
        d.week_of_year,
        d.week_start_date,
        d.week_end_date,
        a.account_name,
        
        SUM(a.spend) AS weekly_spend,
        SUM(a.impressions) AS weekly_impressions,
        SUM(a.clicks) AS weekly_clicks,
        SUM(a.conversions) AS weekly_conversions,
        SUM(a.conversions_value) AS weekly_revenue
    FROM [dbo].[vw_date_dimension] d
    INNER JOIN [dbo].[vw_account_performance] a ON d.date = a.date
    WHERE d.date >= DATEADD(WEEK, -12, CAST(GETDATE() AS DATE))
    GROUP BY 
        d.year,
        d.week_of_year,
        d.week_start_date,
        d.week_end_date,
        a.account_name
)
SELECT 
    wm.year,
    wm.week_of_year,
    wm.week_start_date,
    wm.week_end_date,
    wm.account_name,
    
    -- Current week metrics
    wm.weekly_spend,
    wm.weekly_impressions,
    wm.weekly_clicks,
    wm.weekly_conversions,
    wm.weekly_revenue,
    
    -- Previous week metrics
    LAG(wm.weekly_spend, 1) OVER (
        PARTITION BY wm.account_name 
        ORDER BY wm.year, wm.week_of_year
    ) AS previous_week_spend,
    LAG(wm.weekly_conversions, 1) OVER (
        PARTITION BY wm.account_name 
        ORDER BY wm.year, wm.week_of_year
    ) AS previous_week_conversions,
    
    -- Same week last year
    LAG(wm.weekly_spend, 52) OVER (
        PARTITION BY wm.account_name 
        ORDER BY wm.year, wm.week_of_year
    ) AS same_week_ly_spend,
    LAG(wm.weekly_conversions, 52) OVER (
        PARTITION BY wm.account_name 
        ORDER BY wm.year, wm.week_of_year
    ) AS same_week_ly_conversions,
    
    -- WoW change %
    CASE 
        WHEN LAG(wm.weekly_spend, 1) OVER (
                 PARTITION BY wm.account_name ORDER BY wm.year, wm.week_of_year) > 0
        THEN CAST(((wm.weekly_spend - LAG(wm.weekly_spend, 1) OVER (
                        PARTITION BY wm.account_name ORDER BY wm.year, wm.week_of_year)) 
                   * 100.0 / LAG(wm.weekly_spend, 1) OVER (
                        PARTITION BY wm.account_name ORDER BY wm.year, wm.week_of_year)
                  ) AS DECIMAL(10,2))
        ELSE NULL 
    END AS spend_wow_change_pct,
    
    CASE 
        WHEN LAG(wm.weekly_conversions, 1) OVER (
                 PARTITION BY wm.account_name ORDER BY wm.year, wm.week_of_year) > 0
        THEN CAST(((wm.weekly_conversions - LAG(wm.weekly_conversions, 1) OVER (
                        PARTITION BY wm.account_name ORDER BY wm.year, wm.week_of_year)) 
                   * 100.0 / LAG(wm.weekly_conversions, 1) OVER (
                        PARTITION BY wm.account_name ORDER BY wm.year, wm.week_of_year)
                  ) AS DECIMAL(10,2))
        ELSE NULL 
    END AS conversions_wow_change_pct,
    
    -- Calculated KPIs
    CASE WHEN wm.weekly_impressions > 0 
         THEN CAST((wm.weekly_clicks * 100.0 / wm.weekly_impressions) AS DECIMAL(10,4)) 
         ELSE 0 END AS weekly_ctr,
    CASE WHEN wm.weekly_clicks > 0 
         THEN CAST((wm.weekly_spend / wm.weekly_clicks) AS DECIMAL(18,4)) 
         ELSE 0 END AS weekly_cpc,
    CASE WHEN wm.weekly_clicks > 0 
         THEN CAST((wm.weekly_conversions * 100.0 / wm.weekly_clicks) AS DECIMAL(10,4)) 
         ELSE 0 END AS weekly_conversion_rate,
    CASE WHEN wm.weekly_spend > 0 
         THEN CAST((wm.weekly_revenue / wm.weekly_spend) AS DECIMAL(10,4)) 
         ELSE 0 END AS weekly_roas

FROM WeeklyMetrics wm
ORDER BY wm.year DESC, wm.week_of_year DESC;
GO

/*
================================================================================
QUERY: qry_monthly_comparison
DESCRIPTION: Month-over-Month and Year-over-Year monthly comparison.
================================================================================
*/

WITH MonthlyMetrics AS (
    SELECT 
        d.year,
        d.month_number,
        d.month_name,
        d.year_month,
        a.account_name,
        
        SUM(a.spend) AS monthly_spend,
        SUM(a.impressions) AS monthly_impressions,
        SUM(a.clicks) AS monthly_clicks,
        SUM(a.conversions) AS monthly_conversions,
        SUM(a.conversions_value) AS monthly_revenue
    FROM [dbo].[vw_date_dimension] d
    INNER JOIN [dbo].[vw_account_performance] a ON d.date = a.date
    WHERE d.date >= DATEADD(MONTH, -13, CAST(GETDATE() AS DATE))
    GROUP BY 
        d.year,
        d.month_number,
        d.month_name,
        d.year_month,
        a.account_name
)
SELECT 
    mm.year,
    mm.month_number,
    mm.month_name,
    mm.year_month,
    mm.account_name,
    
    -- Current month metrics
    mm.monthly_spend,
    mm.monthly_impressions,
    mm.monthly_clicks,
    mm.monthly_conversions,
    mm.monthly_revenue,
    
    -- Previous month metrics
    LAG(mm.monthly_spend, 1) OVER (
        PARTITION BY mm.account_name 
        ORDER BY mm.year, mm.month_number
    ) AS previous_month_spend,
    LAG(mm.monthly_conversions, 1) OVER (
        PARTITION BY mm.account_name 
        ORDER BY mm.year, mm.month_number
    ) AS previous_month_conversions,
    
    -- Same month last year
    LAG(mm.monthly_spend, 12) OVER (
        PARTITION BY mm.account_name 
        ORDER BY mm.year, mm.month_number
    ) AS same_month_ly_spend,
    LAG(mm.monthly_conversions, 12) OVER (
        PARTITION BY mm.account_name 
        ORDER BY mm.year, mm.month_number
    ) AS same_month_ly_conversions,
    
    -- MoM change %
    CASE 
        WHEN LAG(mm.monthly_spend, 1) OVER (
                 PARTITION BY mm.account_name ORDER BY mm.year, mm.month_number) > 0
        THEN CAST(((mm.monthly_spend - LAG(mm.monthly_spend, 1) OVER (
                        PARTITION BY mm.account_name ORDER BY mm.year, mm.month_number)) 
                   * 100.0 / LAG(mm.monthly_spend, 1) OVER (
                        PARTITION BY mm.account_name ORDER BY mm.year, mm.month_number)
                  ) AS DECIMAL(10,2))
        ELSE NULL 
    END AS spend_mom_change_pct,
    
    -- YoY change %
    CASE 
        WHEN LAG(mm.monthly_spend, 12) OVER (
                 PARTITION BY mm.account_name ORDER BY mm.year, mm.month_number) > 0
        THEN CAST(((mm.monthly_spend - LAG(mm.monthly_spend, 12) OVER (
                        PARTITION BY mm.account_name ORDER BY mm.year, mm.month_number)) 
                   * 100.0 / LAG(mm.monthly_spend, 12) OVER (
                        PARTITION BY mm.account_name ORDER BY mm.year, mm.month_number)
                  ) AS DECIMAL(10,2))
        ELSE NULL 
    END AS spend_yoy_change_pct,
    
    -- KPIs
    CASE WHEN mm.monthly_impressions > 0 
         THEN CAST((mm.monthly_clicks * 100.0 / mm.monthly_impressions) AS DECIMAL(10,4)) 
         ELSE 0 END AS monthly_ctr,
    CASE WHEN mm.monthly_clicks > 0 
         THEN CAST((mm.monthly_spend / mm.monthly_clicks) AS DECIMAL(18,4)) 
         ELSE 0 END AS monthly_cpc,
    CASE WHEN mm.monthly_clicks > 0 
         THEN CAST((mm.monthly_conversions * 100.0 / mm.monthly_clicks) AS DECIMAL(10,4)) 
         ELSE 0 END AS monthly_conversion_rate,
    CASE WHEN mm.monthly_spend > 0 
         THEN CAST((mm.monthly_revenue / mm.monthly_spend) AS DECIMAL(10,4)) 
         ELSE 0 END AS monthly_roas

FROM MonthlyMetrics mm
ORDER BY mm.year DESC, mm.month_number DESC;
GO

/*
================================================================================
QUERY: qry_day_of_week_analysis
DESCRIPTION: Performance analysis by day of week for bid scheduling optimization.
================================================================================
*/

SELECT 
    d.day_name,
    d.day_of_week,
    c.campaign_name,
    c.account_name,
    
    -- Counts
    COUNT(DISTINCT d.date) AS days_in_analysis,
    
    -- Aggregated metrics
    SUM(c.spend) AS total_spend,
    AVG(c.spend) AS avg_daily_spend,
    SUM(c.impressions) AS total_impressions,
    AVG(c.impressions) AS avg_daily_impressions,
    SUM(c.clicks) AS total_clicks,
    AVG(c.clicks) AS avg_daily_clicks,
    SUM(c.conversions) AS total_conversions,
    AVG(c.conversions) AS avg_daily_conversions,
    
    -- KPIs
    CASE WHEN SUM(c.impressions) > 0 
         THEN CAST((SUM(c.clicks) * 100.0 / SUM(c.impressions)) AS DECIMAL(10,4)) 
         ELSE 0 END AS ctr_percent,
    CASE WHEN SUM(c.clicks) > 0 
         THEN CAST((SUM(c.spend) / SUM(c.clicks)) AS DECIMAL(18,4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(c.clicks) > 0 
         THEN CAST((SUM(c.conversions) * 100.0 / SUM(c.clicks)) AS DECIMAL(10,4)) 
         ELSE 0 END AS conversion_rate,
    CASE WHEN SUM(c.conversions) > 0 
         THEN CAST((SUM(c.spend) / SUM(c.conversions)) AS DECIMAL(18,4)) 
         ELSE 0 END AS cost_per_conversion,
    CASE WHEN SUM(c.spend) > 0 
         THEN CAST((SUM(c.conversions_value) / SUM(c.spend)) AS DECIMAL(10,4)) 
         ELSE 0 END AS roas,
    
    -- Day performance indicator
    CASE 
        WHEN SUM(c.conversions) > 0 AND SUM(c.spend) / SUM(c.conversions) < 
             AVG(SUM(c.spend) / NULLIF(SUM(c.conversions), 0)) OVER (PARTITION BY c.campaign_name)
        THEN 'Above Average'
        WHEN SUM(c.conversions) > 0
        THEN 'Below Average'
        ELSE 'No Conversions'
    END AS day_performance

FROM [dbo].[vw_date_dimension] d
INNER JOIN [dbo].[vw_campaign_performance] c ON d.date = c.date
WHERE d.date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY 
    d.day_name,
    d.day_of_week,
    c.campaign_name,
    c.account_name
ORDER BY 
    c.campaign_name,
    d.day_of_week;
GO

/*
================================================================================
QUERY: qry_hour_of_day_analysis (if hourly data available)
DESCRIPTION: Performance analysis by hour for ad scheduling optimization.
NOTE: Requires hourly stats tables if available in Fivetran schema.
================================================================================
*/

-- Placeholder query - adjust based on actual hourly data availability
SELECT 
    'Note: Hour of day analysis requires hourly stats data.' AS message,
    'Check google_ads.campaign_stats_hourly or similar table availability.' AS action_required;
GO
