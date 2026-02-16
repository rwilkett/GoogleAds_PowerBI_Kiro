/*
================================================================================
VIEW: vw_hubspot_engagement_performance
DESCRIPTION: Overall engagement metrics across all channels from HubSpot CRM.
             Provides comprehensive engagement analytics including calls, meetings,
             emails, notes, and tasks for productivity and outreach tracking.
SCHEMA TABLES:
  - hubspot.engagement: Base engagement records
    Columns: engagement_id, type, created_at, last_updated, timestamp, owner_id,
             portal_id, active
  - hubspot.engagement_contact: Contact-engagement associations
    Columns: engagement_id, contact_id
  - hubspot.engagement_company: Company-engagement associations
    Columns: engagement_id, company_id
  - hubspot.engagement_deal: Deal-engagement associations
    Columns: engagement_id, deal_id
  - hubspot.engagement_call: Call engagement details
    Columns: engagement_id, body, disposition, duration_milliseconds, status,
             from_number, to_number, recording_url
  - hubspot.engagement_meeting: Meeting engagement details
    Columns: engagement_id, body, title, start_time, end_time, meeting_outcome
  - hubspot.engagement_email: Email engagement details
    Columns: engagement_id, body, subject, from_email, to_email
  - hubspot.engagement_note: Note engagement details
    Columns: engagement_id, body
  - hubspot.engagement_task: Task engagement details
    Columns: engagement_id, body, subject, status, task_type, priority, completion_date
  - hubspot.owner: Owner/sales rep records
    Columns: owner_id, email, first_name, last_name
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_engagement_performance]
AS
SELECT 
    -- Engagement identifiers
    e.engagement_id,
    e.type AS engagement_type,
    
    -- Time information
    e.created_at,
    e.last_updated,
    e.timestamp AS engagement_timestamp,
    CAST(e.timestamp AS DATE) AS engagement_date,
    CONVERT(INT, FORMAT(e.timestamp, 'yyyyMMdd')) AS engagement_date_id,
    
    -- Time components for analysis
    DATEPART(HOUR, e.timestamp) AS hour_of_day,
    DATENAME(WEEKDAY, e.timestamp) AS day_of_week,
    DATEPART(WEEKDAY, e.timestamp) AS day_of_week_num,
    DATEPART(WEEK, e.timestamp) AS week_of_year,
    MONTH(e.timestamp) AS month_number,
    YEAR(e.timestamp) AS year_number,
    
    -- Owner information
    e.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Status
    COALESCE(e.active, 1) AS is_active,
    
    -- Call-specific fields
    ec.disposition AS call_disposition,
    COALESCE(ec.duration_milliseconds, 0) AS call_duration_ms,
    CAST(COALESCE(ec.duration_milliseconds, 0) / 1000.0 AS DECIMAL(10, 2)) AS call_duration_seconds,
    CAST(COALESCE(ec.duration_milliseconds, 0) / 60000.0 AS DECIMAL(10, 2)) AS call_duration_minutes,
    ec.status AS call_status,
    ec.from_number AS call_from_number,
    ec.to_number AS call_to_number,
    CASE WHEN ec.recording_url IS NOT NULL THEN 1 ELSE 0 END AS has_recording,
    
    -- Meeting-specific fields
    em.title AS meeting_title,
    em.start_time AS meeting_start_time,
    em.end_time AS meeting_end_time,
    CASE 
        WHEN em.start_time IS NOT NULL AND em.end_time IS NOT NULL 
        THEN DATEDIFF(MINUTE, em.start_time, em.end_time)
        ELSE NULL 
    END AS meeting_duration_minutes,
    em.meeting_outcome,
    
    -- Email-specific fields
    ee.subject AS email_subject,
    ee.from_email,
    ee.sender_email,
    
    -- Task-specific fields
    et.subject AS task_subject,
    et.status AS task_status,
    et.task_type,
    et.priority AS task_priority,
    et.completion_date AS task_completion_date,
    CASE WHEN et.status = 'COMPLETED' THEN 1 ELSE 0 END AS is_task_completed,
    
    -- Association counts
    (SELECT COUNT(*) FROM hubspot.engagement_contact ec2 WHERE ec2.engagement_id = e.engagement_id) AS associated_contact_count,
    (SELECT COUNT(*) FROM hubspot.engagement_company ec3 WHERE ec3.engagement_id = e.engagement_id) AS associated_company_count,
    (SELECT COUNT(*) FROM hubspot.engagement_deal ed WHERE ed.engagement_id = e.engagement_id) AS associated_deal_count,
    
    -- Metadata
    e._fivetran_synced AS last_synced_at

FROM hubspot.engagement e
LEFT JOIN hubspot.owner o ON e.owner_id = o.owner_id AND o._fivetran_deleted = 0
LEFT JOIN hubspot.engagement_call ec ON e.engagement_id = ec.engagement_id AND e.type = 'CALL'
LEFT JOIN hubspot.engagement_meeting em ON e.engagement_id = em.engagement_id AND e.type = 'MEETING'
LEFT JOIN hubspot.engagement_email ee ON e.engagement_id = ee.engagement_id AND e.type = 'EMAIL'
LEFT JOIN hubspot.engagement_task et ON e.engagement_id = et.engagement_id AND e.type = 'TASK'
WHERE e._fivetran_deleted = 0;
GO

/*
================================================================================
VIEW: vw_hubspot_engagement_daily_summary
DESCRIPTION: Daily engagement summary with counts by type.
             Supports trend analysis and productivity tracking.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_engagement_daily_summary]
AS
SELECT 
    CAST(e.timestamp AS DATE) AS engagement_date,
    CONVERT(INT, FORMAT(e.timestamp, 'yyyyMMdd')) AS date_id,
    DATENAME(WEEKDAY, e.timestamp) AS day_of_week,
    DATEPART(WEEKDAY, e.timestamp) AS day_of_week_num,
    
    -- Total engagements
    COUNT(DISTINCT e.engagement_id) AS total_engagements,
    
    -- Counts by type
    COUNT(DISTINCT CASE WHEN e.type = 'CALL' THEN e.engagement_id END) AS total_calls,
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' THEN e.engagement_id END) AS total_meetings,
    COUNT(DISTINCT CASE WHEN e.type = 'EMAIL' THEN e.engagement_id END) AS total_emails,
    COUNT(DISTINCT CASE WHEN e.type = 'NOTE' THEN e.engagement_id END) AS total_notes,
    COUNT(DISTINCT CASE WHEN e.type = 'TASK' THEN e.engagement_id END) AS total_tasks,
    
    -- Active owner count
    COUNT(DISTINCT e.owner_id) AS active_owners,
    
    -- Call metrics
    SUM(CASE WHEN e.type = 'CALL' THEN COALESCE(ec.duration_milliseconds, 0) ELSE 0 END) / 60000.0 AS total_call_minutes,
    AVG(CASE WHEN e.type = 'CALL' AND ec.duration_milliseconds > 0 
             THEN CAST(ec.duration_milliseconds / 60000.0 AS DECIMAL(10, 2)) END) AS avg_call_minutes,
    
    -- Meeting metrics
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND em.meeting_outcome = 'SCHEDULED' THEN e.engagement_id END) AS meetings_scheduled,
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND em.meeting_outcome = 'COMPLETED' THEN e.engagement_id END) AS meetings_completed,
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND em.meeting_outcome = 'CANCELED' THEN e.engagement_id END) AS meetings_canceled,
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND em.meeting_outcome = 'NO_SHOW' THEN e.engagement_id END) AS meetings_no_show,
    
    -- Task metrics
    COUNT(DISTINCT CASE WHEN e.type = 'TASK' AND et.status = 'COMPLETED' THEN e.engagement_id END) AS tasks_completed,
    COUNT(DISTINCT CASE WHEN e.type = 'TASK' AND et.status IN ('NOT_STARTED', 'IN_PROGRESS') THEN e.engagement_id END) AS tasks_pending,
    
    -- Association metrics
    COUNT(DISTINCT econ.contact_id) AS unique_contacts_engaged,
    COUNT(DISTINCT ecomp.company_id) AS unique_companies_engaged,
    COUNT(DISTINCT ed.deal_id) AS unique_deals_engaged

FROM hubspot.engagement e
LEFT JOIN hubspot.engagement_call ec ON e.engagement_id = ec.engagement_id AND e.type = 'CALL'
LEFT JOIN hubspot.engagement_meeting em ON e.engagement_id = em.engagement_id AND e.type = 'MEETING'
LEFT JOIN hubspot.engagement_task et ON e.engagement_id = et.engagement_id AND e.type = 'TASK'
LEFT JOIN hubspot.engagement_contact econ ON e.engagement_id = econ.engagement_id
LEFT JOIN hubspot.engagement_company ecomp ON e.engagement_id = ecomp.engagement_id
LEFT JOIN hubspot.engagement_deal ed ON e.engagement_id = ed.engagement_id
WHERE e._fivetran_deleted = 0
  AND e.timestamp IS NOT NULL
GROUP BY CAST(e.timestamp AS DATE), DATENAME(WEEKDAY, e.timestamp), DATEPART(WEEKDAY, e.timestamp);
GO

/*
================================================================================
VIEW: vw_hubspot_engagement_owner_summary
DESCRIPTION: Engagement summary by owner/sales rep.
             Tracks individual productivity and engagement patterns.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_engagement_owner_summary]
AS
SELECT 
    e.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    o.email AS owner_email,
    
    -- Total engagement counts
    COUNT(DISTINCT e.engagement_id) AS total_engagements,
    COUNT(DISTINCT CASE WHEN e.type = 'CALL' THEN e.engagement_id END) AS total_calls,
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' THEN e.engagement_id END) AS total_meetings,
    COUNT(DISTINCT CASE WHEN e.type = 'EMAIL' THEN e.engagement_id END) AS total_emails,
    COUNT(DISTINCT CASE WHEN e.type = 'NOTE' THEN e.engagement_id END) AS total_notes,
    COUNT(DISTINCT CASE WHEN e.type = 'TASK' THEN e.engagement_id END) AS total_tasks,
    
    -- Last 7 days
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS engagements_7d,
    COUNT(DISTINCT CASE WHEN e.type = 'CALL' AND e.timestamp >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS calls_7d,
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND e.timestamp >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS meetings_7d,
    
    -- Last 30 days
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS engagements_30d,
    COUNT(DISTINCT CASE WHEN e.type = 'CALL' AND e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS calls_30d,
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS meetings_30d,
    COUNT(DISTINCT CASE WHEN e.type = 'EMAIL' AND e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS emails_30d,
    
    -- Call metrics
    SUM(CASE WHEN e.type = 'CALL' THEN COALESCE(ec.duration_milliseconds, 0) ELSE 0 END) / 60000.0 AS total_call_minutes,
    AVG(CASE WHEN e.type = 'CALL' AND ec.duration_milliseconds > 0 
             THEN CAST(ec.duration_milliseconds / 60000.0 AS DECIMAL(10, 2)) END) AS avg_call_minutes,
    
    -- Meeting metrics
    COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND em.meeting_outcome = 'COMPLETED' THEN e.engagement_id END) AS completed_meetings,
    CASE WHEN COUNT(DISTINCT CASE WHEN e.type = 'MEETING' THEN e.engagement_id END) > 0
         THEN CAST(COUNT(DISTINCT CASE WHEN e.type = 'MEETING' AND em.meeting_outcome = 'COMPLETED' THEN e.engagement_id END) * 100.0 
                   / COUNT(DISTINCT CASE WHEN e.type = 'MEETING' THEN e.engagement_id END) AS DECIMAL(10, 2))
         ELSE 0 END AS meeting_completion_rate,
    
    -- Task metrics
    COUNT(DISTINCT CASE WHEN e.type = 'TASK' AND et.status = 'COMPLETED' THEN e.engagement_id END) AS completed_tasks,
    CASE WHEN COUNT(DISTINCT CASE WHEN e.type = 'TASK' THEN e.engagement_id END) > 0
         THEN CAST(COUNT(DISTINCT CASE WHEN e.type = 'TASK' AND et.status = 'COMPLETED' THEN e.engagement_id END) * 100.0 
                   / COUNT(DISTINCT CASE WHEN e.type = 'TASK' THEN e.engagement_id END) AS DECIMAL(10, 2))
         ELSE 0 END AS task_completion_rate,
    
    -- Unique associations
    COUNT(DISTINCT econ.contact_id) AS unique_contacts_engaged,
    COUNT(DISTINCT ecomp.company_id) AS unique_companies_engaged,
    COUNT(DISTINCT ed.deal_id) AS unique_deals_engaged,
    
    -- Time range
    MIN(e.timestamp) AS first_engagement_date,
    MAX(e.timestamp) AS last_engagement_date,
    DATEDIFF(DAY, MIN(e.timestamp), MAX(e.timestamp)) + 1 AS days_active,
    
    -- Engagement velocity
    CASE 
        WHEN DATEDIFF(DAY, MIN(e.timestamp), MAX(e.timestamp)) > 0 
        THEN CAST(COUNT(DISTINCT e.engagement_id) * 7.0 / (DATEDIFF(DAY, MIN(e.timestamp), MAX(e.timestamp)) + 1) AS DECIMAL(10, 2))
        ELSE COUNT(DISTINCT e.engagement_id)
    END AS engagements_per_week

FROM hubspot.engagement e
LEFT JOIN hubspot.owner o ON e.owner_id = o.owner_id AND o._fivetran_deleted = 0
LEFT JOIN hubspot.engagement_call ec ON e.engagement_id = ec.engagement_id AND e.type = 'CALL'
LEFT JOIN hubspot.engagement_meeting em ON e.engagement_id = em.engagement_id AND e.type = 'MEETING'
LEFT JOIN hubspot.engagement_task et ON e.engagement_id = et.engagement_id AND e.type = 'TASK'
LEFT JOIN hubspot.engagement_contact econ ON e.engagement_id = econ.engagement_id
LEFT JOIN hubspot.engagement_company ecomp ON e.engagement_id = ecomp.engagement_id
LEFT JOIN hubspot.engagement_deal ed ON e.engagement_id = ed.engagement_id
WHERE e._fivetran_deleted = 0
  AND e.owner_id IS NOT NULL
GROUP BY e.owner_id, o.first_name, o.last_name, o.email;
GO

/*
================================================================================
VIEW: vw_hubspot_engagement_type_analysis
DESCRIPTION: Engagement analysis by type with detailed metrics.
             Provides insights into engagement patterns and effectiveness.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_engagement_type_analysis]
AS
SELECT 
    e.type AS engagement_type,
    COUNT(DISTINCT e.engagement_id) AS total_count,
    COUNT(DISTINCT e.owner_id) AS unique_owners,
    COUNT(DISTINCT econ.contact_id) AS unique_contacts,
    COUNT(DISTINCT ecomp.company_id) AS unique_companies,
    COUNT(DISTINCT ed.deal_id) AS unique_deals,
    
    -- Time distribution
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS count_7d,
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS count_30d,
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS count_90d,
    
    -- Average contacts/companies per engagement
    CAST(COUNT(econ.contact_id) * 1.0 / NULLIF(COUNT(DISTINCT e.engagement_id), 0) AS DECIMAL(10, 2)) AS avg_contacts_per_engagement,
    CAST(COUNT(ecomp.company_id) * 1.0 / NULLIF(COUNT(DISTINCT e.engagement_id), 0) AS DECIMAL(10, 2)) AS avg_companies_per_engagement,
    
    -- Distribution percentage
    CAST(COUNT(DISTINCT e.engagement_id) * 100.0 / 
         NULLIF(SUM(COUNT(DISTINCT e.engagement_id)) OVER (), 0) AS DECIMAL(10, 2)) AS pct_of_total,
    
    -- Time range
    MIN(e.timestamp) AS first_occurrence,
    MAX(e.timestamp) AS last_occurrence

FROM hubspot.engagement e
LEFT JOIN hubspot.engagement_contact econ ON e.engagement_id = econ.engagement_id
LEFT JOIN hubspot.engagement_company ecomp ON e.engagement_id = ecomp.engagement_id
LEFT JOIN hubspot.engagement_deal ed ON e.engagement_id = ed.engagement_id
WHERE e._fivetran_deleted = 0
GROUP BY e.type;
GO

/*
================================================================================
VIEW: vw_hubspot_call_analysis
DESCRIPTION: Detailed call engagement analysis.
             Tracks call outcomes, durations, and patterns.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_call_analysis]
AS
SELECT 
    e.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    COALESCE(ec.disposition, 'Unknown') AS call_disposition,
    COALESCE(ec.status, 'Unknown') AS call_status,
    
    -- Call counts
    COUNT(DISTINCT e.engagement_id) AS total_calls,
    
    -- Duration metrics
    SUM(COALESCE(ec.duration_milliseconds, 0)) / 60000.0 AS total_minutes,
    AVG(CASE WHEN ec.duration_milliseconds > 0 THEN ec.duration_milliseconds / 60000.0 END) AS avg_minutes,
    MIN(CASE WHEN ec.duration_milliseconds > 0 THEN ec.duration_milliseconds / 60000.0 END) AS min_minutes,
    MAX(ec.duration_milliseconds / 60000.0) AS max_minutes,
    
    -- Connected call rate
    CASE WHEN COUNT(DISTINCT e.engagement_id) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN ec.duration_milliseconds > 0 THEN e.engagement_id END) * 100.0 
                   / COUNT(DISTINCT e.engagement_id) AS DECIMAL(10, 2))
         ELSE 0 END AS connected_call_rate,
    
    -- Recording availability
    COUNT(DISTINCT CASE WHEN ec.recording_url IS NOT NULL THEN e.engagement_id END) AS calls_with_recording,
    
    -- Time distribution
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS calls_7d,
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS calls_30d,
    
    -- Contact/Company reach
    COUNT(DISTINCT econ.contact_id) AS unique_contacts_called,
    COUNT(DISTINCT ecomp.company_id) AS unique_companies_called

FROM hubspot.engagement e
INNER JOIN hubspot.engagement_call ec ON e.engagement_id = ec.engagement_id
LEFT JOIN hubspot.owner o ON e.owner_id = o.owner_id AND o._fivetran_deleted = 0
LEFT JOIN hubspot.engagement_contact econ ON e.engagement_id = econ.engagement_id
LEFT JOIN hubspot.engagement_company ecomp ON e.engagement_id = ecomp.engagement_id
WHERE e._fivetran_deleted = 0
  AND e.type = 'CALL'
GROUP BY e.owner_id, o.first_name, o.last_name, ec.disposition, ec.status;
GO

/*
================================================================================
VIEW: vw_hubspot_meeting_analysis
DESCRIPTION: Detailed meeting engagement analysis.
             Tracks meeting outcomes, durations, and patterns.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_hubspot_meeting_analysis]
AS
SELECT 
    e.owner_id,
    CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, '')) AS owner_name,
    COALESCE(em.meeting_outcome, 'Unknown') AS meeting_outcome,
    
    -- Meeting counts
    COUNT(DISTINCT e.engagement_id) AS total_meetings,
    
    -- Duration metrics
    SUM(CASE WHEN em.start_time IS NOT NULL AND em.end_time IS NOT NULL 
             THEN DATEDIFF(MINUTE, em.start_time, em.end_time) ELSE 0 END) AS total_meeting_minutes,
    AVG(CASE WHEN em.start_time IS NOT NULL AND em.end_time IS NOT NULL 
             THEN DATEDIFF(MINUTE, em.start_time, em.end_time) END) AS avg_meeting_minutes,
    
    -- Outcome distribution
    COUNT(DISTINCT CASE WHEN em.meeting_outcome = 'COMPLETED' THEN e.engagement_id END) AS completed_meetings,
    COUNT(DISTINCT CASE WHEN em.meeting_outcome = 'SCHEDULED' THEN e.engagement_id END) AS scheduled_meetings,
    COUNT(DISTINCT CASE WHEN em.meeting_outcome = 'CANCELED' THEN e.engagement_id END) AS canceled_meetings,
    COUNT(DISTINCT CASE WHEN em.meeting_outcome = 'NO_SHOW' THEN e.engagement_id END) AS no_show_meetings,
    COUNT(DISTINCT CASE WHEN em.meeting_outcome = 'RESCHEDULED' THEN e.engagement_id END) AS rescheduled_meetings,
    
    -- Completion rate
    CASE WHEN COUNT(DISTINCT e.engagement_id) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN em.meeting_outcome = 'COMPLETED' THEN e.engagement_id END) * 100.0 
                   / COUNT(DISTINCT e.engagement_id) AS DECIMAL(10, 2))
         ELSE 0 END AS completion_rate,
    
    -- No-show rate
    CASE WHEN COUNT(DISTINCT e.engagement_id) > 0 
         THEN CAST(COUNT(DISTINCT CASE WHEN em.meeting_outcome = 'NO_SHOW' THEN e.engagement_id END) * 100.0 
                   / COUNT(DISTINCT e.engagement_id) AS DECIMAL(10, 2))
         ELSE 0 END AS no_show_rate,
    
    -- Time distribution
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS meetings_7d,
    COUNT(DISTINCT CASE WHEN e.timestamp >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN e.engagement_id END) AS meetings_30d,
    
    -- Contact/Company/Deal reach
    COUNT(DISTINCT econ.contact_id) AS unique_contacts_met,
    COUNT(DISTINCT ecomp.company_id) AS unique_companies_met,
    COUNT(DISTINCT ed.deal_id) AS deals_with_meetings

FROM hubspot.engagement e
INNER JOIN hubspot.engagement_meeting em ON e.engagement_id = em.engagement_id
LEFT JOIN hubspot.owner o ON e.owner_id = o.owner_id AND o._fivetran_deleted = 0
LEFT JOIN hubspot.engagement_contact econ ON e.engagement_id = econ.engagement_id
LEFT JOIN hubspot.engagement_company ecomp ON e.engagement_id = ecomp.engagement_id
LEFT JOIN hubspot.engagement_deal ed ON e.engagement_id = ed.engagement_id
WHERE e._fivetran_deleted = 0
  AND e.type = 'MEETING'
GROUP BY e.owner_id, o.first_name, o.last_name, em.meeting_outcome;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Overall engagement metrics across all channels from HubSpot CRM.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_engagement_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily engagement summary with counts by type.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_engagement_daily_summary';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Engagement summary by owner/sales rep.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_engagement_owner_summary';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Engagement analysis by type with detailed metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_engagement_type_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Detailed call engagement analysis.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_call_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Detailed meeting engagement analysis.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_hubspot_meeting_analysis';
GO
