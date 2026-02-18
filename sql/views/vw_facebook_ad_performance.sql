/*
================================================================================
VIEW: vw_facebook_ad_performance
DESCRIPTION: Ad-level performance metrics for analyzing creative effectiveness.
             Includes ad details, creative elements, and performance insights.
             Facebook Ads have unique creative types (image, video, carousel, etc.)
SCHEMA TABLES:
  - facebook_ads.basic_ad: Daily ad-level performance metrics
    Columns: ad_id, adset_id, campaign_id, account_id, date, spend, impressions, 
             clicks, reach, actions, action_values, _fivetran_synced
  - facebook_ads.ad_history: Ad metadata with change history
    Columns: ad_id, name, status, creative_id, _fivetran_synced, _fivetran_deleted
  - facebook_ads.creative_history: Creative metadata with change history  
    Columns: creative_id, name, title, body, call_to_action_type, object_type,
             _fivetran_synced, _fivetran_deleted
  - facebook_ads.adset_history: Ad Set metadata
    Columns: adset_id, name, _fivetran_synced
  - facebook_ads.campaign_history: Campaign metadata
    Columns: campaign_id, name, objective, _fivetran_synced
  - facebook_ads.account_history: Account metadata
    Columns: account_id, name, currency, _fivetran_synced
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_performance]
AS
SELECT 
    -- Dimension Keys
    a.ad_id,
    a.adset_id,
    a.campaign_id,
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    
    -- Ad Information (from history table - latest values)
    adh.name AS ad_name,
    adh.status AS ad_status,
    adh.creative_id,
    
    -- Creative Information
    ch.name AS creative_name,
    ch.title AS creative_title,
    ch.body AS creative_body,
    ch.call_to_action_type,
    ch.object_type AS creative_type,
    
    -- Hierarchy context
    adsh.name AS adset_name,
    camph.name AS campaign_name,
    camph.objective AS campaign_objective,
    ah.name AS account_name,
    ah.currency AS currency_code,
    
    -- Raw Metrics
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    a.reach,
    
    -- Frequency
    CASE 
        WHEN a.reach > 0 
        THEN CAST((a.impressions * 1.0 / a.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS frequency,
    
    -- Action Metrics
    COALESCE(a.actions, 0) AS total_actions,
    COALESCE(a.action_values, 0) AS total_action_value,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Unique CTR
    CASE 
        WHEN a.reach > 0 
        THEN CAST((a.clicks * 100.0 / a.reach) AS DECIMAL(10, 4))
        ELSE 0 
    END AS unique_ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
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
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN a.spend > 0 
        THEN CAST((COALESCE(a.action_values, 0) / a.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Calculated Metrics - Average CPM
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.spend * 1000.0 / a.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- Calculated Metrics - CPP
    CASE 
        WHEN a.reach > 0 
        THEN CAST((a.spend * 1000.0 / a.reach) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cpp,
    
    -- Creative Type Label
    CASE 
        WHEN ch.object_type = 'PHOTO' THEN 'Image'
        WHEN ch.object_type = 'LINK' THEN 'Link'
        WHEN ch.object_type = 'VIDEO' THEN 'Video'
        WHEN ch.object_type = 'STATUS' THEN 'Status'
        WHEN ch.object_type = 'OFFER' THEN 'Offer'
        ELSE COALESCE(ch.object_type, 'Unknown')
    END AS creative_type_label,
    
    -- Metadata
    a._fivetran_synced AS last_synced_at

FROM facebook_ads.basic_ad a
LEFT JOIN (
    SELECT 
        ad_id,
        name,
        status,
        creative_id,
        ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.ad_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) adh ON a.ad_id = adh.ad_id AND adh.rn = 1
LEFT JOIN (
    SELECT 
        creative_id,
        name,
        title,
        body,
        call_to_action_type,
        object_type,
        ROW_NUMBER() OVER (PARTITION BY creative_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.creative_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ch ON adh.creative_id = ch.creative_id AND ch.rn = 1
LEFT JOIN (
    SELECT 
        adset_id,
        name,
        ROW_NUMBER() OVER (PARTITION BY adset_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.adset_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) adsh ON a.adset_id = adsh.adset_id AND adsh.rn = 1
LEFT JOIN (
    SELECT 
        campaign_id,
        name,
        objective,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.campaign_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) camph ON a.campaign_id = camph.campaign_id AND camph.rn = 1
LEFT JOIN (
    SELECT 
        account_id,
        name,
        currency,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM facebook_ads.account_history
    WHERE COALESCE(_fivetran_deleted, 0) = 0
) ah ON a.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_facebook_ad_creative_effectiveness
DESCRIPTION: Ad creative effectiveness analysis with aggregated performance metrics.
             Helps identify winning creative elements and variations.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_creative_effectiveness]
AS
WITH AdAggregated AS (
    SELECT 
        ad_id,
        ad_name,
        ad_status,
        creative_id,
        creative_name,
        creative_title,
        creative_body,
        call_to_action_type,
        creative_type_label,
        adset_name,
        campaign_name,
        campaign_objective,
        account_name,
        currency_code,
        
        -- Aggregated metrics (last 30 days)
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(reach) AS total_reach,
        SUM(total_actions) AS total_actions,
        SUM(total_action_value) AS total_action_value,
        COUNT(DISTINCT date) AS active_days
    FROM [dbo].[vw_facebook_ad_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        ad_id,
        ad_name,
        ad_status,
        creative_id,
        creative_name,
        creative_title,
        creative_body,
        call_to_action_type,
        creative_type_label,
        adset_name,
        campaign_name,
        campaign_objective,
        account_name,
        currency_code
)
SELECT 
    ad_id,
    ad_name,
    ad_status,
    creative_id,
    creative_name,
    creative_type_label,
    call_to_action_type,
    adset_name,
    campaign_name,
    campaign_objective,
    account_name,
    currency_code,
    
    -- Creative preview
    LEFT(COALESCE(creative_title, ''), 100) AS creative_title_preview,
    LEFT(COALESCE(creative_body, ''), 150) AS creative_body_preview,
    
    -- Metrics
    total_spend,
    total_impressions,
    total_clicks,
    total_reach,
    total_actions,
    total_action_value,
    active_days,
    
    -- Frequency
    CASE WHEN total_reach > 0 
         THEN CAST((total_impressions * 1.0 / total_reach) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_frequency,
    
    -- KPIs
    CASE WHEN total_impressions > 0 
         THEN CAST((total_clicks * 100.0 / total_impressions) AS DECIMAL(10, 4)) 
         ELSE 0 END AS ctr_percent,
    CASE WHEN total_clicks > 0 
         THEN CAST((total_spend / total_clicks) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN total_actions > 0 
         THEN CAST((total_spend / total_actions) AS DECIMAL(18, 4)) 
         ELSE 0 END AS cost_per_action,
    CASE WHEN total_spend > 0 
         THEN CAST((total_action_value / total_spend) AS DECIMAL(10, 4)) 
         ELSE 0 END AS roas,
    
    -- Rankings within ad set
    DENSE_RANK() OVER (PARTITION BY adset_name ORDER BY total_clicks DESC) AS clicks_rank_in_adset,
    DENSE_RANK() OVER (PARTITION BY adset_name ORDER BY total_actions DESC) AS actions_rank_in_adset,
    DENSE_RANK() OVER (PARTITION BY adset_name ORDER BY 
        CASE WHEN total_impressions > 0 THEN total_clicks * 1.0 / total_impressions ELSE 0 END DESC
    ) AS ctr_rank_in_adset,
    
    -- Performance tier
    CASE 
        WHEN total_actions >= 10 AND 
             (CASE WHEN total_spend > 0 THEN total_action_value / total_spend ELSE 0 END) >= 2
        THEN 'Top Performer'
        WHEN total_actions >= 5 AND 
             (CASE WHEN total_impressions > 0 THEN total_clicks * 100.0 / total_impressions ELSE 0 END) >= 
             AVG(CASE WHEN total_impressions > 0 THEN total_clicks * 100.0 / total_impressions ELSE 0 END) OVER ()
        THEN 'Above Average'
        WHEN total_clicks > 0 AND total_actions = 0
        THEN 'Clicks but No Actions'
        WHEN total_impressions > 0 AND total_clicks = 0
        THEN 'Impressions but No Clicks'
        ELSE 'Developing'
    END AS performance_tier,
    
    -- Creative optimization suggestions
    CASE 
        WHEN total_reach > 0 AND (total_impressions * 1.0 / total_reach) > 8
        THEN 'High frequency - audience may be fatigued'
        WHEN total_impressions > 0 AND (total_clicks * 100.0 / total_impressions) < 0.5
        THEN 'Low CTR - test new creative'
        WHEN total_clicks > 0 AND total_actions = 0
        THEN 'Good clicks but no conversions - check landing page'
        WHEN total_actions > 0 AND total_spend > 0 AND (total_action_value / total_spend) < 1
        THEN 'ROAS below 1 - optimize or pause'
        ELSE 'Performance acceptable'
    END AS optimization_suggestion

FROM AdAggregated
WHERE total_impressions > 0;
GO

/*
================================================================================
VIEW: vw_facebook_ad_creative_type_comparison
DESCRIPTION: Performance comparison across different creative types (image, video, etc.).
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_creative_type_comparison]
AS
SELECT 
    creative_type_label,
    call_to_action_type,
    account_name,
    
    -- Counts
    COUNT(DISTINCT ad_id) AS ad_count,
    COUNT(DISTINCT adset_name) AS adsets_with_type,
    COUNT(DISTINCT campaign_name) AS campaigns_with_type,
    
    -- Aggregated metrics
    SUM(total_spend) AS total_spend,
    SUM(total_impressions) AS total_impressions,
    SUM(total_clicks) AS total_clicks,
    SUM(total_reach) AS total_reach,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- Average per ad
    CAST(SUM(total_spend) / NULLIF(COUNT(DISTINCT ad_id), 0) AS DECIMAL(18, 2)) AS avg_spend_per_ad,
    CAST(SUM(total_actions) / NULLIF(COUNT(DISTINCT ad_id), 0) AS DECIMAL(10, 2)) AS avg_actions_per_ad,
    
    -- Frequency
    CASE WHEN SUM(total_reach) > 0 
         THEN CAST((SUM(total_impressions) * 1.0 / SUM(total_reach)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_frequency,
    
    -- KPIs
    CASE WHEN SUM(total_impressions) > 0 
         THEN CAST((SUM(total_clicks) * 100.0 / SUM(total_impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS ctr_percent,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS cost_per_action,
    CASE WHEN SUM(total_spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(total_spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS roas

FROM [dbo].[vw_facebook_ad_creative_effectiveness]
GROUP BY 
    creative_type_label,
    call_to_action_type,
    account_name;
GO

/*
================================================================================
VIEW: vw_facebook_ad_cta_analysis
DESCRIPTION: Performance analysis by Call-to-Action type to identify
             which CTAs drive the best results.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_cta_analysis]
AS
SELECT 
    call_to_action_type,
    campaign_objective,
    
    -- Counts
    COUNT(DISTINCT ad_id) AS ad_count,
    
    -- Aggregated metrics
    SUM(total_spend) AS total_spend,
    SUM(total_impressions) AS total_impressions,
    SUM(total_clicks) AS total_clicks,
    SUM(total_actions) AS total_actions,
    SUM(total_action_value) AS total_action_value,
    
    -- KPIs
    CASE WHEN SUM(total_impressions) > 0 
         THEN CAST((SUM(total_clicks) * 100.0 / SUM(total_impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_actions) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_actions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cost_per_action,
    CASE WHEN SUM(total_spend) > 0 
         THEN CAST((SUM(total_action_value) / SUM(total_spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    
    -- Rankings
    DENSE_RANK() OVER (ORDER BY 
        CASE WHEN SUM(total_impressions) > 0 
             THEN SUM(total_clicks) * 1.0 / SUM(total_impressions) ELSE 0 END DESC
    ) AS ctr_rank,
    DENSE_RANK() OVER (ORDER BY 
        CASE WHEN SUM(total_clicks) > 0 
             THEN SUM(total_actions) * 1.0 / SUM(total_clicks) ELSE 0 END DESC
    ) AS conversion_rate_rank

FROM [dbo].[vw_facebook_ad_creative_effectiveness]
WHERE call_to_action_type IS NOT NULL
GROUP BY 
    call_to_action_type,
    campaign_objective;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily Facebook ad-level performance metrics with creative details and video metrics.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_ad_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook ad creative effectiveness analysis with performance rankings and optimization suggestions.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_ad_creative_effectiveness';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Performance comparison across Facebook ad creative types.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_ad_creative_type_comparison';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Facebook ad performance analysis by Call-to-Action type.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_facebook_ad_cta_analysis';
GO
