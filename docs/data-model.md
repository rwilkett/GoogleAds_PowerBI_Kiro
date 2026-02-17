# Ad Campaign & CRM Data Model Documentation

## Overview

This document describes the data model for the multi-platform analytics PowerBI dashboard, including entity relationships, metric definitions, and usage guidelines. The data is sourced from:
- **Google Ads** data (via Fivetran connector) - stored in the `google_ads` schema
- **Facebook Ads** data (via Fivetran connector) - stored in the `facebook_ads` schema
- **HubSpot CRM** data (via Fivetran connector) - stored in the `hubspot` schema

---

## Table of Contents

1. [Entity Relationship Diagram](#entity-relationship-diagram)
2. [Data Source Tables (google_ads Schema)](#data-source-tables-google_ads-schema)
3. [Data Source Tables (facebook_ads Schema)](#data-source-tables-facebook_ads-schema)
4. [Data Source Tables (hubspot Schema)](#data-source-tables-hubspot-schema)
5. [View Definitions](#view-definitions)
6. [Facebook Ads View Definitions](#facebook-ads-view-definitions)
7. [HubSpot View Definitions](#hubspot-view-definitions)
8. [Metric Definitions](#metric-definitions)
9. [Facebook Ads Metric Definitions](#facebook-ads-metric-definitions)
10. [HubSpot Metric Definitions](#hubspot-metric-definitions)
11. [Dimension Hierarchies](#dimension-hierarchies)
12. [Date Dimension](#date-dimension)
13. [Data Refresh Schedule](#data-refresh-schedule)

---

## Entity Relationship Diagram

### Google Ads Data Model

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

### Facebook Ads Data Model

```
┌─────────────────┐
│   Account       │
│ (vw_facebook_   │
│ account_        │
│ performance)    │
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐
│   Campaign      │
│ (vw_facebook_   │
│ campaign_       │
│ performance)    │
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐
│    Ad Set       │
│ (vw_facebook_   │
│ adset_          │
│ performance)    │
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐        ┌─────────────────┐
│      Ad         │───────►│    Creative     │
│ (vw_facebook_   │   1:1  │  (creative_     │
│ ad_performance) │        │   history)      │
└─────────────────┘        └─────────────────┘

Facebook Ads Relationships:
- Account ──(1:N)──► Campaign
- Campaign ──(1:N)──► Ad Set
- Ad Set ──(1:N)──► Ad
- Ad ──(1:1)──► Creative

Insight Breakdowns (vw_facebook_ad_insights):
┌─────────────────────────────────────────────┐
│              Ad Insights                     │
│  Breakdowns by:                             │
│  - Demographics (age, gender)               │
│  - Placements (platform, position)          │
│  - Devices (mobile, desktop)                │
└─────────────────────────────────────────────┘
```

### HubSpot CRM Data Model

```
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│    Contact      │◄──────►│    Company      │◄──────►│     Deal        │
│  (vw_hubspot_   │  N:1   │  (vw_hubspot_   │  1:N   │  (vw_hubspot_   │
│   contact_      │        │   company_      │        │   deal_         │
│  performance)   │        │  performance)   │        │  performance)   │
└────────┬────────┘        └────────┬────────┘        └────────┬────────┘
         │                          │                          │
         │ N:N                      │ N:N                      │ N:N
         ▼                          ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Engagement                                     │
│                    (vw_hubspot_engagement_performance)                   │
│   Types: CALL, MEETING, EMAIL, NOTE, TASK                               │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐        ┌─────────────────┐
│  Email Campaign │───────►│   Email Event   │
│  (vw_hubspot_   │  1:N   │  (SENT, OPEN,   │
│   email_        │        │   CLICK, etc.)  │
│  performance)   │        │                 │
└─────────────────┘        └─────────────────┘

┌─────────────────┐        ┌─────────────────┐
│  Deal Pipeline  │───────►│   Deal Stage    │
│                 │  1:N   │                 │
└─────────────────┘        └─────────────────┘


HubSpot Relationships:
- Contact ──(N:1)──► Company (associated_company_id)
- Contact ──(1:N)──► Deal (associated_contact_id)
- Company ──(1:N)──► Deal (associated_company_id)
- Contact ──(N:N)──► Engagement (via engagement_contact)
- Company ──(N:N)──► Engagement (via engagement_company)
- Deal ──(N:N)──► Engagement (via engagement_deal)
- Email Campaign ──(1:N)──► Email Event
- Deal Pipeline ──(1:N)──► Deal Stage
- Deal ──(N:1)──► Deal Stage

All entities associated with:
┌─────────────────┐
│     Owner       │
│ (Sales Rep/     │
│  Team Member)   │
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

## Data Source Tables (facebook_ads Schema)

The following tables are expected in the `facebook_ads` schema (via Fivetran connector):

### Stats Tables (Daily Metrics)

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `facebook_ads.basic_ad` | Daily ad-level statistics | ad_id, date | spend, impressions, clicks, reach, actions, action_values |

### History Tables (Entity Attributes)

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `facebook_ads.account_history` | Account metadata | account_id, _fivetran_synced | name, account_status, currency, timezone_name |
| `facebook_ads.campaign_history` | Campaign metadata | campaign_id, _fivetran_synced | name, status, objective, daily_budget, lifetime_budget |
| `facebook_ads.adset_history` | Ad Set metadata | adset_id, _fivetran_synced | name, status, targeting, optimization_goal, bid_amount |
| `facebook_ads.ad_history` | Ad metadata | ad_id, _fivetran_synced | name, status, creative_id |
| `facebook_ads.creative_history` | Creative metadata | creative_id, _fivetran_synced | name, title, body, call_to_action_type, object_type |

---

## Data Source Tables (hubspot Schema)

The following tables are defined in `AdCampaignDataSchema.sql` within the `hubspot` schema:

### Contact & Company Tables

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `hubspot.contact` | Contact records with CRM properties | contact_id | email, lifecycle_stage, lead_status, owner_id, associated_company_id, total_revenue, hs_analytics_source |
| `hubspot.company` | Company/account records | company_id | name, domain, industry, lifecycle_stage, owner_id, annual_revenue, num_associated_contacts, num_associated_deals |
| `hubspot.contact_list` | Contact list definitions | contact_list_id | name, dynamic, list_size |
| `hubspot.contact_list_member` | Contact-to-list associations | contact_id, contact_list_id | added_at |
| `hubspot.owner` | Owner/sales rep records | owner_id | email, first_name, last_name, type |

### Deal Pipeline Tables

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `hubspot.deal` | Deal/opportunity records | deal_id | deal_name, pipeline_id, pipeline_stage_id, amount, owner_id, associated_company_id, is_closed, is_closed_won |
| `hubspot.deal_pipeline` | Pipeline definitions | pipeline_id | label, display_order |
| `hubspot.deal_stage` | Stage definitions per pipeline | stage_id, pipeline_id | label, probability, is_closed, is_closed_won |
| `hubspot.deal_stage_history` | Deal stage transition history | deal_id, stage_id, timestamp | source, source_id |

### Email Campaign Tables

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `hubspot.email_campaign` | Marketing email campaign definitions | campaign_id | name, subject, type, num_included, num_queued |
| `hubspot.email_event` | All email events (sends, opens, clicks, etc.) | event_id | email_campaign_id, recipient, type, created_at, device_type |
| `hubspot.email_event_sent` | Sent email details | event_id | from_email, subject |
| `hubspot.email_event_open` | Open event details | event_id | browser, ip_address, duration |
| `hubspot.email_event_click` | Click event details | event_id | url, browser |
| `hubspot.email_event_bounce` | Bounce event details | event_id | category, response, status |

### Engagement Tables

| Table Name | Description | Primary Key | Key Columns |
|------------|-------------|-------------|-------------|
| `hubspot.engagement` | Base engagement records | engagement_id | type (CALL, MEETING, EMAIL, NOTE, TASK), timestamp, owner_id |
| `hubspot.engagement_contact` | Contact-engagement associations | engagement_id, contact_id | - |
| `hubspot.engagement_company` | Company-engagement associations | engagement_id, company_id | - |
| `hubspot.engagement_deal` | Deal-engagement associations | engagement_id, deal_id | - |
| `hubspot.engagement_call` | Call engagement details | engagement_id | disposition, duration_milliseconds, status, recording_url |
| `hubspot.engagement_meeting` | Meeting engagement details | engagement_id | title, start_time, end_time, meeting_outcome |
| `hubspot.engagement_email` | Email engagement details | engagement_id | subject, from_email, to_email |
| `hubspot.engagement_note` | Note engagement details | engagement_id | body |
| `hubspot.engagement_task` | Task engagement details | engagement_id | subject, status, task_type, priority, completion_date |

### HubSpot Column Data Types Reference

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `*_id` | BIGINT | Entity identifiers (contact_id, company_id, deal_id, etc.) |
| `email` | NVARCHAR(255) | Email addresses |
| `lifecycle_stage` | NVARCHAR(100) | Contact/Company lifecycle (subscriber, lead, mql, sql, opportunity, customer) |
| `amount` | DECIMAL(18,2) | Deal monetary values |
| `hs_*` | Various | HubSpot analytics and system properties |
| `duration_milliseconds` | BIGINT | Call duration in milliseconds |
| `probability` | DECIMAL(5,2) | Deal stage probability percentage |
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

## Facebook Ads View Definitions

All Facebook Ads views are defined in the `dbo` schema and reference tables from the `facebook_ads` schema.

### Account Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_facebook_account_performance` | Daily account metrics | basic_ad, account_history | Reach, frequency, all KPIs |
| `vw_facebook_account_performance_summary` | Aggregated account stats | (via vw_facebook_account_performance) | 30-day comparison |

### Campaign Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_facebook_campaign_performance` | Daily campaign metrics | basic_ad, campaign_history, account_history | Objective, budget utilization |
| `vw_facebook_campaign_trend_analysis` | Trend analysis | (via vw_facebook_campaign_performance) | Moving averages, WoW comparisons |
| `vw_facebook_campaign_performance_summary` | Aggregated campaign stats | (via vw_facebook_campaign_performance) | Period summary |
| `vw_facebook_campaign_objective_analysis` | Objective comparison | (via summary) | Performance by objective |

### Ad Set Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_facebook_adset_performance` | Daily ad set metrics | basic_ad, adset_history, campaign_history | Targeting context |
| `vw_facebook_adset_drilldown` | Hierarchical drill-down | (via vw_facebook_adset_performance) | Targeting effectiveness |
| `vw_facebook_adset_performance_summary` | Aggregated ad set stats | (via vw_facebook_adset_performance) | Period comparison |
| `vw_facebook_adset_optimization_goal_analysis` | Goal analysis | (via drilldown) | Performance by optimization goal |

### Ad Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_facebook_ad_performance` | Daily ad metrics | basic_ad, ad_history, creative_history | Creative elements, video metrics |
| `vw_facebook_ad_creative_effectiveness` | Creative analysis | (via vw_facebook_ad_performance) | Performance tiers, suggestions |
| `vw_facebook_ad_creative_type_comparison` | Type comparison | (via effectiveness) | Image vs video vs carousel |
| `vw_facebook_ad_cta_analysis` | CTA analysis | (via effectiveness) | Performance by call-to-action |

### Insights Views (Demographics & Placements)

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_facebook_ad_insights_demographics` | Age/gender breakdown | basic_ad | Demographic performance |
| `vw_facebook_ad_insights_placements` | Placement breakdown | basic_ad | Platform and position performance |
| `vw_facebook_demographic_summary` | Demographic summary | (via demographics) | Audience optimization |
| `vw_facebook_placement_summary` | Placement summary | (via placements) | Placement recommendations |
| `vw_facebook_device_performance` | Device breakdown | (via placements) | Mobile vs desktop |
| `vw_facebook_age_gender_matrix` | Cross-tabulation | (via demographics) | Heatmap visualization |

---

## HubSpot View Definitions

All HubSpot views are defined in the `dbo` schema and reference tables from the `hubspot` schema.

### Contact Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_hubspot_contact_performance` | Contact metrics & engagement | contact, owner, company, engagement_contact, engagement | Lifecycle stage, engagement tracking, revenue attribution |
| `vw_hubspot_contact_lifecycle_funnel` | Funnel analysis by stage | contact | Stage distribution, conversion metrics |
| `vw_hubspot_contact_source_performance` | Source attribution | contact | Acquisition source analysis, conversion rates |
| `vw_hubspot_contact_owner_performance` | Owner/rep metrics | contact, owner | Owner productivity, contact quality |

### Company Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_hubspot_company_performance` | Company/account metrics | company, owner, contact, deal, engagement_company, engagement | Account health, lifetime value, deal metrics |
| `vw_hubspot_company_industry_analysis` | Industry segmentation | company | Industry-level aggregations |
| `vw_hubspot_company_geography_analysis` | Geographic analysis | company | Location-based metrics |
| `vw_hubspot_company_owner_performance` | Owner account metrics | company, owner | Account ownership productivity |

### Deal Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_hubspot_deal_performance` | Deal pipeline metrics | deal, deal_pipeline, deal_stage, owner, company, contact, engagement_deal | Pipeline analysis, velocity, health indicators |
| `vw_hubspot_deal_pipeline_summary` | Pipeline stage summary | deal, deal_pipeline, deal_stage | Stage distribution, weighted values |
| `vw_hubspot_deal_stage_conversion` | Stage conversion analysis | deal_stage_history, deal_stage, deal_pipeline | Transition metrics, bottleneck identification |
| `vw_hubspot_deal_owner_performance` | Sales rep performance | deal, owner | Win rates, revenue, velocity |
| `vw_hubspot_deal_forecast` | Sales forecasting | deal, deal_stage, owner | Weighted pipeline by period |

### Email Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_hubspot_email_performance` | Email campaign metrics | email_campaign, email_event | Open/click rates, deliverability, device breakdown |
| `vw_hubspot_email_daily_metrics` | Daily email trends | email_event, email_campaign | Time series analysis |
| `vw_hubspot_email_bounce_analysis` | Bounce analysis | email_event, email_event_bounce, email_campaign | Bounce categories, deliverability issues |
| `vw_hubspot_email_link_performance` | Link click analysis | email_event, email_event_click, email_campaign | URL-level engagement |
| `vw_hubspot_email_engagement_by_time` | Time pattern analysis | email_event | Hour/day engagement patterns |
| `vw_hubspot_email_recipient_engagement` | Recipient engagement | email_event | Individual engagement history |

### Engagement Level Views

| View Name | Purpose | Schema Tables Used | Key Features |
|-----------|---------|-------------------|--------------|
| `vw_hubspot_engagement_performance` | All engagement details | engagement, owner, engagement_call, engagement_meeting, engagement_email, engagement_task | Cross-channel metrics, call/meeting details |
| `vw_hubspot_engagement_daily_summary` | Daily engagement summary | engagement, engagement_call, engagement_meeting, engagement_task, engagement_contact, engagement_company, engagement_deal | Trend analysis, type breakdown |
| `vw_hubspot_engagement_owner_summary` | Owner engagement metrics | engagement, owner, engagement_call, engagement_meeting, engagement_task | Productivity tracking |
| `vw_hubspot_engagement_type_analysis` | Engagement type analysis | engagement, engagement_contact, engagement_company, engagement_deal | Type distribution, effectiveness |
| `vw_hubspot_call_analysis` | Call engagement analysis | engagement, engagement_call, owner, engagement_contact, engagement_company | Call outcomes, duration, patterns |
| `vw_hubspot_meeting_analysis` | Meeting engagement analysis | engagement, engagement_meeting, owner, engagement_contact, engagement_company, engagement_deal | Meeting outcomes, completion rates |

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

## Facebook Ads Metric Definitions

### Core Metrics

| Metric | Definition | Formula |
|--------|------------|---------|
| **Spend** | Total cost/spend for ads | Direct from source (in account currency) |
| **Impressions** | Number of times ads were shown | Direct from source |
| **Clicks** | Number of clicks on ads | Direct from source |
| **Reach** | Unique users who saw the ad | Direct from source |
| **Actions** | Number of conversion actions taken | Direct from source |
| **Action Value** | Total value of conversion actions | Direct from source |

### Calculated KPIs

| KPI | Definition | Formula | Good Benchmark |
|-----|------------|---------|----------------|
| **CTR** | Click-through rate | `(Clicks / Impressions) × 100` | >1% |
| **Unique CTR** | Click rate based on reach | `(Unique Clicks / Reach) × 100` | >2% |
| **CPC** | Cost per click | `Spend / Clicks` | Varies by objective |
| **CPM** | Cost per 1,000 impressions | `(Spend / Impressions) × 1000` | $5-15 |
| **CPP** | Cost per 1,000 people reached | `(Spend / Reach) × 1000` | $8-20 |
| **Frequency** | Avg impressions per user | `Impressions / Reach` | 1.5-3 (avoid >8) |
| **Cost Per Action** | Cost per result | `Spend / Actions` | Varies by action type |
| **ROAS** | Return on ad spend | `Action Value / Spend` | >3:1 |

### Facebook-Specific Metrics

| Metric | Definition |
|--------|------------|
| **Link Clicks** | Clicks to destination URL |
| **Link CTR** | Link clicks / Impressions |
| **Video Views 25%** | Views reaching 25% completion |
| **Video Views 100%** | Views completing full video |
| **Video Completion Rate** | 100% views / 25% views |

---

## HubSpot Metric Definitions

### Contact Metrics

| Metric | Definition | Formula/Source |
|--------|------------|----------------|
| **Lifecycle Stage** | Contact's position in marketing/sales funnel | subscriber → lead → MQL → SQL → opportunity → customer |
| **Total Engagements** | Number of engagement activities with contact | Count of associated engagements |
| **Engagement Velocity** | Engagement rate over time | Total engagements / Months since created |
| **Contact Age** | Days since contact was created | DATEDIFF(created_at, today) |
| **Days Since Last Activity** | Time since last engagement | DATEDIFF(last_activity_date, today) |

### Deal Metrics

| KPI | Definition | Formula | Good Benchmark |
|-----|------------|---------|----------------|
| **Win Rate** | Percentage of closed deals that were won | `Won Deals / Total Closed Deals × 100` | >25% |
| **Pipeline Value** | Total value of open deals | Sum of open deal amounts | Varies |
| **Weighted Pipeline** | Probability-adjusted pipeline value | `Sum(Amount × Stage Probability)` | Varies |
| **Days to Close** | Average time to close won deals | Average of days_to_close for won deals | <60 days |
| **Average Deal Size** | Mean value of won deals | `Total Won Revenue / Won Deals` | Varies |
| **Deal Velocity** | Speed of deals through pipeline | `Weighted Pipeline / Days in Pipeline` | Higher is better |

### Email Metrics

| Metric | Definition | Formula | Good Benchmark |
|--------|------------|---------|----------------|
| **Delivery Rate** | Percentage of emails successfully delivered | `Delivered / Sent × 100` | >95% |
| **Unique Open Rate** | Percentage of recipients who opened | `Unique Opens / Delivered × 100` | >20% |
| **Unique Click Rate** | Percentage of recipients who clicked | `Unique Clicks / Delivered × 100` | >3% |
| **Click-to-Open Rate** | Clicks relative to opens | `Unique Clicks / Unique Opens × 100` | >10% |
| **Bounce Rate** | Percentage of emails that bounced | `Bounces / Sent × 100` | <2% |
| **Unsubscribe Rate** | Percentage who unsubscribed | `Unsubscribes / Delivered × 100` | <0.5% |
| **Spam Complaint Rate** | Percentage who marked as spam | `Spam Reports / Delivered × 100` | <0.01% |

### Engagement Metrics

| Metric | Definition | Source |
|--------|------------|--------|
| **Total Calls** | Number of call engagements | engagement.type = 'CALL' |
| **Total Meetings** | Number of meeting engagements | engagement.type = 'MEETING' |
| **Total Emails (CRM)** | Number of CRM email engagements | engagement.type = 'EMAIL' |
| **Call Duration** | Time spent on calls | engagement_call.duration_milliseconds |
| **Meeting Completion Rate** | Percentage of meetings completed | `Completed Meetings / Total Meetings × 100` |
| **Task Completion Rate** | Percentage of tasks completed | `Completed Tasks / Total Tasks × 100` |

### Account Health Indicators

| Status | Definition | Criteria |
|--------|------------|----------|
| **Highly Active** | Strong engagement and active deals | Engagements in last 30 days AND open deals |
| **Active** | Recent engagement | Engagements in last 30 days |
| **Warm** | Moderate engagement | Engagements in last 90 days |
| **Cold** | Low engagement | Engagements exist but none in 90 days |
| **No Engagement** | No tracked activities | Zero engagements |

### Deal Health Indicators

| Status | Definition | Criteria |
|--------|------------|----------|
| **Healthy** | Active deal with recent engagement | Last engagement within 7 days |
| **Needs Attention** | Deal engagement slowing | Last engagement 8-14 days ago |
| **At Risk** | Deal may be stalling | Last engagement 15-30 days ago |
| **Stale** | Deal likely dead | Last engagement >30 days ago |
| **No Engagement** | No activities logged | Zero engagements on deal |

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

### Google Ads Schema
1. **Database Configuration**: Azure SQL Database settings and configurations
2. **Schema Creation**: `google_ads` schema for all Google Ads tables
3. **Stats Tables**: Daily metric tables (account_stats, campaign_stats, ad_group_stats, ad_stats, keyword_stats)
4. **History Tables**: Entity metadata tables with change tracking (account_history, campaign_history, ad_group_history, ad_history, ad_group_criterion_history)
5. **Indexes**: Optimized indexes for common query patterns

### Facebook Ads Schema
1. **Schema Creation**: `facebook_ads` schema for all Facebook Ads tables
2. **Stats Tables**: basic_ad (daily metrics with demographic and placement breakdowns)
3. **History Tables**: account_history, campaign_history, adset_history, ad_history, creative_history
4. **Indexes**: Optimized indexes for ad reporting queries

### HubSpot Schema
1. **Schema Creation**: `hubspot` schema for all HubSpot CRM tables
2. **Contact & Company Tables**: contact, company, contact_list, contact_list_member, owner
3. **Deal Pipeline Tables**: deal, deal_pipeline, deal_stage, deal_stage_history
4. **Email Campaign Tables**: email_campaign, email_event, email_event_sent, email_event_open, email_event_click, email_event_bounce
5. **Engagement Tables**: engagement, engagement_contact, engagement_company, engagement_deal, engagement_call, engagement_meeting, engagement_email, engagement_note, engagement_task
6. **Indexes**: Optimized indexes for CRM reporting queries

---

## Best Practices

### PowerBI Report Design

1. **Use Star Schema**: Connect all fact views to the date dimension
2. **Implement Row-Level Security**: Filter by account_id (Google Ads) or owner_id (HubSpot) for multi-tenant scenarios
3. **Create Calculation Groups**: For time intelligence (YoY, MoM, WoW)
4. **Use Bookmarks**: For report navigation between different analysis views
5. **Separate Google Ads and HubSpot Pages**: Create dedicated sections for each data source
6. **Build Cross-Platform Insights**: Create views that combine ad campaign data with CRM conversion data

### Performance Optimization

1. **Use Aggregated Views**: For dashboard cards and KPIs
2. **Filter at Query Level**: Apply date filters in SQL, not just in PowerBI
3. **Limit Data Volume**: Only import necessary date ranges
4. **Use DirectQuery**: For real-time needs; Import mode for performance
5. **Pre-aggregate HubSpot Engagement Data**: Use daily summary views for trend analysis

### Common Slicer Combinations

| Slicer Set | Use Case | Data Source |
|------------|----------|-------------|
| Date Range + Account | Executive summary | Google Ads |
| Campaign + Date | Campaign analysis | Google Ads |
| Ad Group + Campaign + Date | Drill-down analysis | Google Ads |
| Keyword Match Type + Campaign | Keyword optimization | Google Ads |
| Ad Type + Campaign | Ad creative analysis | Google Ads |
| Date Range + Owner | Sales rep performance | HubSpot |
| Lifecycle Stage + Owner | Pipeline analysis | HubSpot |
| Pipeline + Stage + Date | Deal funnel | HubSpot |
| Email Campaign + Date | Email performance | HubSpot |
| Engagement Type + Owner + Date | Activity analysis | HubSpot |

### HubSpot-Specific Recommendations

1. **Monitor Deal Health Daily**: Use `vw_hubspot_deal_performance` health indicators
2. **Track Engagement Velocity**: Early warning for stalling deals
3. **Review Lifecycle Stage Distribution**: Weekly funnel health check
4. **Email Deliverability Monitoring**: Alert on bounce rates >2%
5. **Owner Performance Reviews**: Weekly activity and outcome comparisons

---

## Query Files Reference

### Google Ads Queries
- `sql/queries/dashboard_queries.sql` - Executive dashboard, daily trends, campaign matrix, budget pacing, conversion funnel
- `sql/queries/time_period_analysis.sql` - Time-based analysis queries

### Facebook Ads Queries
- `sql/queries/facebook_ads_dashboard_queries.sql` - Executive metrics, daily trends, campaign matrix, ad set targeting, creative performance, demographics, placements

### HubSpot Queries
- `sql/queries/hubspot_dashboard_queries.sql` - Executive summary, pipeline health, deals at risk, sales forecast, contact funnel, engagement trends, email campaigns, owner leaderboard, company insights, source attribution

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Initial | Initial data model creation (Google Ads) |
| 2.0 | Previous | Added HubSpot CRM schema and views for contacts, companies, deals, emails, and engagements |
| 3.0 | Current | Added Facebook Ads schema and views for accounts, campaigns, ad sets, ads, and insights with demographic/placement breakdowns |
