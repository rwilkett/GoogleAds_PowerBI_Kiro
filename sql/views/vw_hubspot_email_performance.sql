/*
================================================================================
VIEW: vw_hubspot_email_performance
DESCRIPTION: Email campaign metrics including opens, clicks, bounces, and deliverability
             from HubSpot marketing email events. Provides comprehensive email 
             analytics for campaign performance and engagement tracking.
SCHEMA TABLES:
  - hubspot.email_campaign: Email campaign definitions
    Columns: campaign_id, app_id, app_name, content_id, subject, name, type,
             num_included, num_queued
  - hubspot.email_event: Email event records (all event types)
    Columns: event_id, email_campaign_id, recipient, type, created_at,
             sent_by_created_at, browser_name, device_type, location_city,
             location_state, location_country, url, bounce_category, drop_reason
  - hubspot.email_event_sent: Sent email event details
    Columns: event_id, from_email, subject
  - hubspot.email_event_open: Open event details
    Columns: event_id, browser, ip_address, location, user_agent, duration
  - hubspot.email_event_click: Click event details
    Columns: event_id, url, browser, ip_address, location
  - hubspot.email_event_bounce: Bounce event details
    Columns: event_id, category, response, status
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_email_performance]
AS
WITH EmailMetrics AS (
    SELECT 
        ee.email_campaign_id,
        -- Event counts
        COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.event_id END) AS sent_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'DELIVERED' THEN ee.event_id END) AS delivered_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.event_id END) AS open_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'CLICK' THEN ee.event_id END) AS click_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'BOUNCE' THEN ee.event_id END) AS bounce_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'UNSUBSCRIBED' THEN ee.event_id END) AS unsubscribe_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'SPAMREPORT' THEN ee.event_id END) AS spam_report_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'DROPPED' THEN ee.event_id END) AS dropped_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'DEFERRED' THEN ee.event_id END) AS deferred_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'FORWARD' THEN ee.event_id END) AS forward_count,
        COUNT(DISTINCT CASE WHEN ee.type = 'PRINT' THEN ee.event_id END) AS print_count,
        
        -- Unique recipient counts
        COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.recipient END) AS unique_recipients,
        COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.recipient END) AS unique_opens,
        COUNT(DISTINCT CASE WHEN ee.type = 'CLICK' THEN ee.recipient END) AS unique_clicks,
        COUNT(DISTINCT CASE WHEN ee.type = 'BOUNCE' THEN ee.recipient END) AS unique_bounces,
        COUNT(DISTINCT CASE WHEN ee.type = 'UNSUBSCRIBED' THEN ee.recipient END) AS unique_unsubscribes,
        
        -- Time metrics
        MIN(CASE WHEN ee.type = 'SENT' THEN ee.created_at END) AS first_sent_at,
        MAX(CASE WHEN ee.type = 'SENT' THEN ee.created_at END) AS last_sent_at,
        MIN(CASE WHEN ee.type = 'OPEN' THEN ee.created_at END) AS first_open_at,
        MAX(CASE WHEN ee.type = 'OPEN' THEN ee.created_at END) AS last_open_at,
        
        -- Device type distribution
        COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'MOBILE' THEN ee.event_id END) AS mobile_opens,
        COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'DESKTOP' THEN ee.event_id END) AS desktop_opens,
        COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'TABLET' THEN ee.event_id END) AS tablet_opens
        
    FROM hubspot.email_event ee
    WHERE ee.email_campaign_id IS NOT NULL
    GROUP BY ee.email_campaign_id
)
SELECT 
    -- Campaign identifiers
    ec.campaign_id,
    ec.name AS campaign_name,
    ec.subject AS email_subject,
    ec.type AS campaign_type,
    ec.app_name,
    ec.content_id,
    
    -- Campaign setup metrics
    COALESCE(ec.num_included, 0) AS num_included,
    COALESCE(ec.num_queued, 0) AS num_queued,
    
    -- Raw event counts
    COALESCE(em.sent_count, 0) AS sent_count,
    COALESCE(em.delivered_count, 0) AS delivered_count,
    COALESCE(em.open_count, 0) AS total_opens,
    COALESCE(em.click_count, 0) AS total_clicks,
    COALESCE(em.bounce_count, 0) AS bounce_count,
    COALESCE(em.unsubscribe_count, 0) AS unsubscribe_count,
    COALESCE(em.spam_report_count, 0) AS spam_report_count,
    COALESCE(em.dropped_count, 0) AS dropped_count,
    COALESCE(em.deferred_count, 0) AS deferred_count,
    COALESCE(em.forward_count, 0) AS forward_count,
    COALESCE(em.print_count, 0) AS print_count,
    
    -- Unique metrics
    COALESCE(em.unique_recipients, 0) AS unique_recipients,
    COALESCE(em.unique_opens, 0) AS unique_opens,
    COALESCE(em.unique_clicks, 0) AS unique_clicks,
    COALESCE(em.unique_bounces, 0) AS unique_bounces,
    COALESCE(em.unique_unsubscribes, 0) AS unique_unsubscribes,
    
    -- Calculated rates (based on sent)
    CASE WHEN COALESCE(em.sent_count, 0) > 0 
         THEN CAST(COALESCE(em.delivered_count, 0) * 100.0 / em.sent_count AS DECIMAL(10, 2))
         ELSE 0 END AS delivery_rate,
    
    CASE WHEN COALESCE(em.sent_count, 0) > 0 
         THEN CAST(COALESCE(em.bounce_count, 0) * 100.0 / em.sent_count AS DECIMAL(10, 2))
         ELSE 0 END AS bounce_rate,
    
    -- Calculated rates (based on delivered)
    CASE WHEN COALESCE(em.delivered_count, 0) > 0 
         THEN CAST(COALESCE(em.unique_opens, 0) * 100.0 / em.delivered_count AS DECIMAL(10, 2))
         ELSE 0 END AS unique_open_rate,
    
    CASE WHEN COALESCE(em.delivered_count, 0) > 0 
         THEN CAST(COALESCE(em.open_count, 0) * 100.0 / em.delivered_count AS DECIMAL(10, 2))
         ELSE 0 END AS total_open_rate,
    
    CASE WHEN COALESCE(em.delivered_count, 0) > 0 
         THEN CAST(COALESCE(em.unique_clicks, 0) * 100.0 / em.delivered_count AS DECIMAL(10, 2))
         ELSE 0 END AS unique_click_rate,
    
    CASE WHEN COALESCE(em.delivered_count, 0) > 0 
         THEN CAST(COALESCE(em.click_count, 0) * 100.0 / em.delivered_count AS DECIMAL(10, 2))
         ELSE 0 END AS total_click_rate,
    
    -- Click-to-open rate
    CASE WHEN COALESCE(em.unique_opens, 0) > 0 
         THEN CAST(COALESCE(em.unique_clicks, 0) * 100.0 / em.unique_opens AS DECIMAL(10, 2))
         ELSE 0 END AS click_to_open_rate,
    
    -- Unsubscribe rate
    CASE WHEN COALESCE(em.delivered_count, 0) > 0 
         THEN CAST(COALESCE(em.unsubscribe_count, 0) * 100.0 / em.delivered_count AS DECIMAL(10, 2))
         ELSE 0 END AS unsubscribe_rate,
    
    -- Spam complaint rate
    CASE WHEN COALESCE(em.delivered_count, 0) > 0 
         THEN CAST(COALESCE(em.spam_report_count, 0) * 100.0 / em.delivered_count AS DECIMAL(10, 4))
         ELSE 0 END AS spam_complaint_rate,
    
    -- Engagement metrics
    CASE WHEN COALESCE(em.unique_opens, 0) > 0 
         THEN CAST(COALESCE(em.open_count, 0) * 1.0 / em.unique_opens AS DECIMAL(10, 2))
         ELSE 0 END AS avg_opens_per_recipient,
    
    CASE WHEN COALESCE(em.unique_clicks, 0) > 0 
         THEN CAST(COALESCE(em.click_count, 0) * 1.0 / em.unique_clicks AS DECIMAL(10, 2))
         ELSE 0 END AS avg_clicks_per_clicker,
    
    -- Device distribution
    COALESCE(em.mobile_opens, 0) AS mobile_opens,
    COALESCE(em.desktop_opens, 0) AS desktop_opens,
    COALESCE(em.tablet_opens, 0) AS tablet_opens,
    
    CASE WHEN COALESCE(em.open_count, 0) > 0 
         THEN CAST(COALESCE(em.mobile_opens, 0) * 100.0 / em.open_count AS DECIMAL(10, 2))
         ELSE 0 END AS mobile_open_pct,
    
    CASE WHEN COALESCE(em.open_count, 0) > 0 
         THEN CAST(COALESCE(em.desktop_opens, 0) * 100.0 / em.open_count AS DECIMAL(10, 2))
         ELSE 0 END AS desktop_open_pct,
    
    -- Time metrics
    em.first_sent_at,
    em.last_sent_at,
    em.first_open_at,
    em.last_open_at,
    CONVERT(INT, FORMAT(em.first_sent_at, 'yyyyMMdd')) AS first_sent_date_id,
    
    -- Time to first open (hours)
    CASE 
        WHEN em.first_sent_at IS NOT NULL AND em.first_open_at IS NOT NULL 
        THEN DATEDIFF(HOUR, em.first_sent_at, em.first_open_at)
        ELSE NULL 
    END AS hours_to_first_open,
    
    -- Campaign performance tier
    CASE 
        WHEN CASE WHEN COALESCE(em.delivered_count, 0) > 0 
                  THEN em.unique_opens * 100.0 / em.delivered_count 
                  ELSE 0 END >= 30 THEN 'Excellent'
        WHEN CASE WHEN COALESCE(em.delivered_count, 0) > 0 
                  THEN em.unique_opens * 100.0 / em.delivered_count 
                  ELSE 0 END >= 20 THEN 'Good'
        WHEN CASE WHEN COALESCE(em.delivered_count, 0) > 0 
                  THEN em.unique_opens * 100.0 / em.delivered_count 
                  ELSE 0 END >= 10 THEN 'Average'
        ELSE 'Needs Improvement'
    END AS performance_tier,
    
    -- Metadata
    ec._fivetran_synced AS last_synced_at

FROM hubspot.email_campaign ec
LEFT JOIN EmailMetrics em ON ec.campaign_id = em.email_campaign_id
WHERE ec._fivetran_deleted = 0;
GO

/*
================================================================================
VIEW: vw_hubspot_email_daily_metrics
DESCRIPTION: Daily email performance metrics for trend analysis.
             Aggregates email events by date for time series reporting.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_email_daily_metrics]
AS
SELECT 
    CAST(ee.created_at AS DATE) AS event_date,
    CONVERT(INT, FORMAT(ee.created_at, 'yyyyMMdd')) AS date_id,
    ee.email_campaign_id,
    ec.name AS campaign_name,
    
    -- Daily event counts
    COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.event_id END) AS sent_count,
    COUNT(DISTINCT CASE WHEN ee.type = 'DELIVERED' THEN ee.event_id END) AS delivered_count,
    COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.event_id END) AS open_count,
    COUNT(DISTINCT CASE WHEN ee.type = 'CLICK' THEN ee.event_id END) AS click_count,
    COUNT(DISTINCT CASE WHEN ee.type = 'BOUNCE' THEN ee.event_id END) AS bounce_count,
    COUNT(DISTINCT CASE WHEN ee.type = 'UNSUBSCRIBED' THEN ee.event_id END) AS unsubscribe_count,
    
    -- Unique recipient counts
    COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.recipient END) AS unique_opens,
    COUNT(DISTINCT CASE WHEN ee.type = 'CLICK' THEN ee.recipient END) AS unique_clicks,
    
    -- Device breakdown
    COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'MOBILE' THEN ee.event_id END) AS mobile_opens,
    COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'DESKTOP' THEN ee.event_id END) AS desktop_opens

FROM hubspot.email_event ee
LEFT JOIN hubspot.email_campaign ec ON ee.email_campaign_id = ec.campaign_id AND ec._fivetran_deleted = 0
WHERE ee.created_at IS NOT NULL
GROUP BY CAST(ee.created_at AS DATE), ee.email_campaign_id, ec.name;
GO

/*
================================================================================
VIEW: vw_hubspot_email_bounce_analysis
DESCRIPTION: Email bounce analysis by category and reason.
             Helps identify deliverability issues and list hygiene needs.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_email_bounce_analysis]
AS
SELECT 
    ee.email_campaign_id,
    ec.name AS campaign_name,
    COALESCE(ee.bounce_category, eeb.category, 'Unknown') AS bounce_category,
    COALESCE(eeb.status, 'Unknown') AS bounce_status,
    COUNT(DISTINCT ee.event_id) AS bounce_count,
    COUNT(DISTINCT ee.recipient) AS unique_bounced_recipients,
    
    -- Sample response messages (for debugging)
    MAX(eeb.response) AS sample_response

FROM hubspot.email_event ee
LEFT JOIN hubspot.email_event_bounce eeb ON ee.event_id = eeb.event_id
LEFT JOIN hubspot.email_campaign ec ON ee.email_campaign_id = ec.campaign_id AND ec._fivetran_deleted = 0
WHERE ee.type = 'BOUNCE'
GROUP BY ee.email_campaign_id, ec.name, COALESCE(ee.bounce_category, eeb.category, 'Unknown'), COALESCE(eeb.status, 'Unknown');
GO

/*
================================================================================
VIEW: vw_hubspot_email_link_performance
DESCRIPTION: Email link click analysis by URL.
             Tracks which links drive the most engagement.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_email_link_performance]
AS
SELECT 
    ee.email_campaign_id,
    ec.name AS campaign_name,
    COALESCE(eec.url, ee.url) AS click_url,
    COUNT(DISTINCT ee.event_id) AS total_clicks,
    COUNT(DISTINCT ee.recipient) AS unique_clickers,
    
    -- Click timing
    MIN(ee.created_at) AS first_click_at,
    MAX(ee.created_at) AS last_click_at,
    
    -- Device breakdown
    COUNT(DISTINCT CASE WHEN ee.device_type = 'MOBILE' THEN ee.event_id END) AS mobile_clicks,
    COUNT(DISTINCT CASE WHEN ee.device_type = 'DESKTOP' THEN ee.event_id END) AS desktop_clicks,
    
    -- Location breakdown (top country)
    MAX(ee.location_country) AS top_click_country

FROM hubspot.email_event ee
LEFT JOIN hubspot.email_event_click eec ON ee.event_id = eec.event_id
LEFT JOIN hubspot.email_campaign ec ON ee.email_campaign_id = ec.campaign_id AND ec._fivetran_deleted = 0
WHERE ee.type = 'CLICK'
  AND (eec.url IS NOT NULL OR ee.url IS NOT NULL)
GROUP BY ee.email_campaign_id, ec.name, COALESCE(eec.url, ee.url);
GO

/*
================================================================================
VIEW: vw_hubspot_email_engagement_by_time
DESCRIPTION: Email engagement patterns by hour and day of week.
             Helps optimize email send timing.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_email_engagement_by_time]
AS
SELECT 
    DATEPART(HOUR, ee.created_at) AS hour_of_day,
    DATENAME(WEEKDAY, ee.created_at) AS day_of_week,
    DATEPART(WEEKDAY, ee.created_at) AS day_of_week_num,
    ee.type AS event_type,
    COUNT(DISTINCT ee.event_id) AS event_count,
    COUNT(DISTINCT ee.recipient) AS unique_recipients,
    COUNT(DISTINCT ee.email_campaign_id) AS campaign_count

FROM hubspot.email_event ee
WHERE ee.type IN ('OPEN', 'CLICK')
  AND ee.created_at IS NOT NULL
GROUP BY DATEPART(HOUR, ee.created_at), DATENAME(WEEKDAY, ee.created_at), DATEPART(WEEKDAY, ee.created_at), ee.type;
GO

/*
================================================================================
VIEW: vw_hubspot_email_recipient_engagement
DESCRIPTION: Individual recipient engagement metrics across email campaigns.
             Identifies highly engaged and unengaged contacts.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_email_recipient_engagement]
AS
SELECT 
    ee.recipient AS email_address,
    COUNT(DISTINCT ee.email_campaign_id) AS campaigns_received,
    COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.email_campaign_id END) AS campaigns_sent,
    COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.email_campaign_id END) AS campaigns_opened,
    COUNT(DISTINCT CASE WHEN ee.type = 'CLICK' THEN ee.email_campaign_id END) AS campaigns_clicked,
    
    -- Total events
    COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.event_id END) AS total_emails_sent,
    COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.event_id END) AS total_opens,
    COUNT(DISTINCT CASE WHEN ee.type = 'CLICK' THEN ee.event_id END) AS total_clicks,
    
    -- Engagement rates
    CASE WHEN COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.email_campaign_id END) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.email_campaign_id END) * 100.0 
                   / COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.email_campaign_id END) AS DECIMAL(10, 2))
         ELSE 0 END AS campaign_open_rate,
    
    CASE WHEN COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.email_campaign_id END) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN ee.type = 'CLICK' THEN ee.email_campaign_id END) * 100.0 
                   / COUNT(DISTINCT CASE WHEN ee.type = 'SENT' THEN ee.email_campaign_id END) AS DECIMAL(10, 2))
         ELSE 0 END AS campaign_click_rate,
    
    -- Timing
    MIN(CASE WHEN ee.type = 'SENT' THEN ee.created_at END) AS first_email_sent,
    MAX(CASE WHEN ee.type = 'SENT' THEN ee.created_at END) AS last_email_sent,
    MAX(CASE WHEN ee.type = 'OPEN' THEN ee.created_at END) AS last_open,
    MAX(CASE WHEN ee.type = 'CLICK' THEN ee.created_at END) AS last_click,
    
    -- Engagement status
    CASE 
        WHEN MAX(CASE WHEN ee.type = 'CLICK' THEN ee.created_at END) >= DATEADD(DAY, -30, GETDATE()) THEN 'Highly Engaged'
        WHEN MAX(CASE WHEN ee.type = 'OPEN' THEN ee.created_at END) >= DATEADD(DAY, -30, GETDATE()) THEN 'Engaged'
        WHEN MAX(CASE WHEN ee.type = 'OPEN' THEN ee.created_at END) >= DATEADD(DAY, -90, GETDATE()) THEN 'Somewhat Engaged'
        WHEN COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' THEN ee.event_id END) > 0 THEN 'Previously Engaged'
        ELSE 'Never Engaged'
    END AS engagement_status,
    
    -- Device preference
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'MOBILE' THEN ee.event_id END) >
             COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'DESKTOP' THEN ee.event_id END)
        THEN 'Mobile'
        WHEN COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'DESKTOP' THEN ee.event_id END) >
             COUNT(DISTINCT CASE WHEN ee.type = 'OPEN' AND ee.device_type = 'MOBILE' THEN ee.event_id END)
        THEN 'Desktop'
        ELSE 'Mixed/Unknown'
    END AS preferred_device

FROM hubspot.email_event ee
WHERE ee.recipient IS NOT NULL
GROUP BY ee.recipient;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Email campaign metrics including opens, clicks, bounces, and deliverability.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_email_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily email performance metrics for trend analysis.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_email_daily_metrics';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Email bounce analysis by category and reason.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_email_bounce_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Email link click analysis by URL.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_email_link_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Email engagement patterns by hour and day of week.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_email_engagement_by_time';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Individual recipient engagement metrics across email campaigns.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_email_recipient_engagement';
GO
