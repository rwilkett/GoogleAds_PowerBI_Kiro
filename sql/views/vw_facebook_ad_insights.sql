/*
================================================================================
VIEW: vw_facebook_ad_insights
DESCRIPTION: Detailed Facebook Ads insights with demographic and placement breakdowns.
             Provides granular performance data for audience and placement analysis.
             Uses Facebook's breakdown dimensions for deeper analysis.
SCHEMA TABLES:
  - facebook_ads.basic_ad: Daily ad-level performance with demographic breakdowns
    Columns: ad_id, adset_id, campaign_id, account_id, date, spend, impressions, 
             clicks, reach, actions, action_values, inline_link_clicks,
             age, gender, impression_device, publisher_platform, platform_position,
             device_platform, _fivetran_synced
  - facebook_ads.ad_history: Ad metadata
    Columns: ad_id, name, status, _fivetran_synced
  - facebook_ads.adset_history: Ad Set metadata
    Columns: adset_id, name, _fivetran_synced
  - facebook_ads.campaign_history: Campaign metadata
    Columns: campaign_id, name, objective, _fivetran_synced
  - facebook_ads.account_history: Account metadata
    Columns: account_id, name, currency, _fivetran_synced

NOTE: Facebook provides different breakdown views. The basic_ad table structure
may vary based on Fivetran connector configuration. This view assumes standard
demographic and placement fields are available.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_insights_demographics]
AS
SELECT 
    -- Dimension Keys
    a.ad_id,
    a.adset_id,
    a.campaign_id,
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    
    -- Demographic Breakdowns
    a.age AS age_range,
    a.gender,
    
    -- Hierarchy context
    adh.name AS ad_name,
    adsh.name AS adset_name,
    ch.name AS campaign_name,
    ch.objective AS campaign_objective,
    ah.name AS account_name,
    ah.currency AS currency_code,
    
    -- Raw Metrics
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    a.reach,
    COALESCE(a.inline_link_clicks, 0) AS link_clicks,
    COALESCE(a.actions, 0) AS total_actions,
    COALESCE(a.action_values, 0) AS total_action_value,
    
    -- Calculated Metrics - CTR
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - CPC
    CASE 
        WHEN a.clicks > 0 
        THEN CAST((a.spend / a.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Cost Per Action
    CASE 
        WHEN COALESCE(a.actions, 0) > 0 
        THEN CAST((a.spend / a.actions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_action,
    
    -- Calculated Metrics - ROAS
    CASE 
        WHEN a.spend > 0 
        THEN CAST((COALESCE(a.action_values, 0) / a.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Metadata
    a._fivetran_synced AS last_synced_at

FROM facebook_ads.basic_ad a
LEFT JOIN (
    SELECT ad_id, name,
           ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.ad_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) adh ON a.ad_id = adh.ad_id AND adh.rn = 1
LEFT JOIN (
    SELECT adset_id, name,
           ROW_NUMBER() OVER (PARTITION BY adset_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.adset_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) adsh ON a.adset_id = adsh.adset_id AND adsh.rn = 1
LEFT JOIN (
    SELECT campaign_id, name, objective,
           ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.campaign_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) ch ON a.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT account_id, name, currency,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.account_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) ah ON a.account_id = ah.account_id AND ah.rn = 1
WHERE a.age IS NOT NULL OR a.gender IS NOT NULL;
GO

/*
================================================================================
VIEW: vw_facebook_ad_insights_placements
DESCRIPTION: Ad performance breakdown by placement (Facebook, Instagram, 
             Audience Network, Messenger) and position (Feed, Stories, etc.).
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_insights_placements]
AS
SELECT 
    -- Dimension Keys
    a.ad_id,
    a.adset_id,
    a.campaign_id,
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    
    -- Placement Breakdowns
    a.publisher_platform,
    a.platform_position,
    a.impression_device,
    a.device_platform,
    
    -- Combined placement label
    CONCAT(
        COALESCE(a.publisher_platform, 'Unknown'), 
        ' - ', 
        COALESCE(a.platform_position, 'Unknown')
    ) AS placement_label,
    
    -- Hierarchy context
    adh.name AS ad_name,
    adsh.name AS adset_name,
    ch.name AS campaign_name,
    ch.objective AS campaign_objective,
    ah.name AS account_name,
    ah.currency AS currency_code,
    
    -- Raw Metrics
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    a.reach,
    COALESCE(a.inline_link_clicks, 0) AS link_clicks,
    COALESCE(a.actions, 0) AS total_actions,
    COALESCE(a.action_values, 0) AS total_action_value,
    
    -- Calculated Metrics
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    CASE 
        WHEN a.clicks > 0 
        THEN CAST((a.spend / a.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    CASE 
        WHEN COALESCE(a.actions, 0) > 0 
        THEN CAST((a.spend / a.actions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_action,
    
    CASE 
        WHEN a.spend > 0 
        THEN CAST((COALESCE(a.action_values, 0) / a.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- CPM for placement comparison
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.spend * 1000.0 / a.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- Metadata
    a._fivetran_synced AS last_synced_at

FROM facebook_ads.basic_ad a
LEFT JOIN (
    SELECT ad_id, name,
           ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.ad_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) adh ON a.ad_id = adh.ad_id AND adh.rn = 1
LEFT JOIN (
    SELECT adset_id, name,
           ROW_NUMBER() OVER (PARTITION BY adset_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.adset_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) adsh ON a.adset_id = adsh.adset_id AND adsh.rn = 1
LEFT JOIN (
    SELECT campaign_id, name, objective,
           ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.campaign_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) ch ON a.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT account_id, name, currency,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.account_history WHERE COALESCE(_fivetran_deleted, 0) = 0
) ah ON a.account_id = ah.account_id AND ah.rn = 1
WHERE a.publisher_platform IS NOT NULL OR a.platform_position IS NOT NULL;
GO

/*
================================================================================
VIEW: vw_facebook_demographic_summary
DESCRIPTION: Aggregated demographic performance summary for audience analysis.
             Identifies best-performing age/gender combinations.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_demographic_summary]
AS
SELECT 
    age_range,
    gender,
    campaign_objective,
    
    -- Counts
    COUNT(DISTINCT ad_id) AS ad_count,
    COUNT(DISTINCT campaign_id) AS campaign_count,
    
    -- Aggregated metrics
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(reach) AS total_reach,
    SUM(link_clicks) AS total_link_clicks,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- KPIs
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(clicks) * 100.0 / SUM(impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(clicks) > 0 
         THEN CAST((SUM(spend) / SUM(clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_action,
    CASE WHEN SUM(spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    
    -- Percentage distribution
    CAST((SUM(spend) * 100.0 / 
          NULLIF(SUM(SUM(spend)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_spend,
    CAST((SUM(total_actions) * 100.0 / 
          NULLIF(SUM(SUM(total_actions)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_actions,
    
    -- Performance ranking
    DENSE_RANK() OVER (ORDER BY 
        CASE WHEN SUM(total_actions) > 0 THEN SUM(spend) / SUM(total_actions) ELSE 999999 END ASC
    ) AS cost_efficiency_rank

FROM [dbo].[vw_facebook_ad_insights_demographics]
WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND age_range IS NOT NULL AND gender IS NOT NULL
GROUP BY 
    age_range,
    gender,
    campaign_objective;
GO

/*
================================================================================
VIEW: vw_facebook_placement_summary
DESCRIPTION: Aggregated placement performance summary for placement optimization.
             Identifies best-performing placements across platforms.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_placement_summary]
AS
SELECT 
    publisher_platform,
    platform_position,
    placement_label,
    impression_device,
    campaign_objective,
    
    -- Counts
    COUNT(DISTINCT ad_id) AS ad_count,
    COUNT(DISTINCT campaign_id) AS campaign_count,
    
    -- Aggregated metrics
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(reach) AS total_reach,
    SUM(link_clicks) AS total_link_clicks,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- KPIs
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(clicks) * 100.0 / SUM(impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(link_clicks) * 100.0 / SUM(impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_link_ctr,
    CASE WHEN SUM(clicks) > 0 
         THEN CAST((SUM(spend) / SUM(clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(spend) * 1000.0 / SUM(impressions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpm,
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_action,
    CASE WHEN SUM(spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    
    -- Percentage distribution
    CAST((SUM(spend) * 100.0 / 
          NULLIF(SUM(SUM(spend)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_spend,
    CAST((SUM(impressions) * 100.0 / 
          NULLIF(SUM(SUM(impressions)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_impressions,
    
    -- Performance ranking
    DENSE_RANK() OVER (ORDER BY 
        CASE WHEN SUM(total_actions) > 0 THEN SUM(spend) / SUM(total_actions) ELSE 999999 END ASC
    ) AS cost_efficiency_rank,
    
    -- Placement recommendations
    CASE 
        WHEN SUM(total_actions) > 0 AND 
             (SUM(spend) / SUM(total_actions)) < 
             AVG(CASE WHEN SUM(total_actions) > 0 THEN SUM(spend) / SUM(total_actions) END) OVER ()
        THEN 'Scale - Below Avg CPA'
        WHEN SUM(impressions) > 0 AND 
             (SUM(clicks) * 100.0 / SUM(impressions)) < 0.5
        THEN 'Test Different Creative'
        WHEN SUM(total_actions) = 0 AND SUM(spend) > 100
        THEN 'Consider Pausing'
        ELSE 'Monitor'
    END AS placement_recommendation

FROM [dbo].[vw_facebook_ad_insights_placements]
WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND publisher_platform IS NOT NULL
GROUP BY 
    publisher_platform,
    platform_position,
    placement_label,
    impression_device,
    campaign_objective;
GO

/*
================================================================================
VIEW: vw_facebook_device_performance
DESCRIPTION: Performance analysis by device type (mobile, desktop, tablet).
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_device_performance]
AS
SELECT 
    device_platform,
    impression_device,
    
    -- Aggregated metrics
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(reach) AS total_reach,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- KPIs
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(clicks) * 100.0 / SUM(impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(clicks) > 0 
         THEN CAST((SUM(spend) / SUM(clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_action,
    CASE WHEN SUM(spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    
    -- Share of total
    CAST((SUM(spend) * 100.0 / 
          NULLIF(SUM(SUM(spend)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_spend

FROM [dbo].[vw_facebook_ad_insights_placements]
WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND (device_platform IS NOT NULL OR impression_device IS NOT NULL)
GROUP BY 
    device_platform,
    impression_device;
GO

/*
================================================================================
VIEW: vw_facebook_age_gender_matrix
DESCRIPTION: Cross-tabulation of age and gender for demographic targeting optimization.
             Creates a matrix view for heatmap visualization in PowerBI.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_age_gender_matrix]
AS
SELECT 
    age_range,
    gender,
    
    -- Key metrics for matrix
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- CTR for color coding
    CASE WHEN SUM(impressions) > 0 
         THEN CAST((SUM(clicks) * 100.0 / SUM(impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS ctr_percent,
    
    -- CPA for efficiency comparison
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS cost_per_action,
    
    -- ROAS for value comparison
    CASE WHEN SUM(spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS roas,
    
    -- Performance index relative to average
    CASE 
        WHEN SUM(total_actions) > 0 AND 
             AVG(CASE WHEN SUM(total_actions) > 0 THEN SUM(spend) / SUM(total_actions) END) OVER () > 0
        THEN CAST((
            AVG(CASE WHEN SUM(total_actions) > 0 THEN SUM(spend) / SUM(total_actions) END) OVER () /
            (SUM(spend) / SUM(total_actions))
        ) * 100 AS DECIMAL(10, 2))
        ELSE 0 
    END AS efficiency_index

FROM [dbo].[vw_facebook_ad_insights_demographics]
WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND age_range IS NOT NULL AND gender IS NOT NULL
GROUP BY 
    age_range,
    gender;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook Ad insights with demographic breakdowns (age, gender).',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_ad_insights_demographics';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook Ad insights with placement breakdowns (platform, position, device).',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_ad_insights_placements';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Aggregated Facebook demographic performance summary for audience optimization.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_demographic_summary';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Aggregated Facebook placement performance summary with recommendations.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_placement_summary';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook performance analysis by device type.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_device_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Age and gender cross-tabulation matrix for demographic heatmap visualization.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_age_gender_matrix';
GO
