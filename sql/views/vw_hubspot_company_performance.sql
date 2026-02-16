/*
================================================================================
VIEW: vw_hubspot_company_performance
DESCRIPTION: Company/account-level metrics and insights from HubSpot CRM.
             Provides comprehensive company analytics including associated contacts,
             deals, and engagement tracking for account-based reporting.
SCHEMA TABLES:
  - hubspot.company: Company records with properties and analytics
    Columns: company_id, name, domain, industry, type, phone, city, state, country,
             postal_code, owner_id, lifecycle_stage, lead_status, num_employees,
             annual_revenue, total_revenue, num_associated_contacts, num_associated_deals,
             created_at, updated_at, last_activity_date, last_contacted,
             hs_analytics_source, hs_analytics_num_page_views, hs_analytics_num_visits
  - hubspot.owner: Owner/sales rep records
    Columns: owner_id, email, first_name, last_name
  - hubspot.contact: Associated contact records
    Columns: contact_id, associated_company_id, lifecycle_stage, total_revenue
  - hubspot.deal: Associated deal records
    Columns: deal_id, associated_company_id, amount, deal_stage, is_closed_won
  - hubspot.engagement_company: Company engagement associations
    Columns: engagement_id, company_id
  - hubspot.engagement: Engagement activity records
    Columns: engagement_id, type, timestamp
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_company_performance]
AS
WITH CompanyEngagements AS (
    SELECT 
        ec.company_id,
        COUNT(DISTINCT e.engagement_id) AS total_engagements,
        COUNT(DISTINCT CASE WHEN e.type = 'CALL' THEN e.engagement_id END) AS total_calls,
        COUNT(DISTINCT CASE WHEN e.type = 'MEETING' THEN e.engagement_id END) AS total_meetings,
        COUNT(DISTINCT CASE WHEN e.type = 'EMAIL' THEN e.engagement_id END) AS total_emails,
        COUNT(DISTINCT CASE WHEN e.type = 'NOTE' THEN e.engagement_id END) AS total_notes,
        COUNT(DISTINCT CASE WHEN e.type = 'TASK' THEN e.engagement_id END) AS total_tasks,
        MAX(e.timestamp) AS last_engagement_date,
        MIN(e.timestamp) AS first_engagement_date,
        COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
                            THEN e.engagement_id END) AS engagements_last_30_days,
        COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) 
                            THEN e.engagement_id END) AS engagements_last_90_days
    FROM hubspot.engagement_company ec
    INNER JOIN hubspot.engagement e ON ec.engagement_id = e.engagement_id
    WHERE e._fivetran_deleted = 0
    GROUP BY ec.company_id
),
CompanyContacts AS (
    SELECT 
        associated_company_id AS company_id,
        COUNT(DISTINCT contact_id) AS contact_count,
        COUNT(DISTINCT CASE WHEN lifecycle_stage = 'customer' THEN contact_id END) AS customer_contacts,
        COUNT(DISTINCT CASE WHEN lifecycle_stage IN ('opportunity', 'salesqualifiedlead') THEN contact_id END) AS sales_qualified_contacts,
        COUNT(DISTINCT CASE WHEN lifecycle_stage = 'marketingqualifiedlead' THEN contact_id END) AS mql_contacts,
        SUM(COALESCE(total_revenue, 0)) AS contact_total_revenue
    FROM hubspot.contact
    WHERE _fivetran_deleted = 0
      AND associated_company_id IS NOT NULL
    GROUP BY associated_company_id
),
CompanyDeals AS (
    SELECT 
        associated_company_id AS company_id,
        COUNT(DISTINCT deal_id) AS total_deals,
        COUNT(DISTINCT CASE WHEN is_closed_won = 1 THEN deal_id END) AS won_deals,
        COUNT(DISTINCT CASE WHEN is_closed = 1 AND is_closed_won = 0 THEN deal_id END) AS lost_deals,
        COUNT(DISTINCT CASE WHEN is_closed = 0 THEN deal_id END) AS open_deals,
        SUM(CASE WHEN is_closed_won = 1 THEN COALESCE(amount, 0) ELSE 0 END) AS closed_won_revenue,
        SUM(CASE WHEN is_closed = 0 THEN COALESCE(amount, 0) ELSE 0 END) AS pipeline_value,
        AVG(CASE WHEN is_closed_won = 1 THEN amount END) AS avg_won_deal_size,
        AVG(CASE WHEN is_closed_won = 1 THEN days_to_close END) AS avg_days_to_close
    FROM hubspot.deal
    WHERE _fivetran_deleted = 0
      AND associated_company_id IS NOT NULL
    GROUP BY associated_company_id
)
SELECT 
    -- Company identifiers
    c.company_id,
    c.name AS company_name,
    c.domain,
    c.industry,
    c.type AS company_type,
    
    -- Contact information
    c.phone,
    c.city,
    c.state,
    c.country,
    c.postal_code,
    
    -- Location combined
    CONCAT(COALESCE(c.city, ''), 
           CASE WHEN c.city IS NOT NULL AND c.state IS NOT NULL THEN ', ' ELSE '' END,
           COALESCE(c.state, ''),
           CASE WHEN (c.city IS NOT NULL OR c.state IS NOT NULL) AND c.country IS NOT NULL THEN ', ' ELSE '' END,
           COALESCE(c.country, '')) AS location,
    
    -- Owner information
    c.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Lifecycle and status
    c.lifecycle_stage,
    c.lead_status,
    
    -- Company size and revenue
    c.num_employees,
    c.annual_revenue,
    COALESCE(c.total_revenue, 0) AS total_revenue,
    
    -- Timestamps
    c.created_at,
    c.updated_at,
    c.last_activity_date,
    c.last_contacted,
    CONVERT(INT, FORMAT(c.created_at, 'yyyyMMdd')) AS created_date_id,
    
    -- Company age
    DATEDIFF(DAY, c.created_at, GETDATE()) AS company_age_days,
    
    -- Days since last activity
    CASE 
        WHEN c.last_activity_date IS NOT NULL 
        THEN DATEDIFF(DAY, c.last_activity_date, GETDATE())
        ELSE NULL 
    END AS days_since_last_activity,
    
    -- Analytics source
    c.hs_analytics_source,
    COALESCE(c.hs_analytics_num_page_views, 0) AS total_page_views,
    COALESCE(c.hs_analytics_num_visits, 0) AS total_visits,
    
    -- Associated contacts (from schema fields)
    COALESCE(c.num_associated_contacts, 0) AS num_associated_contacts,
    COALESCE(c.num_associated_deals, 0) AS num_associated_deals,
    
    -- Contact metrics from CTE
    COALESCE(cc.contact_count, 0) AS calculated_contact_count,
    COALESCE(cc.customer_contacts, 0) AS customer_contacts,
    COALESCE(cc.sales_qualified_contacts, 0) AS sales_qualified_contacts,
    COALESCE(cc.mql_contacts, 0) AS mql_contacts,
    COALESCE(cc.contact_total_revenue, 0) AS contact_attributed_revenue,
    
    -- Deal metrics from CTE
    COALESCE(cd.total_deals, 0) AS total_deals,
    COALESCE(cd.won_deals, 0) AS won_deals,
    COALESCE(cd.lost_deals, 0) AS lost_deals,
    COALESCE(cd.open_deals, 0) AS open_deals,
    COALESCE(cd.closed_won_revenue, 0) AS closed_won_revenue,
    COALESCE(cd.pipeline_value, 0) AS pipeline_value,
    cd.avg_won_deal_size,
    cd.avg_days_to_close,
    
    -- Deal win rate
    CASE 
        WHEN COALESCE(cd.total_deals, 0) > 0 
        THEN CAST(COALESCE(cd.won_deals, 0) * 100.0 / cd.total_deals AS DECIMAL(10, 2))
        ELSE 0 
    END AS deal_win_rate,
    
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
    
    -- Engagement velocity
    CASE 
        WHEN DATEDIFF(MONTH, c.created_at, GETDATE()) > 0 
        THEN CAST(COALESCE(ce.total_engagements, 0) * 1.0 / DATEDIFF(MONTH, c.created_at, GETDATE()) AS DECIMAL(10, 2))
        ELSE COALESCE(ce.total_engagements, 0)
    END AS engagements_per_month,
    
    -- Account health score (composite)
    CASE 
        WHEN COALESCE(ce.engagements_last_30_days, 0) > 0 AND COALESCE(cd.open_deals, 0) > 0 THEN 'Highly Active'
        WHEN COALESCE(ce.engagements_last_30_days, 0) > 0 THEN 'Active'
        WHEN COALESCE(ce.engagements_last_90_days, 0) > 0 THEN 'Warm'
        WHEN COALESCE(ce.total_engagements, 0) > 0 THEN 'Cold'
        ELSE 'No Engagement'
    END AS account_health_status,
    
    -- Customer status
    CASE 
        WHEN c.lifecycle_stage = 'customer' THEN 'Customer'
        WHEN COALESCE(cd.won_deals, 0) > 0 THEN 'Customer (by deals)'
        ELSE 'Prospect'
    END AS customer_status,
    
    -- Lifetime value indicator
    COALESCE(c.total_revenue, 0) + COALESCE(cd.closed_won_revenue, 0) AS total_lifetime_value,
    
    -- Metadata
    c._fivetran_synced AS last_synced_at

FROM hubspot.company c
LEFT JOIN hubspot.owner o ON c.owner_id = o.owner_id AND o._fivetran_deleted = 0
LEFT JOIN CompanyEngagements ce ON c.company_id = ce.company_id
LEFT JOIN CompanyContacts cc ON c.company_id = cc.company_id
LEFT JOIN CompanyDeals cd ON c.company_id = cd.company_id
WHERE c._fivetran_deleted = 0;
GO

/*
================================================================================
VIEW: vw_hubspot_company_industry_analysis
DESCRIPTION: Company analysis by industry with aggregated metrics.
             Useful for industry-level reporting and targeting.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_company_industry_analysis]
AS
SELECT 
    COALESCE(c.industry, 'Unknown') AS industry,
    COUNT(DISTINCT c.company_id) AS total_companies,
    COUNT(DISTINCT CASE WHEN c.created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN c.company_id END) AS new_companies_30d,
    COUNT(DISTINCT CASE WHEN c.created_at >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) THEN c.company_id END) AS new_companies_90d,
    
    -- Lifecycle distribution
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'customer' THEN c.company_id END) AS customers,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage IN ('opportunity', 'salesqualifiedlead') THEN c.company_id END) AS sales_qualified,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'marketingqualifiedlead' THEN c.company_id END) AS marketing_qualified,
    
    -- Customer conversion rate
    CASE WHEN COUNT(DISTINCT c.company_id) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'customer' THEN c.company_id END) * 100.0 
                   / COUNT(DISTINCT c.company_id) AS DECIMAL(10, 2))
         ELSE 0 END AS customer_conversion_rate,
    
    -- Revenue metrics
    SUM(COALESCE(c.total_revenue, 0)) AS total_revenue,
    AVG(COALESCE(c.total_revenue, 0)) AS avg_revenue_per_company,
    SUM(COALESCE(c.annual_revenue, 0)) AS total_annual_revenue,
    AVG(COALESCE(c.annual_revenue, 0)) AS avg_annual_revenue,
    
    -- Contact and deal metrics
    SUM(COALESCE(c.num_associated_contacts, 0)) AS total_contacts,
    AVG(COALESCE(c.num_associated_contacts, 0)) AS avg_contacts_per_company,
    SUM(COALESCE(c.num_associated_deals, 0)) AS total_deals,
    AVG(COALESCE(c.num_associated_deals, 0)) AS avg_deals_per_company,
    
    -- Engagement metrics
    AVG(COALESCE(c.hs_analytics_num_page_views, 0)) AS avg_page_views,
    AVG(COALESCE(c.hs_analytics_num_visits, 0)) AS avg_visits

FROM hubspot.company c
WHERE c._fivetran_deleted = 0
GROUP BY c.industry;
GO

/*
================================================================================
VIEW: vw_hubspot_company_geography_analysis
DESCRIPTION: Company analysis by geographic location.
             Supports regional reporting and territory planning.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_company_geography_analysis]
AS
SELECT 
    COALESCE(c.country, 'Unknown') AS country,
    COALESCE(c.state, 'Unknown') AS state,
    COALESCE(c.city, 'Unknown') AS city,
    COUNT(DISTINCT c.company_id) AS total_companies,
    
    -- Lifecycle distribution
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'customer' THEN c.company_id END) AS customers,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage IN ('opportunity', 'salesqualifiedlead') THEN c.company_id END) AS sales_qualified,
    
    -- Revenue metrics
    SUM(COALESCE(c.total_revenue, 0)) AS total_revenue,
    AVG(COALESCE(c.total_revenue, 0)) AS avg_revenue_per_company,
    
    -- Deal metrics
    SUM(COALESCE(c.num_associated_deals, 0)) AS total_deals,
    
    -- Percentage of total
    CAST(COUNT(DISTINCT c.company_id) * 100.0 / 
         NULLIF(SUM(COUNT(DISTINCT c.company_id)) OVER (), 0) AS DECIMAL(10, 2)) AS pct_of_total

FROM hubspot.company c
WHERE c._fivetran_deleted = 0
GROUP BY c.country, c.state, c.city;
GO

/*
================================================================================
VIEW: vw_hubspot_company_owner_performance
DESCRIPTION: Company owner/sales rep performance metrics.
             Tracks account ownership and rep productivity.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_company_owner_performance]
AS
SELECT 
    c.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Company counts
    COUNT(DISTINCT c.company_id) AS total_companies,
    COUNT(DISTINCT CASE WHEN c.created_at >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN c.company_id END) AS new_companies_30d,
    
    -- Lifecycle distribution
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'customer' THEN c.company_id END) AS customers,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage IN ('opportunity', 'salesqualifiedlead') THEN c.company_id END) AS sales_qualified,
    COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'marketingqualifiedlead' THEN c.company_id END) AS marketing_qualified,
    
    -- Customer conversion rate
    CASE WHEN COUNT(DISTINCT c.company_id) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN c.lifecycle_stage = 'customer' THEN c.company_id END) * 100.0 
                   / COUNT(DISTINCT c.company_id) AS DECIMAL(10, 2))
         ELSE 0 END AS customer_conversion_rate,
    
    -- Revenue metrics
    SUM(COALESCE(c.total_revenue, 0)) AS total_revenue,
    AVG(COALESCE(c.total_revenue, 0)) AS avg_revenue_per_company,
    
    -- Contact and deal metrics
    SUM(COALESCE(c.num_associated_contacts, 0)) AS total_contacts,
    SUM(COALESCE(c.num_associated_deals, 0)) AS total_deals,
    
    -- Activity metrics
    COUNT(DISTINCT CASE WHEN c.last_activity_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN c.company_id END) AS active_companies_30d,
    AVG(DATEDIFF(DAY, c.last_contacted, GETDATE())) AS avg_days_since_last_contact

FROM hubspot.company c
LEFT JOIN hubspot.owner o ON c.owner_id = o.owner_id AND o._fivetran_deleted = 0
WHERE c._fivetran_deleted = 0
  AND c.owner_id IS NOT NULL
GROUP BY c.owner_id, o.first_name, o.last_name, o.email;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Company/account-level metrics and insights from HubSpot CRM.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_company_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Company analysis by industry with aggregated metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_company_industry_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Company analysis by geographic location.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_company_geography_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Company owner/sales rep performance metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_company_owner_performance';
GO
