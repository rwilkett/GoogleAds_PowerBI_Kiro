/*
================================================================================
VIEW: vw_ad_performance
DESCRIPTION: Ad-level performance metrics for analyzing ad copy effectiveness.
             Includes ad details and creative performance insights.
FIVETRAN TABLES: google_ads.ad_stats, google_ads.ad_history
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_ad_performance]
AS
SELECT 
    -- Dimension Keys
    a.ad_id,
    a.ad_group_id,
    a.campaign_id,
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    
    -- Ad Information (from history table - latest values)
    adh.type AS ad_type,
    adh.status AS ad_status,
    adh.device_preference,
    
    -- Responsive Search Ad Components
    adh.responsive_search_ad_headlines,
    adh.responsive_search_ad_descriptions,
    adh.responsive_search_ad_path1,
    adh.responsive_search_ad_path2,
    
    -- Expanded Text Ad Components (legacy)
    adh.expanded_text_ad_headline_part1,
    adh.expanded_text_ad_headline_part2,
    adh.expanded_text_ad_headline_part3,
    adh.expanded_text_ad_description,
    adh.expanded_text_ad_description2,
    adh.expanded_text_ad_path1,
    adh.expanded_text_ad_path2,
    
    -- Display/Image Ad Components
    adh.display_url,
    adh.final_urls,
    adh.final_mobile_urls,
    
    -- Ad Strength (for RSAs)
    adh.ad_strength,
    
    -- Hierarchy context
    agh.name AS ad_group_name,
    ch.name AS campaign_name,
    ch.advertising_channel_type,
    ah.descriptive_name AS account_name,
    ah.currency_code,
    
    -- Raw Metrics
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    COALESCE(a.conversions, 0) AS conversions,
    COALESCE(a.conversions_value, 0) AS conversions_value,
    
    -- Interaction Metrics
    COALESCE(a.interactions, 0) AS interactions,
    
    -- Video Metrics (if applicable)
    COALESCE(a.video_views, 0) AS video_views,
    COALESCE(a.video_quartile_p100_rate, 0) AS video_completion_rate,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN a.impressions > 0 
        THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN a.clicks > 0 
        THEN CAST((a.spend / a.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Conversion Rate
    CASE 
        WHEN a.clicks > 0 
        THEN CAST((COALESCE(a.conversions, 0) * 100.0 / a.clicks) AS DECIMAL(10, 4))
        ELSE 0 
    END AS conversion_rate_percent,
    
    -- Calculated Metrics - Cost Per Conversion
    CASE 
        WHEN COALESCE(a.conversions, 0) > 0 
        THEN CAST((a.spend / a.conversions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_conversion,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN a.spend > 0 
        THEN CAST((COALESCE(a.conversions_value, 0) / a.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Ad Strength Category
    CASE 
        WHEN adh.ad_strength = 'EXCELLENT' THEN 'Excellent'
        WHEN adh.ad_strength = 'GOOD' THEN 'Good'
        WHEN adh.ad_strength = 'AVERAGE' THEN 'Average'
        WHEN adh.ad_strength = 'POOR' THEN 'Poor'
        WHEN adh.ad_strength = 'UNSPECIFIED' OR adh.ad_strength IS NULL THEN 'Not Applicable'
        ELSE adh.ad_strength
    END AS ad_strength_label,
    
    -- Metadata
    a._fivetran_synced AS last_synced_at

FROM google_ads.ad_stats a
LEFT JOIN (
    SELECT 
        ad_id,
        type,
        status,
        device_preference,
        responsive_search_ad_headlines,
        responsive_search_ad_descriptions,
        responsive_search_ad_path1,
        responsive_search_ad_path2,
        expanded_text_ad_headline_part1,
        expanded_text_ad_headline_part2,
        expanded_text_ad_headline_part3,
        expanded_text_ad_description,
        expanded_text_ad_description2,
        expanded_text_ad_path1,
        expanded_text_ad_path2,
        display_url,
        final_urls,
        final_mobile_urls,
        ad_strength,
        ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.ad_history
) adh ON a.ad_id = adh.ad_id AND adh.rn = 1
LEFT JOIN (
    SELECT 
        ad_group_id,
        name,
        ROW_NUMBER() OVER (PARTITION BY ad_group_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.ad_group_history
) agh ON a.ad_group_id = agh.ad_group_id AND agh.rn = 1
LEFT JOIN (
    SELECT 
        campaign_id,
        name,
        advertising_channel_type,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.campaign_history
) ch ON a.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT 
        account_id,
        descriptive_name,
        currency_code,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.account_history
) ah ON a.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_ad_copy_effectiveness
DESCRIPTION: Ad copy effectiveness analysis with aggregated performance metrics.
             Helps identify winning ad copy elements and variations.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_ad_copy_effectiveness]
AS
WITH AdAggregated AS (
    SELECT 
        ad_id,
        ad_type,
        ad_status,
        ad_strength_label,
        ad_group_name,
        campaign_name,
        account_name,
        currency_code,
        advertising_channel_type,
        
        -- RSA components
        responsive_search_ad_headlines,
        responsive_search_ad_descriptions,
        
        -- ETA components
        expanded_text_ad_headline_part1,
        expanded_text_ad_headline_part2,
        expanded_text_ad_description,
        
        -- Final URLs
        final_urls,
        
        -- Aggregated metrics (last 30 days)
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value,
        COUNT(DISTINCT date) AS active_days
    FROM [dbo].[vw_ad_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        ad_id,
        ad_type,
        ad_status,
        ad_strength_label,
        ad_group_name,
        campaign_name,
        account_name,
        currency_code,
        advertising_channel_type,
        responsive_search_ad_headlines,
        responsive_search_ad_descriptions,
        expanded_text_ad_headline_part1,
        expanded_text_ad_headline_part2,
        expanded_text_ad_description,
        final_urls
)
SELECT 
    ad_id,
    ad_type,
    ad_status,
    ad_strength_label,
    ad_group_name,
    campaign_name,
    account_name,
    currency_code,
    advertising_channel_type,
    
    -- Ad copy preview (first headline/description)
    CASE 
        WHEN ad_type = 'RESPONSIVE_SEARCH_AD' THEN 
            LEFT(COALESCE(responsive_search_ad_headlines, ''), 100)
        ELSE 
            CONCAT(
                COALESCE(expanded_text_ad_headline_part1, ''),
                ' | ',
                COALESCE(expanded_text_ad_headline_part2, '')
            )
    END AS ad_headline_preview,
    
    CASE 
        WHEN ad_type = 'RESPONSIVE_SEARCH_AD' THEN 
            LEFT(COALESCE(responsive_search_ad_descriptions, ''), 100)
        ELSE 
            COALESCE(expanded_text_ad_description, '')
    END AS ad_description_preview,
    
    final_urls AS landing_page_url,
    
    -- Metrics
    total_spend,
    total_impressions,
    total_clicks,
    total_conversions,
    total_conversions_value,
    active_days,
    
    -- KPIs
    CASE WHEN total_impressions > 0 
         THEN CAST((total_clicks * 100.0 / total_impressions) AS DECIMAL(10, 4)) 
         ELSE 0 END AS ctr_percent,
    CASE WHEN total_clicks > 0 
         THEN CAST((total_spend / total_clicks) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN total_clicks > 0 
         THEN CAST((total_conversions * 100.0 / total_clicks) AS DECIMAL(10, 4)) 
         ELSE 0 END AS conversion_rate_percent,
    CASE WHEN total_conversions > 0 
         THEN CAST((total_spend / total_conversions) AS DECIMAL(18, 4)) 
         ELSE 0 END AS cost_per_conversion,
    CASE WHEN total_spend > 0 
         THEN CAST((total_conversions_value / total_spend) AS DECIMAL(10, 4)) 
         ELSE 0 END AS roas,
    
    -- Rankings within ad group
    DENSE_RANK() OVER (PARTITION BY ad_group_name ORDER BY total_clicks DESC) AS clicks_rank_in_ad_group,
    DENSE_RANK() OVER (PARTITION BY ad_group_name ORDER BY total_conversions DESC) AS conversions_rank_in_ad_group,
    DENSE_RANK() OVER (PARTITION BY ad_group_name ORDER BY 
        CASE WHEN total_impressions > 0 THEN total_clicks * 1.0 / total_impressions ELSE 0 END DESC
    ) AS ctr_rank_in_ad_group,
    
    -- Performance indicators
    CASE 
        WHEN total_conversions >= 5 AND 
             (CASE WHEN total_spend > 0 THEN total_conversions_value / total_spend ELSE 0 END) >= 2
        THEN 'Top Performer'
        WHEN total_conversions >= 2 AND 
             (CASE WHEN total_impressions > 0 THEN total_clicks * 100.0 / total_impressions ELSE 0 END) >= 
             AVG(CASE WHEN total_impressions > 0 THEN total_clicks * 100.0 / total_impressions ELSE 0 END) OVER ()
        THEN 'Above Average'
        WHEN total_clicks > 0 AND total_conversions = 0
        THEN 'Clicks but No Conversions'
        WHEN total_impressions > 0 AND total_clicks = 0
        THEN 'Impressions but No Clicks'
        ELSE 'Developing'
    END AS performance_tier,
    
    -- Ad strength impact flag
    CASE 
        WHEN ad_strength_label IN ('Poor', 'Average') AND ad_type = 'RESPONSIVE_SEARCH_AD'
        THEN 'Improve ad strength'
        WHEN ad_strength_label = 'Excellent' AND total_conversions < 2
        THEN 'Strong ad, low conversions - check targeting'
        ELSE 'No action needed'
    END AS optimization_suggestion

FROM AdAggregated
WHERE total_impressions > 0;
GO

/*
================================================================================
VIEW: vw_ad_strength_analysis
DESCRIPTION: Ad strength distribution and performance correlation analysis.
             Shows relationship between ad strength and performance metrics.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_ad_strength_analysis]
AS
SELECT 
    ad_strength_label,
    ad_type,
    campaign_name,
    account_name,
    
    -- Counts
    COUNT(DISTINCT ad_id) AS ad_count,
    
    -- Aggregated metrics
    SUM(total_spend) AS total_spend,
    SUM(total_impressions) AS total_impressions,
    SUM(total_clicks) AS total_clicks,
    SUM(total_conversions) AS total_conversions,
    SUM(total_conversions_value) AS total_conversions_value,
    
    -- KPIs
    CASE WHEN SUM(total_impressions) > 0 
         THEN CAST((SUM(total_clicks) * 100.0 / SUM(total_impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_ctr_percent,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_conversions) * 100.0 / SUM(total_clicks)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_conversion_rate,
    CASE WHEN SUM(total_spend) > 0 
         THEN CAST((SUM(total_conversions_value) / SUM(total_spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS avg_roas,
    
    -- Percentage of total
    CAST((COUNT(DISTINCT ad_id) * 100.0 / 
          SUM(COUNT(DISTINCT ad_id)) OVER ()) AS DECIMAL(10, 2)) AS pct_of_total_ads,
    CAST((SUM(total_spend) * 100.0 / 
          NULLIF(SUM(SUM(total_spend)) OVER (), 0)) AS DECIMAL(10, 2)) AS pct_of_total_spend

FROM (
    SELECT 
        ad_id,
        ad_type,
        ad_strength_label,
        campaign_name,
        account_name,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value
    FROM [dbo].[vw_ad_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        ad_id,
        ad_type,
        ad_strength_label,
        campaign_name,
        account_name
) ads
GROUP BY 
    ad_strength_label,
    ad_type,
    campaign_name,
    account_name;
GO

/*
================================================================================
VIEW: vw_ad_type_comparison
DESCRIPTION: Performance comparison across different ad types (RSA, ETA, etc.).
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_ad_type_comparison]
AS
SELECT 
    ad_type,
    account_name,
    
    -- Counts
    COUNT(DISTINCT ad_id) AS ad_count,
    COUNT(DISTINCT ad_group_name) AS ad_groups_with_type,
    COUNT(DISTINCT campaign_name) AS campaigns_with_type,
    
    -- Aggregated metrics
    SUM(total_spend) AS total_spend,
    SUM(total_impressions) AS total_impressions,
    SUM(total_clicks) AS total_clicks,
    SUM(total_conversions) AS total_conversions,
    SUM(total_conversions_value) AS total_conversions_value,
    
    -- Average per ad
    CAST(SUM(total_spend) / NULLIF(COUNT(DISTINCT ad_id), 0) AS DECIMAL(18, 2)) AS avg_spend_per_ad,
    CAST(SUM(total_conversions) / NULLIF(COUNT(DISTINCT ad_id), 0) AS DECIMAL(10, 2)) AS avg_conversions_per_ad,
    
    -- KPIs
    CASE WHEN SUM(total_impressions) > 0 
         THEN CAST((SUM(total_clicks) * 100.0 / SUM(total_impressions)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS ctr_percent,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_clicks)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(total_clicks) > 0 
         THEN CAST((SUM(total_conversions) * 100.0 / SUM(total_clicks)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS conversion_rate_percent,
    CASE WHEN SUM(total_conversions) > 0 
         THEN CAST((SUM(total_spend) / SUM(total_conversions)) AS DECIMAL(18, 4)) 
         ELSE 0 END AS cost_per_conversion,
    CASE WHEN SUM(total_spend) > 0 
         THEN CAST((SUM(total_conversions_value) / SUM(total_spend)) AS DECIMAL(10, 4)) 
         ELSE 0 END AS roas

FROM (
    SELECT 
        ad_id,
        ad_type,
        ad_group_name,
        campaign_name,
        account_name,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value
    FROM [dbo].[vw_ad_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        ad_id,
        ad_type,
        ad_group_name,
        campaign_name,
        account_name
) ads
GROUP BY 
    ad_type,
    account_name;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily ad-level performance metrics with ad copy details.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_ad_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Ad copy effectiveness analysis with performance rankings and optimization suggestions.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_ad_copy_effectiveness';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Ad strength distribution and performance correlation analysis for RSAs.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_ad_strength_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Performance comparison across different ad types.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_ad_type_comparison';
GO
