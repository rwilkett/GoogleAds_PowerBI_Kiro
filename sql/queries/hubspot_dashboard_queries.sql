/*
================================================================================
HUBSPOT DASHBOARD QUERIES
Description: SQL queries for HubSpot CRM analytics dashboard in PowerBI.
             Provides executive summaries, pipeline analysis, engagement metrics,
             and cross-channel performance insights.
================================================================================
*/

/*
================================================================================
QUERY: qry_hubspot_executive_summary
DESCRIPTION: Executive-level KPIs for HubSpot CRM dashboard header.
             Provides overall contact, deal, and engagement health metrics.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_contact_performance
  - dbo.vw_hubspot_deal_performance
  - dbo.vw_hubspot_engagement_daily_summary
================================================================================
*/

-- Overall HubSpot CRM Executive Summary
WITH ContactMetrics AS (
    SELECT 
        COUNT(DISTINCT contact_id) AS total_contacts,
        COUNT(DISTINCT CASE WHEN created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN contact_id END) AS new_contacts_30d,
        COUNT(DISTINCT CASE WHEN lifecycle_stage = 'customer' THEN contact_id END) AS total_customers,
        COUNT(DISTINCT CASE WHEN lifecycle_stage IN ('opportunity', 'salesqualifiedlead') THEN contact_id END) AS sales_qualified,
        COUNT(DISTINCT CASE WHEN lifecycle_stage = 'marketingqualifiedlead' THEN contact_id END) AS marketing_qualified,
        SUM(total_revenue) AS total_contact_revenue,
        AVG(total_engagements) AS avg_engagements_per_contact
    FROM [dbo].[vw_hubspot_contact_performance]
),
DealMetrics AS (
    SELECT 
        COUNT(DISTINCT deal_id) AS total_deals,
        COUNT(DISTINCT CASE WHEN deal_status = 'Open' THEN deal_id END) AS open_deals,
        COUNT(DISTINCT CASE WHEN is_closed_won = 1 THEN deal_id END) AS won_deals,
        COUNT(DISTINCT CASE WHEN is_closed = 1 AND is_closed_won = 0 THEN deal_id END) AS lost_deals,
        SUM(CASE WHEN is_closed_won = 1 THEN amount ELSE 0 END) AS closed_won_revenue,
        SUM(CASE WHEN deal_status = 'Open' THEN amount ELSE 0 END) AS pipeline_value,
        SUM(CASE WHEN deal_status = 'Open' THEN weighted_amount ELSE 0 END) AS weighted_pipeline,
        AVG(CASE WHEN is_closed_won = 1 THEN actual_days_to_close END) AS avg_days_to_close,
        -- Win rate
        CASE WHEN COUNT(DISTINCT CASE WHEN is_closed = 1 THEN deal_id END) > 0 
             THEN CAST(COUNT(DISTINCT CASE WHEN is_closed_won = 1 THEN deal_id END) * 100.0 
                       / COUNT(DISTINCT CASE WHEN is_closed = 1 THEN deal_id END) AS DECIMAL(10, 2))
             ELSE 0 END AS win_rate
    FROM [dbo].[vw_hubspot_deal_performance]
),
EngagementMetrics AS (
    SELECT 
        SUM(total_engagements) AS total_engagements_30d,
        SUM(total_calls) AS total_calls_30d,
        SUM(total_meetings) AS total_meetings_30d,
        SUM(total_emails) AS total_emails_30d,
        SUM(unique_contacts_engaged) AS contacts_engaged_30d,
        SUM(unique_companies_engaged) AS companies_engaged_30d,
        SUM(unique_deals_engaged) AS deals_engaged_30d
    FROM [dbo].[vw_hubspot_engagement_daily_summary]
    WHERE engagement_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
)
SELECT 
    -- Contact Metrics
    cm.total_contacts,
    cm.new_contacts_30d,
    cm.total_customers,
    cm.sales_qualified,
    cm.marketing_qualified,
    cm.total_contact_revenue,
    cm.avg_engagements_per_contact,
    
    -- Deal Metrics
    dm.total_deals,
    dm.open_deals,
    dm.won_deals,
    dm.lost_deals,
    dm.closed_won_revenue,
    dm.pipeline_value,
    dm.weighted_pipeline,
    dm.avg_days_to_close,
    dm.win_rate,
    
    -- Engagement Metrics (Last 30 Days)
    em.total_engagements_30d,
    em.total_calls_30d,
    em.total_meetings_30d,
    em.total_emails_30d,
    em.contacts_engaged_30d,
    em.companies_engaged_30d,
    em.deals_engaged_30d,
    
    -- Calculated KPIs
    CASE WHEN cm.total_contacts > 0 
         THEN CAST(cm.total_customers * 100.0 / cm.total_contacts AS DECIMAL(10, 2))
         ELSE 0 END AS customer_conversion_rate,
    
    CASE WHEN cm.total_contacts > 0 
         THEN CAST(cm.total_contact_revenue / cm.total_contacts AS DECIMAL(18, 2))
         ELSE 0 END AS revenue_per_contact,
    
    CASE WHEN dm.open_deals > 0 
         THEN CAST(dm.pipeline_value / dm.open_deals AS DECIMAL(18, 2))
         ELSE 0 END AS avg_deal_size

FROM ContactMetrics cm
CROSS JOIN DealMetrics dm
CROSS JOIN EngagementMetrics em;
GO

/*
================================================================================
QUERY: qry_hubspot_pipeline_health
DESCRIPTION: Deal pipeline health analysis with stage distribution and velocity.
             Identifies bottlenecks and forecasts revenue.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_deal_performance
  - dbo.vw_hubspot_deal_pipeline_summary
================================================================================
*/

-- Pipeline Health Dashboard
SELECT 
    ps.pipeline_name,
    ps.stage_label,
    ps.display_order,
    ps.probability AS stage_probability,
    ps.deal_count,
    ps.total_value,
    ps.weighted_value,
    ps.avg_deal_size,
    ps.avg_age_days,
    ps.pct_of_pipeline_count,
    ps.pct_of_pipeline_value,
    
    -- Health indicators
    CASE 
        WHEN ps.avg_age_days > 60 AND ps.is_closed = 0 THEN 'Stagnant'
        WHEN ps.avg_age_days > 30 AND ps.is_closed = 0 THEN 'Slowing'
        ELSE 'Healthy'
    END AS stage_health,
    
    -- Cumulative metrics
    SUM(ps.deal_count) OVER (PARTITION BY ps.pipeline_id ORDER BY ps.display_order) AS cumulative_deals,
    SUM(ps.total_value) OVER (PARTITION BY ps.pipeline_id ORDER BY ps.display_order) AS cumulative_value

FROM [dbo].[vw_hubspot_deal_pipeline_summary] ps
WHERE ps.is_closed = 0  -- Only active stages
ORDER BY ps.pipeline_id, ps.display_order;
GO

/*
================================================================================
QUERY: qry_hubspot_deals_at_risk
DESCRIPTION: Identifies deals that need attention based on engagement and timing.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_deal_performance
================================================================================
*/

-- Deals At Risk Analysis
SELECT 
    deal_id,
    deal_name,
    owner_name,
    company_name,
    pipeline_name,
    stage_label,
    amount,
    weighted_amount,
    deal_age_days,
    days_since_last_engagement,
    close_date,
    close_date_status,
    deal_health_status,
    total_engagements,
    total_meetings,
    total_calls,
    
    -- Risk score (higher = more at risk)
    CASE 
        WHEN deal_health_status = 'Stale' THEN 100
        WHEN deal_health_status = 'At Risk' THEN 75
        WHEN deal_health_status = 'Needs Attention' THEN 50
        WHEN close_date_status = 'Overdue' THEN 80
        WHEN total_engagements = 0 THEN 90
        ELSE 25
    END AS risk_score,
    
    -- Recommended action
    CASE 
        WHEN total_engagements = 0 THEN 'Schedule initial meeting'
        WHEN deal_health_status = 'Stale' THEN 'Re-engage immediately'
        WHEN deal_health_status = 'At Risk' THEN 'Follow up this week'
        WHEN close_date_status = 'Overdue' THEN 'Update close date and re-qualify'
        WHEN deal_health_status = 'Needs Attention' THEN 'Schedule follow-up'
        ELSE 'Continue nurturing'
    END AS recommended_action

FROM [dbo].[vw_hubspot_deal_performance]
WHERE deal_status = 'Open'
  AND (deal_health_status IN ('Stale', 'At Risk', 'Needs Attention', 'No Engagement')
       OR close_date_status = 'Overdue')
ORDER BY risk_score DESC, amount DESC;
GO

/*
================================================================================
QUERY: qry_hubspot_sales_forecast
DESCRIPTION: Sales forecast by time period and owner.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_deal_forecast
================================================================================
*/

-- Sales Forecast Summary
SELECT 
    owner_name,
    forecast_period,
    deal_count,
    pipeline_value,
    weighted_pipeline,
    avg_probability,
    avg_deal_size,
    
    -- Forecast categories
    SUM(CASE WHEN avg_probability >= 75 THEN pipeline_value ELSE 0 END) AS commit_value,
    SUM(CASE WHEN avg_probability >= 50 AND avg_probability < 75 THEN pipeline_value ELSE 0 END) AS best_case_value,
    SUM(CASE WHEN avg_probability < 50 THEN pipeline_value ELSE 0 END) AS pipeline_only_value,
    
    -- Percentage of total
    CAST(pipeline_value * 100.0 / NULLIF(SUM(pipeline_value) OVER (PARTITION BY forecast_period), 0) AS DECIMAL(10, 2)) AS pct_of_period

FROM [dbo].[vw_hubspot_deal_forecast]
GROUP BY owner_name, forecast_period, owner_id, deal_count, pipeline_value, weighted_pipeline, avg_probability, avg_deal_size
ORDER BY 
    CASE forecast_period 
        WHEN 'This Month' THEN 1 
        WHEN 'Next Month' THEN 2 
        WHEN 'This Quarter' THEN 3 
        WHEN 'Next Quarter' THEN 4 
        ELSE 5 
    END,
    weighted_pipeline DESC;
GO

/*
================================================================================
QUERY: qry_hubspot_contact_funnel
DESCRIPTION: Marketing-to-sales contact funnel analysis.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_contact_lifecycle_funnel
================================================================================
*/

-- Contact Lifecycle Funnel
SELECT 
    stage_display_name,
    stage_order,
    contact_count,
    new_contacts_30d,
    new_contacts_90d,
    total_revenue,
    avg_revenue,
    pct_of_total,
    
    -- Stage-over-stage conversion (approximation)
    LAG(contact_count) OVER (ORDER BY stage_order DESC) AS prev_stage_count,
    CASE 
        WHEN LAG(contact_count) OVER (ORDER BY stage_order DESC) > 0 
        THEN CAST(contact_count * 100.0 / LAG(contact_count) OVER (ORDER BY stage_order DESC) AS DECIMAL(10, 2))
        ELSE NULL 
    END AS stage_conversion_rate,
    
    -- Cumulative funnel
    SUM(contact_count) OVER (ORDER BY stage_order DESC) AS cumulative_contacts

FROM [dbo].[vw_hubspot_contact_lifecycle_funnel]
ORDER BY stage_order;
GO

/*
================================================================================
QUERY: qry_hubspot_engagement_trend
DESCRIPTION: Engagement trend analysis for the last 30 days.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_engagement_daily_summary
================================================================================
*/

-- Daily Engagement Trend
SELECT 
    engagement_date,
    date_id,
    day_of_week,
    day_of_week_num,
    
    -- Totals
    total_engagements,
    total_calls,
    total_meetings,
    total_emails,
    total_notes,
    total_tasks,
    
    -- Reach metrics
    unique_contacts_engaged,
    unique_companies_engaged,
    unique_deals_engaged,
    
    -- Call metrics
    total_call_minutes,
    avg_call_minutes,
    
    -- Meeting metrics
    meetings_completed,
    meetings_scheduled,
    meetings_canceled,
    meetings_no_show,
    
    -- Task metrics
    tasks_completed,
    tasks_pending,
    
    -- 7-day moving averages
    AVG(total_engagements * 1.0) OVER (ORDER BY engagement_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS engagements_7d_ma,
    AVG(total_calls * 1.0) OVER (ORDER BY engagement_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS calls_7d_ma,
    AVG(total_meetings * 1.0) OVER (ORDER BY engagement_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS meetings_7d_ma,
    
    -- Week-over-week comparison
    LAG(total_engagements, 7) OVER (ORDER BY engagement_date) AS engagements_1w_ago,
    CASE 
        WHEN LAG(total_engagements, 7) OVER (ORDER BY engagement_date) > 0 
        THEN CAST((total_engagements - LAG(total_engagements, 7) OVER (ORDER BY engagement_date)) * 100.0 
                   / LAG(total_engagements, 7) OVER (ORDER BY engagement_date) AS DECIMAL(10, 2))
        ELSE NULL 
    END AS engagement_wow_change_pct

FROM [dbo].[vw_hubspot_engagement_daily_summary]
WHERE engagement_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY engagement_date;
GO

/*
================================================================================
QUERY: qry_hubspot_email_campaign_dashboard
DESCRIPTION: Email campaign performance dashboard with key metrics.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_email_performance
================================================================================
*/

-- Email Campaign Performance Summary
SELECT 
    campaign_name,
    email_subject,
    campaign_type,
    first_sent_at,
    
    -- Volume metrics
    sent_count,
    delivered_count,
    unique_recipients,
    
    -- Engagement metrics
    unique_opens,
    total_opens,
    unique_clicks,
    total_clicks,
    
    -- Negative metrics
    bounce_count,
    unsubscribe_count,
    spam_report_count,
    
    -- Calculated rates
    delivery_rate,
    unique_open_rate,
    unique_click_rate,
    click_to_open_rate,
    bounce_rate,
    unsubscribe_rate,
    
    -- Performance tier
    performance_tier,
    
    -- Device breakdown
    mobile_open_pct,
    desktop_open_pct,
    
    -- Benchmarking
    AVG(unique_open_rate) OVER () AS avg_open_rate_all,
    AVG(unique_click_rate) OVER () AS avg_click_rate_all,
    
    -- Variance from average
    unique_open_rate - AVG(unique_open_rate) OVER () AS open_rate_vs_avg,
    unique_click_rate - AVG(unique_click_rate) OVER () AS click_rate_vs_avg

FROM [dbo].[vw_hubspot_email_performance]
WHERE sent_count > 0
ORDER BY first_sent_at DESC;
GO

/*
================================================================================
QUERY: qry_hubspot_owner_leaderboard
DESCRIPTION: Sales rep performance leaderboard combining all metrics.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_deal_owner_performance
  - dbo.vw_hubspot_engagement_owner_summary
================================================================================
*/

-- Owner Performance Leaderboard
SELECT 
    d.owner_name,
    d.owner_email,
    
    -- Deal metrics
    d.total_deals,
    d.won_deals,
    d.lost_deals,
    d.open_deals,
    d.win_rate,
    d.closed_won_revenue,
    d.pipeline_value,
    d.avg_won_deal_size,
    d.avg_days_to_close_won,
    
    -- Recent performance
    d.new_deals_30d,
    d.won_deals_30d,
    d.won_revenue_30d,
    
    -- Engagement metrics
    COALESCE(e.total_engagements, 0) AS total_engagements,
    COALESCE(e.engagements_30d, 0) AS engagements_30d,
    COALESCE(e.total_calls, 0) AS total_calls,
    COALESCE(e.total_meetings, 0) AS total_meetings,
    COALESCE(e.completed_meetings, 0) AS completed_meetings,
    COALESCE(e.meeting_completion_rate, 0) AS meeting_completion_rate,
    COALESCE(e.unique_contacts_engaged, 0) AS contacts_engaged,
    COALESCE(e.unique_companies_engaged, 0) AS companies_engaged,
    COALESCE(e.total_call_minutes, 0) AS total_call_minutes,
    
    -- Rankings
    DENSE_RANK() OVER (ORDER BY d.closed_won_revenue DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY d.won_deals DESC) AS deals_won_rank,
    DENSE_RANK() OVER (ORDER BY d.win_rate DESC) AS win_rate_rank,
    DENSE_RANK() OVER (ORDER BY COALESCE(e.total_engagements, 0) DESC) AS engagement_rank,
    
    -- Composite score (weighted average of rankings)
    CAST((
        DENSE_RANK() OVER (ORDER BY d.closed_won_revenue DESC) * 0.4 +
        DENSE_RANK() OVER (ORDER BY d.won_deals DESC) * 0.2 +
        DENSE_RANK() OVER (ORDER BY d.win_rate DESC) * 0.2 +
        DENSE_RANK() OVER (ORDER BY COALESCE(e.total_engagements, 0) DESC) * 0.2
    ) AS DECIMAL(10, 2)) AS composite_rank

FROM [dbo].[vw_hubspot_deal_owner_performance] d
LEFT JOIN [dbo].[vw_hubspot_engagement_owner_summary] e ON d.owner_id = e.owner_id
ORDER BY closed_won_revenue DESC;
GO

/*
================================================================================
QUERY: qry_hubspot_company_insights
DESCRIPTION: Company/account insights for ABM (Account-Based Marketing) analysis.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_company_performance
================================================================================
*/

-- Top Companies by Revenue Potential
SELECT 
    company_name,
    domain,
    industry,
    company_type,
    location,
    owner_name,
    lifecycle_stage,
    
    -- Contact metrics
    calculated_contact_count,
    customer_contacts,
    sales_qualified_contacts,
    
    -- Deal metrics
    total_deals,
    won_deals,
    open_deals,
    closed_won_revenue,
    pipeline_value,
    deal_win_rate,
    
    -- Engagement metrics
    total_engagements,
    engagements_last_30_days,
    engagements_last_90_days,
    
    -- Health and status
    account_health_status,
    customer_status,
    total_lifetime_value,
    
    -- Score for prioritization
    CASE 
        WHEN customer_status = 'Customer' AND pipeline_value > 0 THEN 1  -- Expansion opportunity
        WHEN pipeline_value > 0 AND engagements_last_30_days > 0 THEN 2  -- Active prospect
        WHEN pipeline_value > 0 THEN 3  -- Has pipeline
        WHEN sales_qualified_contacts > 0 THEN 4  -- Has qualified contacts
        ELSE 5  -- Other
    END AS priority_tier,
    
    -- Recommended action
    CASE 
        WHEN customer_status = 'Customer' AND pipeline_value > 0 THEN 'Drive expansion deal'
        WHEN customer_status = 'Customer' THEN 'Maintain relationship'
        WHEN account_health_status = 'Highly Active' THEN 'Advance to close'
        WHEN account_health_status IN ('Active', 'Warm') THEN 'Continue engagement'
        WHEN pipeline_value > 0 THEN 'Re-engage stakeholders'
        ELSE 'Initial outreach needed'
    END AS recommended_action

FROM [dbo].[vw_hubspot_company_performance]
WHERE calculated_contact_count > 0 OR total_deals > 0
ORDER BY total_lifetime_value DESC, pipeline_value DESC;
GO

/*
================================================================================
QUERY: qry_hubspot_source_attribution
DESCRIPTION: Lead source attribution and ROI analysis.
DEPENDENT VIEWS:
  - dbo.vw_hubspot_contact_source_performance
================================================================================
*/

-- Source Attribution Analysis
SELECT 
    acquisition_source,
    source_detail_1,
    source_detail_2,
    
    -- Volume metrics
    total_contacts,
    new_contacts_30d,
    
    -- Funnel progression
    leads_subscribers,
    marketing_qualified,
    sales_qualified,
    customers,
    
    -- Conversion rates
    customer_conversion_rate,
    sales_qualified_rate,
    
    -- Revenue metrics
    total_revenue,
    avg_revenue_per_contact,
    revenue_per_contact,
    
    -- Engagement quality
    avg_page_views,
    avg_visits,
    avg_deals_per_contact,
    
    -- Source efficiency
    CASE 
        WHEN total_contacts > 0 THEN total_revenue / total_contacts
        ELSE 0 
    END AS revenue_efficiency,
    
    -- Rankings
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY customer_conversion_rate DESC) AS conversion_rank,
    DENSE_RANK() OVER (ORDER BY total_contacts DESC) AS volume_rank

FROM [dbo].[vw_hubspot_contact_source_performance]
WHERE total_contacts >= 10  -- Minimum sample size
ORDER BY total_revenue DESC;
GO

/*
================================================================================
QUERY: qry_hubspot_cross_channel_summary
DESCRIPTION: Cross-channel engagement summary combining all HubSpot data.
             Provides unified view for executive reporting.
================================================================================
*/

-- Cross-Channel Summary (Last 30 Days)
WITH ContactSummary AS (
    SELECT 
        'Contacts' AS channel,
        COUNT(DISTINCT contact_id) AS total_records,
        COUNT(DISTINCT CASE WHEN created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN contact_id END) AS new_30d,
        SUM(total_engagements) AS total_activities,
        SUM(total_revenue) AS total_revenue
    FROM [dbo].[vw_hubspot_contact_performance]
),
CompanySummary AS (
    SELECT 
        'Companies' AS channel,
        COUNT(DISTINCT company_id) AS total_records,
        COUNT(DISTINCT CASE WHEN created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN company_id END) AS new_30d,
        SUM(total_engagements) AS total_activities,
        SUM(total_lifetime_value) AS total_revenue
    FROM [dbo].[vw_hubspot_company_performance]
),
DealSummary AS (
    SELECT 
        'Deals' AS channel,
        COUNT(DISTINCT deal_id) AS total_records,
        COUNT(DISTINCT CASE WHEN create_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN deal_id END) AS new_30d,
        SUM(total_engagements) AS total_activities,
        SUM(CASE WHEN is_closed_won = 1 THEN amount ELSE 0 END) AS total_revenue
    FROM [dbo].[vw_hubspot_deal_performance]
),
EmailSummary AS (
    SELECT 
        'Email Campaigns' AS channel,
        COUNT(DISTINCT campaign_id) AS total_records,
        COUNT(DISTINCT CASE WHEN first_sent_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN campaign_id END) AS new_30d,
        SUM(sent_count) AS total_activities,
        0 AS total_revenue  -- Emails don't directly have revenue
    FROM [dbo].[vw_hubspot_email_performance]
),
EngagementSummary AS (
    SELECT 
        'Engagements' AS channel,
        SUM(total_engagements) AS total_records,
        SUM(total_engagements) AS new_30d,  -- Already filtered to 30d in daily summary
        SUM(total_engagements) AS total_activities,
        0 AS total_revenue
    FROM [dbo].[vw_hubspot_engagement_daily_summary]
    WHERE engagement_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
)
SELECT * FROM ContactSummary
UNION ALL SELECT * FROM CompanySummary
UNION ALL SELECT * FROM DealSummary
UNION ALL SELECT * FROM EmailSummary
UNION ALL SELECT * FROM EngagementSummary;
GO
