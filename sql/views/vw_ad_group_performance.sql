/*
================================================================================
VIEW: vw_ad_group_performance
DESCRIPTION: Ad Group-level performance metrics with drill-down capability.
             Provides hierarchical data from Account > Campaign > Ad Group.
SCHEMA TABLES:
  - google_ads.ad_group_stats: Daily ad group-level performance metrics
    Columns: ad_group_id, campaign_id, account_id, date, spend, impressions, clicks,
             conversions, conversions_value, view_through_conversions, interactions,
             _fivetran_synced
  - google_ads.ad_group_history: Ad group metadata with change history
    Columns: ad_group_id, campaign_id, name, status, type, cpc_bid_micros,
             cpm_bid_micros, target_cpa_micros, effective_target_cpa_micros,
             effective_target_roas, _fivetran_synced
  - google_ads.campaign_history: Campaign metadata with change history
    Columns: campaign_id, name, status, advertising_channel_type, _fivetran_synced
  - google_ads.account_history: Account metadata with change history
    Columns: account_id, descriptive_name, currency_code, _fivetran_synced
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_ad_group_performance]
AS
SELECT 
    -- Dimension Keys (for drill-down)
    ag.ad_group_id,
    ag.campaign_id,
    ag.account_id,
    ag.date,
    CONVERT(INT, FORMAT(ag.date, 'yyyyMMdd')) AS date_id,
    
    -- Ad Group Information (from history table - latest values)
    agh.name AS ad_group_name,
    agh.status AS ad_group_status,
    agh.type AS ad_group_type,
    agh.cpc_bid_micros / 1000000.0 AS cpc_bid,
    agh.cpm_bid_micros / 1000000.0 AS cpm_bid,
    agh.target_cpa_micros / 1000000.0 AS target_cpa,
    agh.effective_target_cpa_micros / 1000000.0 AS effective_target_cpa,
    agh.effective_target_roas AS effective_target_roas,
    
    -- Campaign Information (for drill-down context)
    ch.name AS campaign_name,
    ch.status AS campaign_status,
    ch.advertising_channel_type,
    
    -- Account Information
    ah.descriptive_name AS account_name,
    ah.currency_code,
    
    -- Raw Metrics
    CAST(ag.spend AS DECIMAL(18, 2)) AS spend,
    ag.impressions,
    ag.clicks,
    COALESCE(ag.conversions, 0) AS conversions,
    COALESCE(ag.conversions_value, 0) AS conversions_value,
    COALESCE(ag.view_through_conversions, 0) AS view_through_conversions,
    
    -- Interaction Metrics
    COALESCE(ag.interactions, 0) AS interactions,
    
    -- Calculated Metrics - Click Through Rate (CTR)
    CASE 
        WHEN ag.impressions > 0 
        THEN CAST((ag.clicks * 100.0 / ag.impressions) AS DECIMAL(10, 4))
        ELSE 0 
    END AS ctr_percent,
    
    -- Calculated Metrics - Cost Per Click (CPC)
    CASE 
        WHEN ag.clicks > 0 
        THEN CAST((ag.spend / ag.clicks) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpc,
    
    -- Calculated Metrics - Conversion Rate
    CASE 
        WHEN ag.clicks > 0 
        THEN CAST((COALESCE(ag.conversions, 0) * 100.0 / ag.clicks) AS DECIMAL(10, 4))
        ELSE 0 
    END AS conversion_rate_percent,
    
    -- Calculated Metrics - Cost Per Conversion
    CASE 
        WHEN COALESCE(ag.conversions, 0) > 0 
        THEN CAST((ag.spend / ag.conversions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS cost_per_conversion,
    
    -- Calculated Metrics - Return on Ad Spend (ROAS)
    CASE 
        WHEN ag.spend > 0 
        THEN CAST((COALESCE(ag.conversions_value, 0) / ag.spend) AS DECIMAL(10, 4))
        ELSE 0 
    END AS roas,
    
    -- Calculated Metrics - Average CPM
    CASE 
        WHEN ag.impressions > 0 
        THEN CAST((ag.spend * 1000.0 / ag.impressions) AS DECIMAL(18, 4))
        ELSE 0 
    END AS avg_cpm,
    
    -- CPA vs Target comparison
    CASE 
        WHEN COALESCE(ag.conversions, 0) > 0 AND agh.target_cpa_micros > 0
        THEN CAST(((ag.spend / ag.conversions) - (agh.target_cpa_micros / 1000000.0)) AS DECIMAL(18, 4))
        ELSE NULL 
    END AS cpa_vs_target_variance,
    
    -- Metadata
    ag._fivetran_synced AS last_synced_at

FROM google_ads.ad_group_stats ag
LEFT JOIN (
    SELECT 
        ad_group_id,
        name,
        status,
        type,
        cpc_bid_micros,
        cpm_bid_micros,
        target_cpa_micros,
        effective_target_cpa_micros,
        effective_target_roas,
        ROW_NUMBER() OVER (PARTITION BY ad_group_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.ad_group_history
) agh ON ag.ad_group_id = agh.ad_group_id AND agh.rn = 1
LEFT JOIN (
    SELECT 
        campaign_id,
        name,
        status,
        advertising_channel_type,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.campaign_history
) ch ON ag.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (
    SELECT 
        account_id,
        descriptive_name,
        currency_code,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn
    FROM google_ads.account_history
) ah ON ag.account_id = ah.account_id AND ah.rn = 1;
GO

/*
================================================================================
VIEW: vw_ad_group_drilldown
DESCRIPTION: Hierarchical ad group view optimized for drill-down from 
             Campaign to Ad Group in PowerBI visuals.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_ad_group_drilldown]
AS
WITH AdGroupAggregated AS (
    SELECT 
        account_id,
        account_name,
        campaign_id,
        campaign_name,
        campaign_status,
        advertising_channel_type,
        ad_group_id,
        ad_group_name,
        ad_group_status,
        ad_group_type,
        currency_code,
        
        -- Aggregated metrics
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions,
        SUM(conversions_value) AS total_conversions_value,
        
        -- Date range
        MIN(date) AS first_date,
        MAX(date) AS last_date,
        COUNT(DISTINCT date) AS active_days
    FROM [dbo].[vw_ad_group_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY 
        account_id,
        account_name,
        campaign_id,
        campaign_name,
        campaign_status,
        advertising_channel_type,
        ad_group_id,
        ad_group_name,
        ad_group_status,
        ad_group_type,
        currency_code
)
SELECT 
    -- Hierarchy path for drill-down
    CONCAT(account_name, ' > ', campaign_name, ' > ', ad_group_name) AS full_hierarchy_path,
    
    -- Dimensions
    account_id,
    account_name,
    campaign_id,
    campaign_name,
    campaign_status,
    advertising_channel_type,
    ad_group_id,
    ad_group_name,
    ad_group_status,
    ad_group_type,
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
    
    -- Percentage of campaign metrics
    CAST((total_spend * 100.0 / 
          NULLIF(SUM(total_spend) OVER (PARTITION BY campaign_id), 0)) AS DECIMAL(10, 2)) 
          AS pct_of_campaign_spend,
    CAST((total_clicks * 100.0 / 
          NULLIF(SUM(total_clicks) OVER (PARTITION BY campaign_id), 0)) AS DECIMAL(10, 2)) 
          AS pct_of_campaign_clicks,
    CAST((total_conversions * 100.0 / 
          NULLIF(SUM(total_conversions) OVER (PARTITION BY campaign_id), 0)) AS DECIMAL(10, 2)) 
          AS pct_of_campaign_conversions,
    
    -- Rank within campaign
    DENSE_RANK() OVER (PARTITION BY campaign_id ORDER BY total_spend DESC) AS spend_rank_in_campaign,
    DENSE_RANK() OVER (PARTITION BY campaign_id ORDER BY total_conversions DESC) AS conversions_rank_in_campaign,
    
    -- Performance indicators
    CASE 
        WHEN total_conversions > 0 AND (total_spend / total_conversions) < 
             AVG(CASE WHEN total_conversions > 0 THEN total_spend / total_conversions END) 
             OVER (PARTITION BY campaign_id)
        THEN 'Above Average'
        WHEN total_conversions > 0 
        THEN 'Below Average'
        ELSE 'No Conversions'
    END AS performance_indicator,
    
    -- Date range info
    first_date,
    last_date,
    active_days

FROM AdGroupAggregated;
GO

/*
================================================================================
VIEW: vw_ad_group_performance_summary
DESCRIPTION: Summary view for ad group performance with period comparisons.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_ad_group_performance_summary]
AS
WITH CurrentPeriod AS (
    SELECT 
        ad_group_id,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions
    FROM [dbo].[vw_ad_group_performance]
    WHERE date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
      AND date < CAST(GETDATE() AS DATE)
    GROUP BY ad_group_id
),
PreviousPeriod AS (
    SELECT 
        ad_group_id,
        SUM(spend) AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(conversions) AS total_conversions
    FROM [dbo].[vw_ad_group_performance]
    WHERE date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
      AND date < DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
    GROUP BY ad_group_id
)
SELECT 
    agp.ad_group_id,
    agp.ad_group_name,
    agp.ad_group_status,
    agp.campaign_name,
    agp.account_name,
    
    -- Current period
    cp.total_spend AS current_spend,
    cp.total_impressions AS current_impressions,
    cp.total_clicks AS current_clicks,
    cp.total_conversions AS current_conversions,
    
    -- Previous period
    COALESCE(pp.total_spend, 0) AS previous_spend,
    COALESCE(pp.total_conversions, 0) AS previous_conversions,
    
    -- Change percentages
    CASE WHEN COALESCE(pp.total_spend, 0) > 0 
         THEN CAST(((cp.total_spend - pp.total_spend) * 100.0 / pp.total_spend) AS DECIMAL(10, 2)) 
         ELSE NULL END AS spend_change_percent,
    CASE WHEN COALESCE(pp.total_conversions, 0) > 0 
         THEN CAST(((cp.total_conversions - pp.total_conversions) * 100.0 / pp.total_conversions) AS DECIMAL(10, 2)) 
         ELSE NULL END AS conversions_change_percent

FROM (
    SELECT DISTINCT 
        ad_group_id, 
        ad_group_name, 
        ad_group_status,
        campaign_name,
        account_name
    FROM [dbo].[vw_ad_group_performance]
) agp
INNER JOIN CurrentPeriod cp ON agp.ad_group_id = cp.ad_group_id
LEFT JOIN PreviousPeriod pp ON agp.ad_group_id = pp.ad_group_id;
GO

-- Add descriptions
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Daily ad group-level performance metrics with calculated KPIs and hierarchy context.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_ad_group_performance';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Hierarchical ad group view optimized for drill-down functionality in PowerBI.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_ad_group_drilldown';
GO

EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Ad group performance summary with 30-day period comparisons.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_ad_group_performance_summary';
GO
