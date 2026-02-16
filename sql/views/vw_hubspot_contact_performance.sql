/*
================================================================================
VIEW: vw_hubspot_contact_performance
DESCRIPTION: Contact-level metrics and engagement tracking from HubSpot CRM.
             Provides insights into contact lifecycle, engagement, and revenue attribution.
SCHEMA TABLES:
  - hubspot.contact: Contact records with properties and analytics
    Columns: contact_id, email, first_name, last_name, phone, company, job_title,
             lifecycle_stage, lead_status, owner_id, associated_company_id,
             created_at, updated_at, last_activity_date, last_contacted,
             num_associated_deals, total_revenue, hs_analytics_source,
             hs_analytics_num_page_views, hs_analytics_num_visits, _fivetran_synced
  - hubspot.owner: Owner/sales rep records
    Columns: owner_id, email, first_name, last_name, type
  - hubspot.company: Associated company records
    Columns: company_id, name, industry, domain
  - hubspot.engagement_contact: Contact engagement associations
    Columns: engagement_id, contact_id
  - hubspot.engagement: Engagement activity records
    Columns: engagement_id, type, timestamp, owner_id
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_contact_performance]
AS
WITH ContactEngagements AS (
    SELECT 
        ec.contact_id,
        COUNT(DISTINCT e.engagement_id) AS total_engagements,
        COUNT(DISTINCT CASE WHEN e.type = 'CALL' THEN e.engagement_id END) AS total_calls,
        COUNT(DISTINCT CASE WHEN e.type = 'MEETING' THEN e.engagement_id END) AS total_meetings,
        COUNT(DISTINCT CASE WHEN e.type = 'EMAIL' THEN e.engagement_id END) AS total_emails,
        COUNT(DISTINCT CASE WHEN e.type = 'NOTE' THEN e.engagement_id END) AS total_notes,
        COUNT(DISTINCT CASE WHEN e.type = 'TASK' THEN e.engagement_id END) AS total_tasks,
        MAX(e.timestamp) AS last_engagement_date,
        MIN(e.timestamp) AS first_engagement_date,
        -- Engagements in last 30 days
        COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
                            THEN e.engagement_id END) AS engagements_last_30_days,
        -- Engagements in last 90 days
        COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) 
                            THEN e.engagement_id END) AS engagements_last_90_days
    FROM hubspot.engagement_contact ec
    INNER JOIN hubspot.engagement e ON ec.engagement_id = e.engagement_id
    WHERE e._fivetran_deleted = 0
    GROUP BY ec.contact_id
)
SELECT 
    -- Contact identifiers
    c.contact_id,
    c.email,
    CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) AS full_name,
    c.first_name,
    c.last_name,
    c.phone,
    c.company AS contact_company,
    c.job_title,
    
    -- Lifecycle and status
    c.lifecycle_stage,
    c.lead_status,
    
    -- Owner information
    c.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Associated company
    c.associated_company_id,
    comp.name AS associated_company_name,
    comp.industry AS associated_company_industry,
    comp.domain AS associated_company_domain,
    
    -- Timestamps
    c.created_at,
    c.updated_at,
    c.last_activity_date,
    c.last_contacted,
    CONVERT(INT, FORMAT(c.created_at, 'yyyyMMdd')) AS created_date_id,
    
    -- Contact age (days since created)
    DATEDIFF(DAY, c.created_at, GETDATE()) AS contact_age_days,
    
    -- Days since last activity
    CASE 
        WHEN c.last_activity_date IS NOT NULL 
        THEN DATEDIFF(DAY, c.last_activity_date, GETDATE())
        ELSE NULL 
    END AS days_since_last_activity,
    
    -- Days since last contacted
    CASE 
        WHEN c.last_contacted IS NOT NULL 
        THEN DATEDIFF(DAY, c.last_contacted, GETDATE())
        ELSE NULL 
    END AS days_since_last_contacted,
    
    -- Deal information
    COALESCE(c.num_associated_deals, 0) AS num_associated_deals,
    COALESCE(c.total_revenue, 0) AS total_revenue,
    
    -- Analytics source attribution
    c.hs_analytics_source,
    c.hs_analytics_source_data_1,
    c.hs_analytics_source_data_2,
    c.hs_analytics_first_url,
    
    -- Web analytics
    COALESCE(c.hs_analytics_num_page_views, 0) AS total_page_views,
    COALESCE(c.hs_analytics_num_visits, 0) AS total_visits,
    COALESCE(c.hs_analytics_num_event_completions, 0) AS total_event_completions,
    
    -- Average pages per visit
    CASE 
        WHEN COALESCE(c.hs_analytics_num_visits, 0) > 0 
        THEN CAST(c.hs_analytics_num_page_views * 1.0 / c.hs_analytics_num_visits AS DECIMAL(10, 2))
        ELSE 0 
    END AS avg_pages_per_visit,
    
    -- Email status
    COALESCE(c.hs_email_optout, 0) AS is_email_opted_out,
    COALESCE(c.hs_email_bounce, 0) AS has_email_bounced,
    COALESCE(c.hs_email_quarantined, 0) AS is_email_quarantined,
    
    -- Engagement metrics from CTE
    COALESCE(ce.total_engagements, 0) AS total_engagements,
    COALESCE(ce.total_calls, 0) AS total_calls,
    COALESCE(ce.total_meetings, 0) AS total_meetings,
    COALESCE(ce.total_emails, 0) AS total_emails,
    COALESCE(ce.total_notes, 0) AS total_notes,
    COALESCE(ce.total_tasks, 0) AS total_tasks,
    ce.last_engagement_date,
    ce.first_engagement_date,
    COALESCE(ce.engagements_last_30_days, 0) AS engagements_last_30_days,
    COALESCE(ce.engagements_last_90_days, 0) AS engagements_last_90_days,
    
    -- Engagement velocity (engagements per month since created)
    CASE 
        WHEN DATEDIFF(MONTH, c.created_at, GETDATE()) > 0 
        THEN CAST(COALESCE(ce.total_engagements, 0) * 1.0 / DATEDIFF(MONTH, c.created_at, GETDATE()) AS DECIMAL(10, 2))
        ELSE COALESCE(ce.total_engagements, 0)
    END AS engagements_per_month,
    
    -- Contact scoring indicators
    CASE 
        WHEN c.lifecycle_stage = 'customer' THEN 'Customer'
        WHEN c.lifecycle_stage = 'opportunity' THEN 'Opportunity'
        WHEN c.lifecycle_stage = 'salesqualifiedlead' THEN 'SQL'
        WHEN c.lifecycle_stage = 'marketingqualifiedlead' THEN 'MQL'
        WHEN c.lifecycle_stage = 'lead' THEN 'Lead'
        WHEN c.lifecycle_stage = 'subscriber' THEN 'Subscriber'
        ELSE COALESCE(c.lifecycle_stage, 'Unknown')
    END AS lifecycle_stage_display,
    
    -- Engagement status classification
    CASE 
        WHEN ce.engagements_last_30_days > 0 THEN 'Active'
        WHEN ce.engagements_last_90_days > 0 THEN 'Warm'
        WHEN ce.total_engagements > 0 THEN 'Cold'
        ELSE 'No Engagements'
    END AS engagement_status,
    
    -- Revenue per engagement
    CASE 
        WHEN COALESCE(ce.total_engagements, 0) > 0 
        THEN CAST(COALESCE(c.total_revenue, 0) / ce.total_engagements AS DECIMAL(18, 2))
        ELSE 0 
    END AS revenue_per_engagement,
    
    -- Metadata
    c._fivetran_synced AS last_synced_at

FROM hubspot.contact c
LEFT JOIN hubspot.owner o ON c.owner_id = o.owner_id AND o._fivetran_deleted = 0
LEFT JOIN hubspot.company comp ON c.associated_company_id = comp.company_id AND comp._fivetran_deleted = 0
LEFT JOIN ContactEngagements ce ON c.contact_id = ce.contact_id
WHERE c._fivetran_deleted = 0;
GO

/*
================================================================================
VIEW: vw_hubspot_contact_lifecycle_funnel
DESCRIPTION: Contact funnel analysis by lifecycle stage with conversion metrics.
             Tracks progression through marketing and sales stages.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_contact_lifecycle_funnel]
AS
WITH LifecycleStages AS (
    SELECT 
        lifecycle_stage,
        COUNT(*) AS contact_count,
        COUNT(CASE WHEN created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN 1 END) AS new_contacts_30d,
        COUNT(CASE WHEN created_at >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) THEN 1 END) AS new_contacts_90d,
        SUM(COALESCE(total_revenue, 0)) AS total_revenue,
        AVG(COALESCE(total_revenue, 0)) AS avg_revenue,
        AVG(COALESCE(hs_analytics_num_page_views, 0)) AS avg_page_views,
        AVG(COALESCE(hs_analytics_num_visits, 0)) AS avg_visits
    FROM hubspot.contact
    WHERE _fivetran_deleted = 0
    GROUP BY lifecycle_stage
)
SELECT 
    COALESCE(ls.lifecycle_stage, 'Unknown') AS lifecycle_stage,
    CASE 
        WHEN ls.lifecycle_stage = 'customer' THEN 1
        WHEN ls.lifecycle_stage = 'opportunity' THEN 2
        WHEN ls.lifecycle_stage = 'salesqualifiedlead' THEN 3
        WHEN ls.lifecycle_stage = 'marketingqualifiedlead' THEN 4
        WHEN ls.lifecycle_stage = 'lead' THEN 5
        WHEN ls.lifecycle_stage = 'subscriber' THEN 6
        ELSE 7
    END AS stage_order,
    CASE 
        WHEN ls.lifecycle_stage = 'customer' THEN 'Customer'
        WHEN ls.lifecycle_stage = 'opportunity' THEN 'Opportunity'
        WHEN ls.lifecycle_stage = 'salesqualifiedlead' THEN 'SQL'
        WHEN ls.lifecycle_stage = 'marketingqualifiedlead' THEN 'MQL'
        WHEN ls.lifecycle_stage = 'lead' THEN 'Lead'
        WHEN ls.lifecycle_stage = 'subscriber' THEN 'Subscriber'
        ELSE 'Other'
    END AS stage_display_name,
    ls.contact_count,
    ls.new_contacts_30d,
    ls.new_contacts_90d,
    ls.total_revenue,
    ls.avg_revenue,
    ls.avg_page_views,
    ls.avg_visits,
    -- Percentage of total contacts
    CAST(ls.contact_count * 100.0 / NULLIF(SUM(ls.contact_count) OVER (), 0) AS DECIMAL(10, 2)) AS pct_of_total
FROM LifecycleStages ls;
GO

/*
================================================================================
VIEW: vw_hubspot_contact_source_performance
DESCRIPTION: Contact acquisition source analysis with performance metrics.
             Tracks which sources generate the best quality contacts.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_contact_source_performance]
AS
SELECT 
    COALESCE(hs_analytics_source, 'Unknown') AS acquisition_source,
    hs_analytics_source_data_1 AS source_detail_1,
    hs_analytics_source_data_2 AS source_detail_2,
    COUNT(*) AS total_contacts,
    COUNT(CASE WHEN created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN 1 END) AS new_contacts_30d,
    
    -- Lifecycle stage distribution
    COUNT(CASE WHEN lifecycle_stage = 'customer' THEN 1 END) AS customers,
    COUNT(CASE WHEN lifecycle_stage IN ('opportunity', 'salesqualifiedlead') THEN 1 END) AS sales_qualified,
    COUNT(CASE WHEN lifecycle_stage = 'marketingqualifiedlead' THEN 1 END) AS marketing_qualified,
    COUNT(CASE WHEN lifecycle_stage IN ('lead', 'subscriber') THEN 1 END) AS leads_subscribers,
    
    -- Conversion rates
    CASE WHEN COUNT(*) > 0 
         THEN CAST(COUNT(CASE WHEN lifecycle_stage = 'customer' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(10, 2))
         ELSE 0 END AS customer_conversion_rate,
    CASE WHEN COUNT(*) > 0 
         THEN CAST(COUNT(CASE WHEN lifecycle_stage IN ('customer', 'opportunity', 'salesqualifiedlead') THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(10, 2))
         ELSE 0 END AS sales_qualified_rate,
    
    -- Revenue metrics
    SUM(COALESCE(total_revenue, 0)) AS total_revenue,
    AVG(COALESCE(total_revenue, 0)) AS avg_revenue_per_contact,
    CASE WHEN COUNT(*) > 0 
         THEN SUM(COALESCE(total_revenue, 0)) / COUNT(*)
         ELSE 0 END AS revenue_per_contact,
    
    -- Engagement metrics
    AVG(COALESCE(hs_analytics_num_page_views, 0)) AS avg_page_views,
    AVG(COALESCE(hs_analytics_num_visits, 0)) AS avg_visits,
    
    -- Deal metrics
    SUM(COALESCE(num_associated_deals, 0)) AS total_deals,
    AVG(COALESCE(num_associated_deals, 0)) AS avg_deals_per_contact

FROM hubspot.contact
WHERE _fivetran_deleted = 0
GROUP BY hs_analytics_source, hs_analytics_source_data_1, hs_analytics_source_data_2;
GO

/*
================================================================================
VIEW: vw_hubspot_contact_owner_performance
DESCRIPTION: Contact owner/sales rep performance analysis.
             Tracks owner productivity and contact quality.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_contact_owner_performance]
AS
SELECT 
    c.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Contact counts
    COUNT(DISTINCT c.contact_id) AS total_contacts,
    COUNT(DISTINCT CASE WHEN c.created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN c.contact_id END) AS new_contacts_30d,
    
    -- Lifecycle distribution
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'customer' THEN c.contact_id END) AS customers,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'opportunity' THEN c.contact_id END) AS opportunities,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'salesqualifiedlead' THEN c.contact_id END) AS sqls,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'marketingqualifiedlead' THEN c.contact_id END) AS mqls,
    
    -- Conversion rate
    CASE WHEN COUNT(DISTINCT c.contact_id) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'customer' THEN c.contact_id END) * 100.0 
                   / COUNT(DISTINCT c.contact_id) AS DECIMAL(10, 2))
         ELSE 0 END AS customer_conversion_rate,
    
    -- Revenue metrics
    SUM(COALESCE(c.total_revenue, 0)) AS total_revenue,
    AVG(COALESCE(c.total_revenue, 0)) AS avg_revenue_per_contact,
    
    -- Deal metrics
    SUM(COALESCE(c.num_associated_deals, 0)) AS total_deals,
    AVG(COALESCE(c.num_associated_deals, 0)) AS avg_deals_per_contact,
    
    -- Activity metrics
    COUNT(DISTINCT CASE WHEN c.last_activity_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN c.contact_id END) AS active_contacts_30d,
    AVG(DATEDIFF(DAY, c.last_contacted, GETDATE())) AS avg_days_since_last_contact

FROM hubspot.contact c
LEFT JOIN hubspot.owner o ON c.owner_id = o.owner_id AND o._fivetran_deleted = 0
WHERE c._fivetran_deleted = 0
  AND c.owner_id IS NOT NULL
GROUP BY c.owner_id, o.first_name, o.last_name, o.email;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Contact-level metrics and engagement tracking from HubSpot CRM.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_contact_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Contact funnel analysis by lifecycle stage with conversion metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_contact_lifecycle_funnel';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Contact acquisition source analysis with performance metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_contact_source_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Contact owner/sales rep performance analysis.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_contact_owner_performance';
GO
