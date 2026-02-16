/*
================================================================================
VIEW: vw_keyword_performance
DESCRIPTION: Keyword-level performance metrics including quality score analysis.
             Provides insights into keyword performance and bid optimization.
SCHEMA TABLES:
  - google_ads.keyword_stats: Daily keyword-level performance metrics
    Columns: criterion_id, ad_group_id, campaign_id, account_id, date, spend,
             impressions, clicks, conversions, conversions_value,
             search_impression_share, search_top_impression_share,
             search_absolute_top_impression_share, search_rank_lost_impression_share,
             search_budget_lost_impression_share, _fivetran_synced
  - google_ads.ad_group_criterion_history: Keyword and criteria metadata
    Columns: criterion_id, ad_group_id, type, status, keyword_text, keyword_match_type,
             system_serving_status, approval_status, quality_score, creative_quality_score,
             post_click_quality_score, search_predicted_ctr, cpc_bid_micros,
             effective_cpc_bid_micros, final_url_suffix, _fivetran_synced
  - google_ads.ad_group_history: Ad group metadata
    Columns: ad_group_id, name, _fivetran_synced
  - google_ads.campaign_history: Campaign metadata
    Columns: campaign_id, name, _fivetran_synced
  - google_ads.account_history: Account metadata
    Columns: account_id, descriptive_name, currency_code, _fivetran_synced
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_keyword_performance]
AS
SELECT 
    -- Dimension Keys
    k.criterion_id AS keyword_id,
    k.ad_group_id,
    k.campaign_id,
    k.account_id,
    k.date,
    CONVERT(INT, FORMAT(k.date, 'yyyyMMdd')) AS date_id,
    
    -- Keyword Information (from criterion history - latest values)
    kh.keyword_text,
    kh.keyword_match_type,
    kh.status AS keyword_status,
    kh.system_serving_status,
    kh.approval_status,
    
    -- Quality Score Metrics
    kh.quality_score,
    kh.creative_quality_score,
    kh.post_click_quality_score,
    kh.search_predicted_ctr,
    
    -- Bid Information
    kh.cpc_bid_micros / 1000000.0 AS cpc_bid,
    kh.effective_cpc_bid_micros / 1000000.0 AS effective_cpc_bid,
    kh.final_url_suffix,
    
    -- Hierarchy context
    agh.name AS ad_group_name,
    ch.name AS campaign_name,
    ah.descriptive_name AS account_name,
    ah.currency_code,
    
    -- Raw Metrics
    CAST(k.spend AS DECIMAL(18, 2)) AS spend,
    k.impressions,
    k.clicks,
    COALESCE(k.conversions, 0) AS conversions,
    COALESCE(k.conversions_value, 0) AS conversions_value,
    
    -- Search Metrics
    COALESCE(k.search_impression_share, 0) AS search_impression_share,
    COALESCE(k.search_top_impression_share, 0) AS search_top_impression_share,
    COALESCE(k.search_absolute_top_impression_share, 0) AS search_absolute_top_impression_share,
    COALESCE(k.search_rank_lost_impression_share, 0) AS search_rank_lost_impression_share,
    COALESCE(k.search_budget_lost_impression_share, 0) AS search_budget_lost_impression_share,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN k.impressions > 0 
        THEN CAST((k.clicks * 100.0 / k.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN k.clicks > 0 
        THEN CAST((k.spend / k.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Conversion Rate
    CASE 
        WHEN k.clicks > 0 
        THEN CAST((COALESCE(k.conversions, 0) * 100.0 / k.clicks) AS DECIMAL(10, 4))
        ELSE 0 
    END AS conversion_rate_percent,
    
    -- Calculated Metrics - Cost Per Conversion
    CASE 
        WHEN COALESCE(k.conversions, 0) > 0 
        THEN CAST((k.spend / k.conversions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_conversion,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN k.spend > 0 
        THEN CAST((COALESCE(k.conversions_value, 0) / k.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Quality Score Category
    CASE 
        WHEN kh.quality_score >= 7 THEN 'High (7-10)'
        WHEN kh.quality_score >= 4 THEN 'Medium (4-6)'
        WHEN kh.quality_score >= 1 THEN 'Low (1-3)'
        ELSE 'Not Available'
    END AS quality_score_category,
    
    -- Metadata
    k._fivetran_synced AS last_synced_at

FROM google_ads.keyword_stats k
LEFT JOIN (
    SELECT 
        criterion_id,
        keyword_text,
        keyword_match_type,
        status,
        system_serving_status,
        approval_status,
        quality_score,
        creative_quality_score,
        post_click_quality_score,
        search_predicted_ctr,
        cpc_bid_micros,
        effective_cpc_bid_micros,
        final_url_suffix,
        ROW_NUMBER() OVER (PARTITION BY criterion_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.ad_group_criterion_history
    WHERE type = 'KEYWORD'
) kh ON k.criterion_id = kh.criterion_id AND kh.rn = 1
LEFT JOIN (
    SELECT 
        ad_group_id,
        name,
        ROW_NUMBER() OVER (PARTITION BY ad_group_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.ad_group_history
) agh ON k.ad_group_id = agh.ad_group_id AND agh.rn = 1
LEFT JOIN (
    SELECT 
        campaign_id,
        name,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.campaign_history
) ch ON k.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT 
        account_id,
        descriptive_name,
        currency_code,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.account_history
) ah ON k.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_keyword_top_performers
DESCRIPTION: Top performing keywords based on conversions, ROAS, and efficiency.
             Useful for identifying optimization opportunities.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_keyword_top_performers]
AS
WITH KeywordAggregated AS (
    SELECT 
        keyword_id,
        keyword_text,
        keyword_match_type,
        keyword_status,
        quality_score,
        quality_score_category,
        ad_group_name,
        campaign_name,
        account_name,
        currency_code,
        
        -- Aggregated metrics (last 30 days)
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value,
        AVG(search_impression_share) AS avg_impression_share
    FROM [dbo].[vw_keyword_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        keyword_id,
        keyword_text,
        keyword_match_type,
        keyword_status,
        quality_score,
        quality_score_category,
        ad_group_name,
        campaign_name,
        account_name,
        currency_code
)
SELECT 
    keyword_id,
    keyword_text,
    keyword_match_type,
    keyword_status,
    quality_score,
    quality_score_category,
    ad_group_name,
    campaign_name,
    account_name,
    currency_code,
    
    -- Metrics
    total_spend,
    total_impressions,
    total_clicks,
    total_conversions,
    total_conversions_value,
    
    -- Calculated KPIs
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
    avg_impression_share,
    
    -- Rankings
    DENSE_RANK() OVER (ORDER BY total_conversions DESC) AS conversions_rank,
    DENSE_RANK() OVER (ORDER BY total_spend DESC) AS spend_rank,
    DENSE_RANK() OVER (ORDER BY CASE WHEN total_spend > 0 
                                      THEN total_conversions_value / total_spend 
                                      ELSE 0 END DESC) AS roas_rank,
    DENSE_RANK() OVER (ORDER BY CASE WHEN total_conversions > 0 
                                      THEN total_spend / total_conversions 
                                      ELSE 999999 END ASC) AS efficiency_rank,
    
    -- Performance classification
    CASE 
        WHEN total_conversions >= 10 AND 
             (CASE WHEN total_spend > 0 THEN total_conversions_value / total_spend ELSE 0 END) >= 2
        THEN 'Star Performer'
        WHEN total_conversions >= 5 AND 
             (CASE WHEN total_spend > 0 THEN total_conversions_value / total_spend ELSE 0 END) >= 1
        THEN 'Strong Performer'
        WHEN total_clicks >= 100 AND total_conversions < 2
        THEN 'High Traffic, Low Conversion'
        WHEN total_impressions >= 1000 AND total_clicks < 10
        THEN 'Low CTR'
        WHEN total_spend > 0 AND total_conversions = 0
        THEN 'Spending, No Conversions'
        ELSE 'Developing'
    END AS performance_classification

FROM KeywordAggregated
WHERE total_impressions > 0;  -- Only include keywords with activity
GO

/*
================================================================================
VIEW: vw_keyword_quality_score_analysis
DESCRIPTION: Quality score distribution and impact analysis for keywords.
             Helps identify opportunities to improve quality scores.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_keyword_quality_score_analysis]
AS
WITH KeywordQS AS (
    SELECT 
        keyword_id,
        keyword_text,
        keyword_match_type,
        keyword_status,
        quality_score,
        quality_score_category,
        creative_quality_score,
        post_click_quality_score,
        search_predicted_ctr,
        ad_group_name,
        campaign_name,
        account_name,
        
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions
    FROM [dbo].[vw_keyword_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
      AND quality_score IS NOT NULL
    GROUP BY 
        keyword_id,
        keyword_text,
        keyword_match_type,
        keyword_status,
        quality_score,
        quality_score_category,
        creative_quality_score,
        post_click_quality_score,
        search_predicted_ctr,
        ad_group_name,
        campaign_name,
        account_name
)
SELECT 
    keyword_id,
    keyword_text,
    keyword_match_type,
    keyword_status,
    quality_score,
    quality_score_category,
    
    -- Quality score components
    creative_quality_score,
    post_click_quality_score,
    search_predicted_ctr,
    
    -- Context
    ad_group_name,
    campaign_name,
    account_name,
    
    -- Metrics
    total_spend,
    total_impressions,
    total_clicks,
    total_conversions,
    
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
    
    -- Quality score improvement recommendations
    CASE 
        WHEN quality_score < 4 THEN 'Critical - Needs Immediate Attention'
        WHEN quality_score < 7 THEN 'Moderate - Room for Improvement'
        ELSE 'Good - Maintain Current Strategy'
    END AS qs_action_priority,
    
    -- Component-specific recommendations
    CASE 
        WHEN creative_quality_score = 'BELOW_AVERAGE' THEN 'Improve ad relevance'
        WHEN creative_quality_score = 'AVERAGE' THEN 'Test new ad copy'
        ELSE 'Ad creative is strong'
    END AS creative_recommendation,
    
    CASE 
        WHEN post_click_quality_score = 'BELOW_AVERAGE' THEN 'Improve landing page experience'
        WHEN post_click_quality_score = 'AVERAGE' THEN 'Optimize landing page'
        ELSE 'Landing page is effective'
    END AS landing_page_recommendation,
    
    CASE 
        WHEN search_predicted_ctr = 'BELOW_AVERAGE' THEN 'Improve expected CTR'
        WHEN search_predicted_ctr = 'AVERAGE' THEN 'Test more compelling ad copy'
        ELSE 'CTR expectations are good'
    END AS ctr_recommendation,
    
    -- Estimated impact if QS improved to 7+
    CASE 
        WHEN quality_score < 7 AND total_clicks > 0
        THEN CAST((total_spend / total_clicks) * 0.2 AS DECIMAL(18, 4))  -- ~20% potential CPC reduction
        ELSE 0 
    END AS estimated_cpc_savings_potential

FROM KeywordQS;
GO

/*
================================================================================
VIEW: vw_keyword_match_type_analysis
DESCRIPTION: Keyword performance breakdown by match type for optimization insights.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_keyword_match_type_analysis]
AS
SELECT 
    keyword_match_type,
    campaign_name,
    account_name,
    
    -- Counts
    COUNT(DISTINCT keyword_id) AS keyword_count,
    
    -- Aggregated metrics
    SUM(total_spend) AS total_spend,
    SUM(total_impressions) AS total_impressions,
    SUM(total_clicks) AS total_clicks,
    SUM(total_conversions) AS total_conversions,
    SUM(total_conversions_value) AS total_conversions_value,
    
    -- Average quality score
    AVG(CAST(quality_score AS DECIMAL(10, 2))) AS avg_quality_score,
    
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
        keyword_id,
        keyword_match_type,
        quality_score,
        campaign_name,
        account_name,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value
    FROM [dbo].[vw_keyword_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        keyword_id,
        keyword_match_type,
        quality_score,
        campaign_name,
        account_name
) kw
GROUP BY 
    keyword_match_type,
    campaign_name,
    account_name;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily keyword-level performance metrics with quality score data.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_keyword_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Top performing keywords ranked by conversions, ROAS, and efficiency.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_keyword_top_performers';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Quality score analysis with component breakdown and improvement recommendations.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_keyword_quality_score_analysis';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Keyword performance breakdown by match type for optimization insights.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_keyword_match_type_analysis';
GO
