# Google Ads PowerBI Data Model Documentation

## Overview

This document describes the data model for the Google Ads PowerBI dashboard, including entity relationships, metric definitions, and usage guidelines. The data is sourced from Google Ads data (via Fivetran connector or similar ETL) and stored in SQL Server within the `google_ads` schema.

---

## Table of Contents

1. [Entity Relationship Diagram](#entity-relationship-diagram)
2. [Data Source Tables (google_ads Schema)](#data-source-tables-google_ads-schema)
3. [View Definitions](#view-definitions)
4. [Metric Definitions](#metric-definitions)
5. [Dimension Hierarchies](#dimension-hierarchies)
6. [Date Dimension](#date-dimension)
7. [Data Refresh Schedule](#data-refresh-schedule)

---

## Entity Relationship Diagram

```
┌─────────────────┐
│   Account       │
│   (vw_account_  │
│   performance)  │
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐
│   Campaign      │
│   (vw_campaign_ │
│   performance)  │
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐        ┌─────────────────┐
│   Ad Group      │        │     Keyword     │
│   (vw_ad_group_ │◄──────►│   (vw_keyword_  │
│   performance)  │  1:N   │   performance)  │
└────────┬────────┘        └─────────────────┘
         │ 1:N
         ▼
┌─────────────────┐
│      Ad         │
│   (vw_ad_       │
│   performance)  │
└─────────────────┘


Relationships:
- Account ──(1:N)──► Campaign
- Campaign ──(1:N)──► Ad Group
- Ad Group ──(1:N)──► Ad
- Ad Group ──(1:N)──► Keyword

All fact tables connect to:
┌─────────────────┐
│ Date Dimension  │
│ (vw_date_       │
│ dimension)      │
└─────────────────┘
```

---

## Data Source Tables (google_ads Schema)

The following tables are defined in `AdCampaignDataSchema.sql` within the `google_ads` schema:

### Stats Tables (Daily Metrics)

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `google_ads.account_stats` | Daily account-level statistics | account_id, date | spend (DECIMAL), impressions (BIGINT), clicks (BIGINT), conversions (DECIMAL), conversions_value (DECIMAL), view_through_conversions (DECIMAL) |
| `google_ads.campaign_stats` | Daily campaign-level statistics | campaign_id, date | campaign_id, account_id, spend, impressions, clicks, conversions, video_views, interaction_event_types |
| `google_ads.ad_group_stats` | Daily ad group-level statistics | ad_group_id, date | ad_group_id, campaign_id, account_id, spend, impressions, clicks, conversions |
| `google_ads.ad_stats` | Daily ad-level statistics | ad_id, date | ad_id, ad_group_id, campaign_id, account_id, spend, impressions, clicks, conversions, video_views |
| `google_ads.keyword_stats` | Daily keyword-level statistics | criterion_id, date | criterion_id, ad_group_id, campaign_id, account_id, search_impression_share metrics |

### History Tables (Entity Attributes)

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `google_ads.account_history` | Account metadata changes | account_id, _fivetran_synced | descriptive_name (NVARCHAR), currency_code (NVARCHAR), time_zone (NVARCHAR) |
| `google_ads.campaign_history` | Campaign metadata changes | campaign_id, _fivetran_synced | name, status, advertising_channel_type, bidding_strategy_type, budget_amount (DECIMAL), start_date, end_date |
| `google_ads.ad_group_history` | Ad group metadata changes | ad_group_id, _fivetran_synced | name, status, type, cpc_bid_micros (BIGINT), target_cpa_micros (BIGINT), effective_target_roas (DECIMAL) |
| `google_ads.ad_history` | Ad metadata changes | ad_id, _fivetran_synced | type, status, ad_strength, responsive_search_ad_headlines, expanded_text_ad fields, final_urls |
| `google_ads.ad_group_criterion_history` | Keyword/criteria metadata | criterion_id, _fivetran_synced | keyword_text, keyword_match_type, quality_score (INT), creative_quality_score, cpc_bid_micros |

### Column Data Types Reference

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `*_id` | BIGINT | Entity identifiers (account_id, campaign_id, etc.) |
| `date` | DATE | Reporting date |
| `spend` | DECIMAL(18,6) | Cost/spend amount in account currency |
| `impressions` | BIGINT | Number of ad impressions |
| `clicks` | BIGINT | Number of ad clicks |
| `conversions` | DECIMAL(18,6) | Number of conversion actions |
| `conversions_value` | DECIMAL(18,6) | Monetary value of conversions |
| `*_bid_micros` | BIGINT | Bid amounts in micros (divide by 1,000,000 for actual value) |
| `quality_score` | INT | Google Quality Score (1-10) |
| `_fivetran_synced` | DATETIME2 | Sync timestamp for change tracking |
| `_fivetran_deleted` | BIT | Soft delete flag |

---

## View Definitions

All views are defined in the `dbo` schema and reference tables from the `google_ads` schema.

### Account Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_account_performance` | Daily account metrics | account_stats, account_history | All KPIs calculated, account attributes joined |
| `vw_account_performance_summary` | Aggregated account stats | (via vw_account_performance) | 30-day comparison with previous period |

### Campaign Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_campaign_performance` | Daily campaign metrics | campaign_stats, campaign_history, account_history | Budget utilization, all KPIs |
| `vw_campaign_trend_analysis` | Trend analysis data | (via vw_campaign_performance) | 7-day/30-day moving averages, WoW comparisons |
| `vw_campaign_performance_summary` | Aggregated campaign stats | (via vw_campaign_performance) | Period summary with rankings |

### Ad Group Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_ad_group_performance` | Daily ad group metrics | ad_group_stats, ad_group_history, campaign_history, account_history | Full hierarchy context |
| `vw_ad_group_drilldown` | Hierarchical drill-down | (via vw_ad_group_performance) | Percentage of campaign, rankings |
| `vw_ad_group_performance_summary` | Aggregated ad group stats | (via vw_ad_group_performance) | Period comparison |

### Keyword Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_keyword_performance` | Daily keyword metrics | keyword_stats, ad_group_criterion_history, ad_group_history, campaign_history, account_history | Quality score data, impression share |
| `vw_keyword_top_performers` | Top keywords analysis | (via vw_keyword_performance) | Performance classification, rankings |
| `vw_keyword_quality_score_analysis` | Quality score analysis | (via vw_keyword_performance) | Component breakdown, recommendations |
| `vw_keyword_match_type_analysis` | Match type comparison | (via vw_keyword_performance) | Performance by match type |

### Ad Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_ad_performance` | Daily ad metrics | ad_stats, ad_history, ad_group_history, campaign_history, account_history | Ad copy elements, ad strength |
| `vw_ad_copy_effectiveness` | Ad copy analysis | (via vw_ad_performance) | Performance tiers, optimization suggestions |
| `vw_ad_strength_analysis` | Ad strength correlation | (via vw_ad_performance) | Performance by ad strength |
| `vw_ad_type_comparison` | Ad type comparison | (via vw_ad_performance) | RSA vs ETA performance |

### Date Dimension View

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_date_dimension` | Time-based filtering | account_stats (for date range) | Day/week/month/quarter/year attributes, relative date flags |

---

## Metric Definitions

### Core Metrics

| Metric | Definition | Formula |
|--------|------------|---------|
| **Spend** | Total cost/spend for ads | Direct from source (in account currency) |
| **Impressions** | Number of times ads were shown | Direct from source |
| **Clicks** | Number of clicks on ads | Direct from source |
| **Conversions** | Number of conversion actions | Direct from source |
| **Conversions Value** | Total value of conversions | Direct from source (in account currency) |
| **View-Through Conversions** | Conversions after viewing (not clicking) ad | Direct from source |

### Calculated KPIs

| KPI | Definition | Formula | Good Benchmark |
|-----|------------|---------|----------------|
| **CTR (Click-Through Rate)** | Percentage of impressions that result in clicks | `(Clicks / Impressions) × 100` | >2% (Search), >0.5% (Display) |
| **CPC (Cost Per Click)** | Average cost for each click | `Spend / Clicks` | Varies by industry |
| **Conversion Rate** | Percentage of clicks that convert | `(Conversions / Clicks) × 100` | >3% |
| **Cost Per Conversion** | Average cost to acquire one conversion | `Spend / Conversions` | Varies by business |
| **ROAS (Return on Ad Spend)** | Revenue generated per dollar spent | `Conversions Value / Spend` | >4:1 |
| **CPM (Cost Per Mille)** | Cost per 1,000 impressions | `(Spend / Impressions) × 1000` | $2-15 |

### Quality Metrics

| Metric | Definition | Scale |
|--------|------------|-------|
| **Quality Score** | Google's rating of keyword quality | 1-10 (10 is best) |
| **Creative Quality Score** | Rating of ad relevance | BELOW_AVERAGE, AVERAGE, ABOVE_AVERAGE |
| **Landing Page Experience** | Rating of post-click experience | BELOW_AVERAGE, AVERAGE, ABOVE_AVERAGE |
| **Expected CTR** | Predicted click-through rate | BELOW_AVERAGE, AVERAGE, ABOVE_AVERAGE |
| **Ad Strength** | Overall ad quality indicator | POOR, AVERAGE, GOOD, EXCELLENT |

### Impression Share Metrics

| Metric | Definition |
|--------|------------|
| **Search Impression Share** | Percentage of eligible impressions received |
| **Search Top Impression Share** | Percentage of impressions in top positions |
| **Search Absolute Top Impression Share** | Percentage of impressions in #1 position |
| **Lost IS (Rank)** | Impression share lost due to low Ad Rank |
| **Lost IS (Budget)** | Impression share lost due to budget constraints |

---

## Dimension Hierarchies

### Geographic Hierarchy
```
Account (Top Level)
  └── Campaign
        └── Ad Group
              ├── Ad
              └── Keyword
```

### Time Hierarchy
```
Year
  └── Quarter
        └── Month
              └── Week
                    └── Day
```

### Campaign Type Hierarchy
```
Channel Type (Search, Display, Video, etc.)
  └── Channel Sub-Type
        └── Campaign
```

---

## Date Dimension

### Date Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `date_id` | Surrogate key (YYYYMMDD) | 20240115 |
| `date` | Actual date | 2024-01-15 |
| `day_name` | Day of week name | Monday |
| `day_of_week` | Day of week number (1-7) | 2 |
| `week_of_year` | Week number | 3 |
| `month_number` | Month number (1-12) | 1 |
| `month_name` | Month name | January |
| `quarter_number` | Quarter number (1-4) | 1 |
| `year` | Year | 2024 |

### Relative Date Flags

| Flag | Description |
|------|-------------|
| `is_today` | Current date |
| `is_yesterday` | Previous day |
| `is_last_7_days` | Within last 7 days |
| `is_last_30_days` | Within last 30 days |
| `is_current_month` | Current month |
| `is_previous_month` | Previous month |
| `is_current_year` | Current year |
| `days_ago` | Number of days from today |

---

## Data Refresh Schedule

### Data Sync Schedule
- **Frequency**: Daily (recommended)
- **Typical Sync Time**: 2-4 hours after midnight
- **Data Lag**: Google Ads data is typically 1-2 days behind

### PowerBI Refresh Schedule
- **Recommended**: Daily refresh after data sync completes
- **Time**: Schedule 4-6 hours after data sync start time
- **Example**: If data syncs at 2 AM, schedule PowerBI refresh at 6-8 AM

### Data Freshness Indicators
- All views include `last_synced_at` column from `_fivetran_synced`
- Use this to display data freshness in dashboard headers

---

## Schema Reference

The complete schema definition is available in `AdCampaignDataSchema.sql`, which includes:

1. **Database Configuration**: Azure SQL Database settings and configurations
2. **Schema Creation**: `google_ads` schema for all Google Ads tables
3. **Stats Tables**: Daily metric tables (account_stats, campaign_stats, ad_group_stats, ad_stats, keyword_stats)
4. **History Tables**: Entity metadata tables with change tracking (account_history, campaign_history, ad_group_history, ad_history, ad_group_criterion_history)
5. **Indexes**: Optimized indexes for common query patterns

---

## Best Practices

### PowerBI Report Design

1. **Use Star Schema**: Connect all fact views to the date dimension
2. **Implement Row-Level Security**: Filter by account_id for multi-tenant scenarios
3. **Create Calculation Groups**: For time intelligence (YoY, MoM, WoW)
4. **Use Bookmarks**: For report navigation between different analysis views

### Performance Optimization

1. **Use Aggregated Views**: For dashboard cards and KPIs
2. **Filter at Query Level**: Apply date filters in SQL, not just in PowerBI
3. **Limit Data Volume**: Only import necessary date ranges
4. **Use DirectQuery**: For real-time needs; Import mode for performance

### Common Slicer Combinations

| Slicer Set | Use Case |
|------------|----------|
| Date Range + Account | Executive summary |
| Campaign + Date | Campaign analysis |
| Ad Group + Campaign + Date | Drill-down analysis |
| Keyword Match Type + Campaign | Keyword optimization |
| Ad Type + Campaign | Ad creative analysis |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Initial | Initial data model creation |
