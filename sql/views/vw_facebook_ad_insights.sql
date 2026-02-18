/*
================================================================================
VIEW: vw_facebook_ad_insights
DESCRIPTION: Detailed Facebook Ads insights with demographic and placement breakdowns.
             Provides granular performance data for audience and placement analysis.
             
NOTE: The demographic and placement breakdown views below require extended columns
      in the basic_ad table that may be available depending on your Fivetran
      connector configuration. If these columns are not present in your setup,
      please contact your data administrator to enable breakdown syncing.

SCHEMA TABLES:
  - facebook_ads.basic_ad: Daily ad-level performance metrics
    Required columns: ad_id, adset_id, campaign_id, account_id, date, spend, 
                      impressions, clicks, reach, actions, action_values, _fivetran_synced
    Optional breakdown columns (if configured): age, gender, publisher_platform, 
                                                platform_position, impression_device, device_platform
  - facebook_ads.ad_history: Ad metadata
    Columns: ad_id, name, status, _fivetran_synced
  - facebook_ads.adset_history: Ad Set metadata
    Columns: adset_id, name, _fivetran_synced
  - facebook_ads.campaign_history: Campaign metadata
    Columns: campaign_id, name, objective, _fivetran_synced
  - facebook_ads.account_history: Account metadata
    Columns: account_id, name, currency, _fivetran_synced
================================================================================
*/

-- Note: The following demographic and placement insight views are disabled by default
-- because they require optional breakdown columns in the basic_ad table.
-- Uncomment and use these views only if your Fivetran connector syncs demographic
-- and placement breakdown data to the basic_ad table.

/*
-- OPTIONAL: Demographic Insights View (requires age, gender columns in basic_ad)
CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_insights_demographics]
AS
SELECT 
    a.ad_id,
    a.adset_id,
    a.campaign_id,
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    a.age AS age_range,
    a.gender,
    adh.name AS ad_name,
    adsh.name AS adset_name,
    ch.name AS campaign_name,
    ch.objective AS campaign_objective,
    ah.name AS account_name,
    ah.currency AS currency_code,
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    a.reach,
    COALESCE(a.actions, 0) AS total_actions,
    COALESCE(a.action_values, 0) AS total_action_value,
    CASE WHEN a.impressions > 0 THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4)) ELSE 0 END AS ctr_percent,
    CASE WHEN a.clicks > 0 THEN CAST((a.spend / a.clicks) AS DECIMAL(18, 4)) ELSE 0 END AS avg_cpc,
    CASE WHEN COALESCE(a.actions, 0) > 0 THEN CAST((a.spend / a.actions) AS DECIMAL(18, 4)) ELSE 0 END AS cost_per_action,
    CASE WHEN a.spend > 0 THEN CAST((COALESCE(a.action_values, 0) / a.spend) AS DECIMAL(10, 4)) ELSE 0 END AS roas,
    a._fivetran_synced AS last_synced_at
FROM facebook_ads.basic_ad a
LEFT JOIN (SELECT ad_id, name, ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.ad_history WHERE COALESCE(_fivetran_deleted, 0) = 0) adh ON a.ad_id = adh.ad_id AND adh.rn = 1
LEFT JOIN (SELECT adset_id, name, ROW_NUMBER() OVER (PARTITION BY adset_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.adset_history WHERE COALESCE(_fivetran_deleted, 0) = 0) adsh ON a.adset_id = adsh.adset_id AND adsh.rn = 1
LEFT JOIN (SELECT campaign_id, name, objective, ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.campaign_history WHERE COALESCE(_fivetran_deleted, 0) = 0) ch ON a.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (SELECT account_id, name, currency, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.account_history WHERE COALESCE(_fivetran_deleted, 0) = 0) ah ON a.account_id = ah.account_id AND ah.rn = 1
WHERE a.age IS NOT NULL OR a.gender IS NOT NULL;
GO
*/

/*
-- OPTIONAL: Placement Insights View (requires publisher_platform, platform_position columns in basic_ad)
CREATE OR ALTER VIEW [dbo].[vw_facebook_ad_insights_placements]
AS
SELECT 
    a.ad_id,
    a.adset_id,
    a.campaign_id,
    a.account_id,
    a.date,
    CONVERT(INT, FORMAT(a.date, 'yyyyMMdd')) AS date_id,
    a.publisher_platform,
    a.platform_position,
    a.impression_device,
    a.device_platform,
    CONCAT(COALESCE(a.publisher_platform, 'Unknown'), ' - ', COALESCE(a.platform_position, 'Unknown')) AS placement_label,
    adh.name AS ad_name,
    adsh.name AS adset_name,
    ch.name AS campaign_name,
    ch.objective AS campaign_objective,
    ah.name AS account_name,
    ah.currency AS currency_code,
    CAST(a.spend AS DECIMAL(18, 2)) AS spend,
    a.impressions,
    a.clicks,
    a.reach,
    COALESCE(a.actions, 0) AS total_actions,
    COALESCE(a.action_values, 0) AS total_action_value,
    CASE WHEN a.impressions > 0 THEN CAST((a.clicks * 100.0 / a.impressions) AS DECIMAL(10, 4)) ELSE 0 END AS ctr_percent,
    CASE WHEN a.clicks > 0 THEN CAST((a.spend / a.clicks) AS DECIMAL(18, 4)) ELSE 0 END AS avg_cpc,
    CASE WHEN COALESCE(a.actions, 0) > 0 THEN CAST((a.spend / a.actions) AS DECIMAL(18, 4)) ELSE 0 END AS cost_per_action,
    CASE WHEN a.spend > 0 THEN CAST((COALESCE(a.action_values, 0) / a.spend) AS DECIMAL(10, 4)) ELSE 0 END AS roas,
    CASE WHEN a.impressions > 0 THEN CAST((a.spend * 1000.0 / a.impressions) AS DECIMAL(18, 4)) ELSE 0 END AS avg_cpm,
    a._fivetran_synced AS last_synced_at
FROM facebook_ads.basic_ad a
LEFT JOIN (SELECT ad_id, name, ROW_NUMBER() OVER (PARTITION BY ad_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.ad_history WHERE COALESCE(_fivetran_deleted, 0) = 0) adh ON a.ad_id = adh.ad_id AND adh.rn = 1
LEFT JOIN (SELECT adset_id, name, ROW_NUMBER() OVER (PARTITION BY adset_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.adset_history WHERE COALESCE(_fivetran_deleted, 0) = 0) adsh ON a.adset_id = adsh.adset_id AND adsh.rn = 1
LEFT JOIN (SELECT campaign_id, name, objective, ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.campaign_history WHERE COALESCE(_fivetran_deleted, 0) = 0) ch ON a.campaign_id = ch.campaign_id AND ch.rn = 1
LEFT JOIN (SELECT account_id, name, currency, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _fivetran_synced DESC) AS rn FROM facebook_ads.account_history WHERE COALESCE(_fivetran_deleted, 0) = 0) ah ON a.account_id = ah.account_id AND ah.rn = 1
WHERE a.publisher_platform IS NOT NULL OR a.platform_position IS NOT NULL;
GO
*/

-- The summary views for demographics, placements, and device performance are also commented out
-- as they depend on the optional breakdown views above.
-- Uncomment the base views first, then uncomment these summary views if needed.

/*
CREATE OR ALTER VIEW [dbo].[vw_facebook_demographic_summary] ...
CREATE OR ALTER VIEW [dbo].[vw_facebook_placement_summary] ...
CREATE OR ALTER VIEW [dbo].[vw_facebook_device_performance] ...
CREATE OR ALTER VIEW [dbo].[vw_facebook_age_gender_matrix] ...
*/

-- Add placeholder description
PRINT 'Facebook Ad Insights views require optional breakdown columns (age, gender, publisher_platform, etc.)';
PRINT 'Please verify your Fivetran connector configuration includes these breakdown columns before enabling.';
GO
