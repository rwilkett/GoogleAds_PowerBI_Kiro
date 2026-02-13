# Google Ads PowerBI Data Model Documentation

## Overview

This document describes the data model for the Google Ads PowerBI dashboard, including entity relationships, metric definitions, and usage guidelines. The data is sourced from Fivetran's Google Ads connector and stored in SQL Server.

---

## Table of Contents

1. [Entity Relationship Diagram](#entity-relationship-diagram)
2. [Data Source Tables (Fivetran Schema)](#data-source-tables-fivetran-schema)
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

## Data Source Tables (Fivetran Schema)

### Stats Tables (Daily Metrics)

| Table Name | Description | Key Columns |
|------------|-------------|-------------|
| `google_ads.account_stats` | Daily account-level statistics | account_id, date, spend, impressions, clicks, conversions |
| `google_ads.campaign_stats` | Daily campaign-level statistics | campaign_id, account_id, date, spend, impressions, clicks, conversions |
| `google_ads.ad_group_stats` | Daily ad group-level statistics | ad_group_id, campaign_id, date, spend, impressions, clicks, conversions |
| `google_ads.ad_stats` | Daily ad-level statistics | ad_id, ad_group_id, date, spend, impressions, clicks, conversions |
| `google_ads.keyword_stats` | Daily keyword-level statistics | criterion_id, ad_group_id, date, spend, impressions, clicks, conversions |

### History Tables (Entity Attributes)

| Table Name | Description | Key Columns |
|------------|-------------|-------------|
| `google_ads.account_history` | Account metadata changes | account_id, descriptive_name, currency_code, time_zone |
| `google_ads.campaign_history` | Campaign metadata changes | campaign_id, name, status, advertising_channel_type, budget_amount |
| `google_ads.ad_group_history` | Ad group metadata changes | ad_group_id, name, status, type, cpc_bid_micros |
| `google_ads.ad_history` | Ad metadata changes | ad_id, type, status, ad_strength, headlines, descriptions |
| `google_ads.ad_group_criterion_history` | Keyword/criteria metadata | criterion_id, keyword_text, keyword_match_type, quality_score |

---

## View Definitions

### Account Level Views

| View Name | Purpose | Key Features |
|-----------|---------|--------------|
| `vw_account_performance` | Daily account metrics | All KPIs calculated, account attributes joined |
| `vw_account_performance_summary` | Aggregated account stats | 30-day comparison with previous period |

### Campaign Level Views

| View Name | Purpose | Key Features |
|-----------|---------|--------------|
| `vw_campaign_performance` | Daily campaign metrics | Budget utilization, all KPIs |
| `vw_campaign_trend_analysis` | Trend analysis data | 7-day/30-day moving averages, WoW comparisons |
| `vw_campaign_performance_summary` | Aggregated campaign stats | Period summary with rankings |

### Ad Group Level Views

| View Name | Purpose | Key Features |
|-----------|---------|--------------|
| `vw_ad_group_performance` | Daily ad group metrics | Full hierarchy context |
| `vw_ad_group_drilldown` | Hierarchical drill-down | Percentage of campaign, rankings |
| `vw_ad_group_performance_summary` | Aggregated ad group stats | Period comparison |

### Keyword Level Views

| View Name | Purpose | Key Features |
|-----------|---------|--------------|
| `vw_keyword_performance` | Daily keyword metrics | Quality score data, impression share |
| `vw_keyword_top_performers` | Top keywords analysis | Performance classification, rankings |
| `vw_keyword_quality_score_analysis` | Quality score analysis | Component breakdown, recommendations |
| `vw_keyword_match_type_analysis` | Match type comparison | Performance by match type |

### Ad Level Views

| View Name | Purpose | Key Features |
|-----------|---------|--------------|
| `vw_ad_performance` | Daily ad metrics | Ad copy elements, ad strength |
| `vw_ad_copy_effectiveness` | Ad copy analysis | Performance tiers, optimization suggestions |
| `vw_ad_strength_analysis` | Ad strength correlation | Performance by ad strength |
| `vw_ad_type_comparison` | Ad type comparison | RSA vs ETA performance |

### Date Dimension View

| View Name | Purpose | Key Features |
|-----------|---------|--------------|
| `vw_date_dimension` | Time-based filtering | Day/week/month/quarter/year attributes, relative date flags |

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

### Fivetran Sync Schedule
- **Frequency**: Daily (recommended)
- **Typical Sync Time**: 2-4 hours after midnight
- **Data Lag**: Google Ads data is typically 1-2 days behind

### PowerBI Refresh Schedule
- **Recommended**: Daily refresh after Fivetran sync completes
- **Time**: Schedule 4-6 hours after Fivetran sync start time
- **Example**: If Fivetran syncs at 2 AM, schedule PowerBI refresh at 6-8 AM

### Data Freshness Indicators
- All views include `last_synced_at` column from `_fivetran_synced`
- Use this to display data freshness in dashboard headers

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
