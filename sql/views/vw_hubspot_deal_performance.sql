/*
================================================================================
VIEW: vw_hubspot_deal_performance
DESCRIPTION: Deal pipeline metrics, stages, and conversion analysis from HubSpot CRM.
             Provides comprehensive deal analytics for sales pipeline reporting
             including stage progression, velocity metrics, and forecasting data.
SCHEMA TABLES:
  - hubspot.deal: Deal records with pipeline and amount information
    Columns: deal_id, deal_name, pipeline_id, pipeline_stage_id, deal_stage,
             deal_type, amount, deal_currency_code, close_date, create_date,
             owner_id, associated_company_id, associated_contact_id, is_closed,
             is_closed_won, days_to_close, hs_analytics_source, hs_deal_stage_probability,
             hs_projected_amount, hs_acv, hs_arr, hs_mrr, hs_tcv
  - hubspot.deal_pipeline: Pipeline definitions
    Columns: pipeline_id, label, display_order
  - hubspot.deal_stage: Stage definitions for each pipeline
    Columns: stage_id, pipeline_id, label, display_order, probability, is_closed, is_closed_won
  - hubspot.owner: Owner/sales rep records
    Columns: owner_id, email, first_name, last_name
  - hubspot.company: Associated company records
    Columns: company_id, name, industry
  - hubspot.contact: Associated contact records
    Columns: contact_id, email, first_name, last_name
  - hubspot.engagement_deal: Deal engagement associations
    Columns: engagement_id, deal_id
  - hubspot.engagement: Engagement activity records
    Columns: engagement_id, type, timestamp
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_deal_performance]
AS
WITH DealEngagements AS (
    SELECT 
        ed.deal_id,
        COUNT(DISTINCT e.engagement_id) AS total_engagements,
        COUNT(DISTINCT CASE WHEN e.type = 'CALL' THEN e.engagement_id END) AS total_calls,
        COUNT(DISTINCT CASE WHEN e.type = 'MEETING' THEN e.engagement_id END) AS total_meetings,
        COUNT(DISTINCT CASE WHEN e.type = 'EMAIL' THEN e.engagement_id END) AS total_emails,
        COUNT(DISTINCT CASE WHEN e.type = 'NOTE' THEN e.engagement_id END) AS total_notes,
        COUNT(DISTINCT CASE WHEN e.type = 'TASK' THEN e.engagement_id END) AS total_tasks,
        MAX(e.timestamp) AS last_engagement_date,
        MIN(e.timestamp) AS first_engagement_date
    FROM hubspot.engagement_deal ed
    INNER JOIN hubspot.engagement e ON ed.engagement_id = e.engagement_id
    WHERE e._fivetran_deleted = 0
    GROUP BY ed.deal_id
)
SELECT 
    -- Deal identifiers
    d.deal_id,
    d.deal_name,
    d.deal_type,
    
    -- Pipeline information
    d.pipeline_id,
    dp.label AS pipeline_name,
    d.pipeline_stage_id,
    d.deal_stage,
    ds.label AS stage_label,
    ds.display_order AS stage_order,
    COALESCE(ds.probability, d.hs_deal_stage_probability) AS stage_probability,
    
    -- Deal status
    COALESCE(d.is_closed, 0) AS is_closed,
    COALESCE(d.is_closed_won, 0) AS is_closed_won,
    CASE 
        WHEN d.is_closed_won = 1 THEN 'Won'
        WHEN d.is_closed = 1 AND d.is_closed_won = 0 THEN 'Lost'
        ELSE 'Open'
    END AS deal_status,
    
    -- Deal value
    COALESCE(d.amount, 0) AS amount,
    d.deal_currency_code,
    COALESCE(d.hs_projected_amount, d.amount * COALESCE(ds.probability, d.hs_deal_stage_probability, 0) / 100) AS weighted_amount,
    
    -- Recurring revenue metrics
    COALESCE(d.hs_acv, 0) AS acv,  -- Annual Contract Value
    COALESCE(d.hs_arr, 0) AS arr,  -- Annual Recurring Revenue
    COALESCE(d.hs_mrr, 0) AS mrr,  -- Monthly Recurring Revenue
    COALESCE(d.hs_tcv, 0) AS tcv,  -- Total Contract Value
    
    -- Important dates
    d.create_date,
    d.close_date,
    CONVERT(INT, FORMAT(d.create_date, 'yyyyMMdd')) AS create_date_id,
    CONVERT(INT, FORMAT(d.close_date, 'yyyyMMdd')) AS close_date_id,
    
    -- Time metrics
    COALESCE(d.days_to_close, 
             DATEDIFF(DAY, d.create_date, COALESCE(d.close_date, GETDATE()))) AS days_in_pipeline,
    CASE 
        WHEN d.is_closed = 1 THEN d.days_to_close
        ELSE NULL 
    END AS actual_days_to_close,
    
    -- Deal age
    DATEDIFF(DAY, d.create_date, GETDATE()) AS deal_age_days,
    
    -- Days until expected close
    CASE 
        WHEN d.is_closed = 0 AND d.close_date IS NOT NULL 
        THEN DATEDIFF(DAY, GETDATE(), d.close_date)
        ELSE NULL 
    END AS days_until_close,
    
    -- Close date status
    CASE 
        WHEN d.is_closed = 1 THEN 'Closed'
        WHEN d.close_date IS NULL THEN 'No Close Date'
        WHEN d.close_date < CAST(GETDATE() AS DATE) THEN 'Overdue'
        WHEN d.close_date <= DATEADD(DAY, 7, CAST(GETDATE() AS DATE)) THEN 'Closing This Week'
        WHEN d.close_date <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE)) THEN 'Closing This Month'
        WHEN d.close_date <= DATEADD(DAY, 90, CAST(GETDATE() AS DATE)) THEN 'Closing This Quarter'
        ELSE 'Future'
    END AS close_date_status,
    
    -- Owner information
    d.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Associated company
    d.associated_company_id,
    comp.name AS company_name,
    comp.industry AS company_industry,
    
    -- Associated contact
    d.associated_contact_id,
    CONCAT(COALESCE(con.first_name, ''), ' ', COALESCE(con.last_name, '')) AS contact_name,
    con.email AS contact_email,
    
    -- Analytics source
    d.hs_analytics_source,
    
    -- Engagement metrics from CTE
    COALESCE(de.total_engagements, 0) AS total_engagements,
    COALESCE(de.total_calls, 0) AS total_calls,
    COALESCE(de.total_meetings, 0) AS total_meetings,
    COALESCE(de.total_emails, 0) AS total_emails,
    COALESCE(de.total_notes, 0) AS total_notes,
    COALESCE(de.total_tasks, 0) AS total_tasks,
    de.last_engagement_date,
    de.first_engagement_date,
    
    -- Days since last engagement
    CASE 
        WHEN de.last_engagement_date IS NOT NULL 
        THEN DATEDIFF(DAY, de.last_engagement_date, GETDATE())
        ELSE NULL 
    END AS days_since_last_engagement,
    
    -- Engagement velocity (engagements per week in pipeline)
    CASE 
        WHEN DATEDIFF(WEEK, d.create_date, GETDATE()) > 0 
        THEN CAST(COALESCE(de.total_engagements, 0) * 1.0 / DATEDIFF(WEEK, d.create_date, GETDATE()) AS DECIMAL(10, 2))
        ELSE COALESCE(de.total_engagements, 0)
    END AS engagements_per_week,
    
    -- Activity notes count
    COALESCE(d.num_contacted_notes, 0) AS num_contacted_notes,
    COALESCE(d.num_notes, 0) AS num_notes,
    
    -- Deal health indicators
    CASE 
        WHEN d.is_closed = 1 THEN 'Closed'
        WHEN de.last_engagement_date IS NULL THEN 'No Engagement'
        WHEN DATEDIFF(DAY, de.last_engagement_date, GETDATE()) <= 7 THEN 'Healthy'
        WHEN DATEDIFF(DAY, de.last_engagement_date, GETDATE()) <= 14 THEN 'Needs Attention'
        WHEN DATEDIFF(DAY, de.last_engagement_date, GETDATE()) <= 30 THEN 'At Risk'
        ELSE 'Stale'
    END AS deal_health_status,
    
    -- Metadata
    d._fivetran_synced AS last_synced_at

FROM hubspot.deal d
LEFT JOIN hubspot.deal_pipeline dp ON d.pipeline_id = dp.pipeline_id AND dp._fivetran_deleted = 0
LEFT JOIN hubspot.deal_stage ds ON d.pipeline_stage_id = ds.stage_id AND d.pipeline_id = ds.pipeline_id AND ds._fivetran_deleted = 0
LEFT JOIN hubspot.owner o ON d.owner_id = o.owner_id AND o._fivetran_deleted = 0
LEFT JOIN hubspot.company comp ON d.associated_company_id = comp.company_id AND comp._fivetran_deleted = 0
LEFT JOIN hubspot.contact con ON d.associated_contact_id = con.contact_id AND con._fivetran_deleted = 0
LEFT JOIN DealEngagements de ON d.deal_id = de.deal_id
WHERE d._fivetran_deleted = 0;
GO

/*
================================================================================
VIEW: vw_hubspot_deal_pipeline_summary
DESCRIPTION: Pipeline summary with stage distribution and conversion metrics.
             Provides funnel analysis and pipeline health indicators.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_deal_pipeline_summary]
AS
WITH PipelineStages AS (
    SELECT 
        d.pipeline_id,
        d.pipeline_stage_id,
        dp.label AS pipeline_name,
        ds.label AS stage_label,
        ds.display_order,
        ds.probability,
        ds.is_closed,
        ds.is_closed_won,
        COUNT(DISTINCT d.deal_id) AS deal_count,
        SUM(COALESCE(d.amount, 0)) AS total_value,
        AVG(COALESCE(d.amount, 0)) AS avg_deal_size,
        SUM(COALESCE(d.amount, 0) * COALESCE(ds.probability, 0) / 100) AS weighted_value,
        AVG(DATEDIFF(DAY, d.create_date, GETDATE())) AS avg_age_days
    FROM hubspot.deal d
    LEFT JOIN hubspot.deal_pipeline dp ON d.pipeline_id = dp.pipeline_id AND dp._fivetran_deleted = 0
    LEFT JOIN hubspot.deal_stage ds ON d.pipeline_stage_id = ds.stage_id AND d.pipeline_id = ds.pipeline_id AND ds._fivetran_deleted = 0
    WHERE d._fivetran_deleted = 0
    GROUP BY d.pipeline_id, d.pipeline_stage_id, dp.label, ds.label, ds.display_order, ds.probability, ds.is_closed, ds.is_closed_won
)
SELECT 
    pipeline_id,
    pipeline_name,
    pipeline_stage_id,
    stage_label,
    display_order,
    probability,
    COALESCE(is_closed, 0) AS is_closed,
    COALESCE(is_closed_won, 0) AS is_closed_won,
    deal_count,
    total_value,
    avg_deal_size,
    weighted_value,
    avg_age_days,
    -- Percentage of pipeline
    CAST(deal_count * 100.0 / NULLIF(SUM(deal_count) OVER (PARTITION BY pipeline_id), 0) AS DECIMAL(10, 2)) AS pct_of_pipeline_count,
    CAST(total_value * 100.0 / NULLIF(SUM(total_value) OVER (PARTITION BY pipeline_id), 0) AS DECIMAL(10, 2)) AS pct_of_pipeline_value
FROM PipelineStages;
GO

/*
================================================================================
VIEW: vw_hubspot_deal_stage_conversion
DESCRIPTION: Deal stage conversion analysis with time-in-stage metrics.
             Tracks progression and identifies bottlenecks.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_deal_stage_conversion]
AS
WITH StageHistory AS (
    SELECT 
        dsh.deal_id,
        dsh.stage_id,
        dsh.pipeline_id,
        dsh.timestamp,
        LAG(dsh.stage_id) OVER (PARTITION BY dsh.deal_id ORDER BY dsh.timestamp) AS prev_stage_id,
        LAG(dsh.timestamp) OVER (PARTITION BY dsh.deal_id ORDER BY dsh.timestamp) AS prev_timestamp,
        ds.label AS stage_label,
        ds.display_order
    FROM hubspot.deal_stage_history dsh
    LEFT JOIN hubspot.deal_stage ds ON dsh.stage_id = ds.stage_id AND dsh.pipeline_id = ds.pipeline_id
),
StageTransitions AS (
    SELECT 
        pipeline_id,
        prev_stage_id AS from_stage_id,
        stage_id AS to_stage_id,
        COUNT(*) AS transition_count,
        AVG(DATEDIFF(HOUR, prev_timestamp, timestamp)) AS avg_hours_in_stage,
        AVG(DATEDIFF(DAY, prev_timestamp, timestamp)) AS avg_days_in_stage,
        MIN(DATEDIFF(DAY, prev_timestamp, timestamp)) AS min_days_in_stage,
        MAX(DATEDIFF(DAY, prev_timestamp, timestamp)) AS max_days_in_stage
    FROM StageHistory
    WHERE prev_stage_id IS NOT NULL
    GROUP BY pipeline_id, prev_stage_id, stage_id
)
SELECT 
    st.pipeline_id,
    dp.label AS pipeline_name,
    st.from_stage_id,
    ds_from.label AS from_stage_label,
    ds_from.display_order AS from_stage_order,
    st.to_stage_id,
    ds_to.label AS to_stage_label,
    ds_to.display_order AS to_stage_order,
    st.transition_count,
    st.avg_hours_in_stage,
    st.avg_days_in_stage,
    st.min_days_in_stage,
    st.max_days_in_stage,
    -- Conversion direction (forward/backward/closed)
    CASE 
        WHEN ds_to.is_closed_won = 1 THEN 'Won'
        WHEN ds_to.is_closed = 1 THEN 'Lost'
        WHEN ds_to.display_order > ds_from.display_order THEN 'Forward'
        WHEN ds_to.display_order < ds_from.display_order THEN 'Backward'
        ELSE 'Same Level'
    END AS transition_type
FROM StageTransitions st
LEFT JOIN hubspot.deal_pipeline dp ON st.pipeline_id = dp.pipeline_id AND dp._fivetran_deleted = 0
LEFT JOIN hubspot.deal_stage ds_from ON st.from_stage_id = ds_from.stage_id AND st.pipeline_id = ds_from.pipeline_id
LEFT JOIN hubspot.deal_stage ds_to ON st.to_stage_id = ds_to.stage_id AND st.pipeline_id = ds_to.pipeline_id;
GO

/*
================================================================================
VIEW: vw_hubspot_deal_owner_performance
DESCRIPTION: Deal owner/sales rep performance analysis.
             Tracks win rates, deal velocity, and revenue metrics by owner.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_deal_owner_performance]
AS
SELECT 
    d.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Deal counts
    COUNT(DISTINCT d.deal_id) AS total_deals,
    COUNT(DISTINCT CASE WHEN d.is_closed_won = 1 THEN d.deal_id END) AS won_deals,
    COUNT(DISTINCT CASE WHEN d.is_closed = 1 AND d.is_closed_won = 0 THEN d.deal_id END) AS lost_deals,
    COUNT(DISTINCT CASE WHEN d.is_closed = 0 THEN d.deal_id END) AS open_deals,
    
    -- Win rate
    CASE WHEN COUNT(DISTINCT CASE WHEN d.is_closed = 1 THEN d.deal_id END) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN d.is_closed_won = 1 THEN d.deal_id END) * 100.0 
                   / COUNT(DISTINCT CASE WHEN d.is_closed = 1 THEN d.deal_id END) AS DECIMAL(10, 2))
         ELSE 0 END AS win_rate,
    
    -- Revenue metrics
    SUM(CASE WHEN d.is_closed_won = 1 THEN COALESCE(d.amount, 0) ELSE 0 END) AS closed_won_revenue,
    SUM(CASE WHEN d.is_closed = 0 THEN COALESCE(d.amount, 0) ELSE 0 END) AS pipeline_value,
    AVG(CASE WHEN d.is_closed_won = 1 THEN d.amount END) AS avg_won_deal_size,
    AVG(CASE WHEN d.is_closed = 0 THEN d.amount END) AS avg_open_deal_size,
    
    -- Velocity metrics
    AVG(CASE WHEN d.is_closed_won = 1 THEN d.days_to_close END) AS avg_days_to_close_won,
    AVG(CASE WHEN d.is_closed = 1 AND d.is_closed_won = 0 THEN d.days_to_close END) AS avg_days_to_close_lost,
    
    -- Activity metrics (last 30 days)
    COUNT(DISTINCT CASE WHEN d.create_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN d.deal_id END) AS new_deals_30d,
    COUNT(DISTINCT CASE WHEN d.is_closed_won = 1 AND d.close_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN d.deal_id END) AS won_deals_30d,
    SUM(CASE WHEN d.is_closed_won = 1 AND d.close_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN COALESCE(d.amount, 0) ELSE 0 END) AS won_revenue_30d,
    
    -- Activity metrics (last 90 days)
    COUNT(DISTINCT CASE WHEN d.create_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) THEN d.deal_id END) AS new_deals_90d,
    COUNT(DISTINCT CASE WHEN d.is_closed_won = 1 AND d.close_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) THEN d.deal_id END) AS won_deals_90d,
    SUM(CASE WHEN d.is_closed_won = 1 AND d.close_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) THEN COALESCE(d.amount, 0) ELSE 0 END) AS won_revenue_90d

FROM hubspot.deal d
LEFT JOIN hubspot.owner o ON d.owner_id = o.owner_id AND o._fivetran_deleted = 0
WHERE d._fivetran_deleted = 0
  AND d.owner_id IS NOT NULL
GROUP BY d.owner_id, o.first_name, o.last_name, o.email;
GO

/*
================================================================================
VIEW: vw_hubspot_deal_forecast
DESCRIPTION: Deal forecasting view with weighted pipeline and close date analysis.
             Supports sales forecasting and quota tracking.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_deal_forecast]
AS
WITH ForecastPeriods AS (
    SELECT 
        d.owner_id,
        CASE 
            WHEN d.close_date BETWEEN DATEADD(DAY, 1 - DAY(GETDATE()), CAST(GETDATE() AS DATE)) 
                                  AND EOMONTH(GETDATE()) THEN 'This Month'
            WHEN d.close_date BETWEEN DATEADD(MONTH, 1, DATEADD(DAY, 1 - DAY(GETDATE()), CAST(GETDATE() AS DATE))) 
                                  AND EOMONTH(DATEADD(MONTH, 1, GETDATE())) THEN 'Next Month'
            WHEN d.close_date BETWEEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, GETDATE()), 0) 
                                  AND DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, GETDATE()) + 1, 0)) THEN 'This Quarter'
            WHEN d.close_date BETWEEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, GETDATE()) + 1, 0) 
                                  AND DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, GETDATE()) + 2, 0)) THEN 'Next Quarter'
            ELSE 'Future'
        END AS forecast_period,
        d.deal_id,
        COALESCE(d.amount, 0) AS amount,
        COALESCE(ds.probability, d.hs_deal_stage_probability, 50) AS probability,
        COALESCE(d.amount, 0) * COALESCE(ds.probability, d.hs_deal_stage_probability, 50) / 100 AS weighted_amount
    FROM hubspot.deal d
    LEFT JOIN hubspot.deal_stage ds ON d.pipeline_stage_id = ds.stage_id AND d.pipeline_id = ds.pipeline_id AND ds._fivetran_deleted = 0
    WHERE d._fivetran_deleted = 0
      AND d.is_closed = 0
      AND d.close_date IS NOT NULL
)
SELECT 
    fp.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    fp.forecast_period,
    COUNT(DISTINCT fp.deal_id) AS deal_count,
    SUM(fp.amount) AS pipeline_value,
    SUM(fp.weighted_amount) AS weighted_pipeline,
    AVG(fp.probability) AS avg_probability,
    AVG(fp.amount) AS avg_deal_size
FROM ForecastPeriods fp
LEFT JOIN hubspot.owner o ON fp.owner_id = o.owner_id AND o._fivetran_deleted = 0
GROUP BY fp.owner_id, o.first_name, o.last_name, fp.forecast_period;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Deal pipeline metrics, stages, and conversion analysis from HubSpot CRM.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_deal_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Pipeline summary with stage distribution and conversion metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_deal_pipeline_summary';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Deal stage conversion analysis with time-in-stage metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_deal_stage_conversion';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Deal owner/sales rep performance analysis.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_deal_owner_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Deal forecasting view with weighted pipeline and close date analysis.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_deal_forecast';
GO
