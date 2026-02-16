# Google Ads PowerBI Dashboard

A comprehensive PowerBI dashboard solution for analyzing Google Ads performance data stored in SQL Server within the `google_ads` schema.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [SQL Server Setup](#sql-server-setup)
- [PowerBI Connection Setup](#powerbi-connection-setup)
- [Dashboard Components](#dashboard-components)
- [Metric Definitions](#metric-definitions)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)

---

## Overview

This repository contains the database schema, SQL views, queries, and documentation for building a Google Ads analytics dashboard in PowerBI. The data model transforms raw Google Ads data into analysis-ready views with pre-calculated KPIs and performance metrics.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Google Ads  │────►│  Data Sync   │────►│  SQL Server  │
│     API      │     │  (ETL/ELT)   │     │  (google_ads │
└──────────────┘     └──────────────┘     │   schema)    │
                                          └──────┬───────┘
                                                 │
                                          ┌──────▼───────┐
                                          │  SQL Views   │
                                          │  (dbo schema)│
                                          └──────┬───────┘
                                                 │
                                          ┌──────▼───────┐
                                          │   PowerBI    │
                                          │  Dashboard   │
                                          └──────────────┘
```

---

## Features

- **Account-Level Analytics**: Overall account health, spend trends, and KPI tracking
- **Campaign Performance**: Budget pacing, trend analysis, and campaign comparison
- **Ad Group Drill-Down**: Hierarchical analysis with performance rankings
- **Keyword Analysis**: Quality score tracking, match type comparison, top performers
- **Ad Copy Effectiveness**: Ad strength correlation, creative performance insights
- **Time-Based Analysis**: Daily, weekly, monthly trends with period comparisons
- **Date Dimension**: Comprehensive date intelligence for flexible filtering

---

## Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| SQL Server | 2016+ | Database server |
| PowerBI Desktop | Latest | Report development |
| PowerBI Service | Pro/Premium | Report publishing (optional) |

### Required Access

- SQL Server database with `google_ads` schema
- Read access to google_ads schema tables
- Permission to create views in target database

### Schema Tables Required

The following tables must be present in the `google_ads` schema (defined in `AdCampaignDataSchema.sql`):

**Stats Tables (Daily Metrics):**
- `google_ads.account_stats`
- `google_ads.campaign_stats`
- `google_ads.ad_group_stats`
- `google_ads.ad_stats`
- `google_ads.keyword_stats`

**History Tables (Entity Attributes):**
- `google_ads.account_history`
- `google_ads.campaign_history`
- `google_ads.ad_group_history`
- `google_ads.ad_history`
- `google_ads.ad_group_criterion_history`

---

## Project Structure

```
GoogleAds_PowerBI_Kiro/
├── README.md                           # This file
├── AdCampaignDataSchema.sql            # Database and table schema definitions
├── docs/
│   └── data-model.md                   # Data model documentation
└── sql/
    ├── views/
    │   ├── vw_date_dimension.sql       # Date dimension view
    │   ├── vw_account_performance.sql  # Account-level metrics
    │   ├── vw_campaign_performance.sql # Campaign-level metrics
    │   ├── vw_ad_group_performance.sql # Ad group-level metrics
    │   ├── vw_keyword_performance.sql  # Keyword-level metrics
    │   └── vw_ad_performance.sql       # Ad-level metrics
    └── queries/
        ├── dashboard_queries.sql       # Executive dashboard queries
        └── time_period_analysis.sql    # WoW, MoM, YoY analysis queries
```

---

## SQL Server Setup

### Step 1: Create Database Schema

First, run the schema script to create the database and tables:

```bash
# Execute the schema script
sqlcmd -S your-server-name -d master -i AdCampaignDataSchema.sql
```

Or run in SQL Server Management Studio:
1. Open `AdCampaignDataSchema.sql`
2. Execute the script to create the database, schema, and tables

### Step 2: Verify Schema Tables

Confirm that the tables were created successfully:

```sql
-- Check for required tables
SELECT TABLE_SCHEMA, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'google_ads'
ORDER BY TABLE_NAME;
```

### Step 3: Create Views

Execute the SQL view scripts in the following order:

1. **Date Dimension** (depends on account_stats for date range)
   ```bash
   sql/views/vw_date_dimension.sql
   ```

2. **Account Performance** (depends on google_ads schema tables)
   ```bash
   sql/views/vw_account_performance.sql
   ```

3. **Campaign Performance** (depends on google_ads schema tables)
   ```bash
   sql/views/vw_campaign_performance.sql
   ```

4. **Ad Group Performance** (depends on google_ads schema tables)
   ```bash
   sql/views/vw_ad_group_performance.sql
   ```

5. **Keyword Performance** (depends on google_ads schema tables)
   ```bash
   sql/views/vw_keyword_performance.sql
   ```

6. **Ad Performance** (depends on google_ads schema tables)
   ```bash
   sql/views/vw_ad_performance.sql
   ```

### Step 4: Verify Views

```sql
-- Verify all views were created
SELECT TABLE_SCHEMA, TABLE_NAME 
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_NAME LIKE 'vw_%'
ORDER BY TABLE_NAME;

-- Test account view
SELECT TOP 10 * FROM [dbo].[vw_account_performance];

-- Test campaign view
SELECT TOP 10 * FROM [dbo].[vw_campaign_performance];
```

### Step 5: Grant Permissions (Optional)

If using a separate PowerBI service account:

```sql
-- Create a read-only role for PowerBI
CREATE ROLE PowerBI_Reader;

-- Grant SELECT on all views
GRANT SELECT ON SCHEMA::dbo TO PowerBI_Reader;

-- Add the PowerBI service account to the role
ALTER ROLE PowerBI_Reader ADD MEMBER [YourPowerBIServiceAccount];
```

---

## PowerBI Connection Setup

### Step 1: Open PowerBI Desktop

Launch PowerBI Desktop and create a new report.

### Step 2: Get Data from SQL Server

1. Click **Get Data** → **SQL Server**
2. Enter connection details:
   - **Server**: `your-server-name.database.windows.net` (or local server name)
   - **Database**: `your-database-name`
   - **Data Connectivity mode**: 
     - **Import** (recommended for most cases)
     - **DirectQuery** (for real-time data needs)

### Step 3: Select Tables/Views

In the Navigator, select the following views:

**Required Views:**
- `dbo.vw_date_dimension`
- `dbo.vw_account_performance`
- `dbo.vw_campaign_performance`

**Optional Views (based on analysis needs):**
- `dbo.vw_campaign_trend_analysis`
- `dbo.vw_campaign_performance_summary`
- `dbo.vw_ad_group_performance`
- `dbo.vw_ad_group_drilldown`
- `dbo.vw_keyword_performance`
- `dbo.vw_keyword_top_performers`
- `dbo.vw_ad_performance`
- `dbo.vw_ad_copy_effectiveness`

### Step 4: Create Relationships

In the **Model** view, create relationships:

| From Table | From Column | To Table | To Column | Cardinality |
|------------|-------------|----------|-----------|-------------|
| vw_account_performance | date_id | vw_date_dimension | date_id | Many to One |
| vw_campaign_performance | date_id | vw_date_dimension | date_id | Many to One |
| vw_campaign_performance | account_id | vw_account_performance | account_id | Many to One |
| vw_ad_group_performance | campaign_id | vw_campaign_performance | campaign_id | Many to One |

### Step 5: Configure Date Table

Mark the date dimension as a date table:

1. Select `vw_date_dimension` in Model view
2. Go to **Table tools** → **Mark as date table**
3. Select `date` as the date column

### Step 6: Apply Query Filters (Optional)

To limit data volume, apply filters in Power Query:

```m
// Example: Filter to last 90 days
let
    Source = Sql.Database("your-server", "your-database"),
    dbo_vw_account_performance = Source{[Schema="dbo",Item="vw_account_performance"]}[Data],
    FilteredRows = Table.SelectRows(dbo_vw_account_performance, 
        each [date] >= Date.AddDays(DateTime.Date(DateTime.LocalNow()), -90))
in
    FilteredRows
```

---

## Dashboard Components

### Recommended Report Pages

#### Page 1: Executive Summary
- **Cards**: Total Spend, Conversions, ROAS, CTR
- **Line Chart**: Daily spend/conversions trend
- **KPI Cards**: Period comparison (vs. previous month)

#### Page 2: Campaign Performance
- **Table**: Campaign performance matrix
- **Scatter Plot**: Performance quadrant (CVR vs ROAS)
- **Bar Chart**: Top campaigns by conversions

#### Page 3: Ad Group Analysis
- **Drill-down Matrix**: Account → Campaign → Ad Group hierarchy
- **Tree Map**: Spend distribution by ad group
- **Table**: Performance with rankings

#### Page 4: Keyword Analysis
- **Table**: Top keywords with quality scores
- **Donut Chart**: Match type distribution
- **Scatter Plot**: Quality score vs CPA

#### Page 5: Ad Creative Analysis
- **Table**: Ad performance with copy preview
- **Bar Chart**: Performance by ad strength
- **Comparison Chart**: RSA vs ETA performance

### Suggested Slicers

| Slicer | Field | Type |
|--------|-------|------|
| Date Range | vw_date_dimension[date] | Date range |
| Account | vw_account_performance[account_name] | Dropdown |
| Campaign | vw_campaign_performance[campaign_name] | Dropdown |
| Campaign Status | vw_campaign_performance[campaign_status] | Dropdown |
| Channel Type | vw_campaign_performance[advertising_channel_type] | Dropdown |

---

## Metric Definitions

### Key Performance Indicators

| Metric | Formula | Description |
|--------|---------|-------------|
| **CTR** | (Clicks ÷ Impressions) × 100 | Click-through rate |
| **CPC** | Spend ÷ Clicks | Cost per click |
| **Conversion Rate** | (Conversions ÷ Clicks) × 100 | Conversion rate |
| **CPA** | Spend ÷ Conversions | Cost per acquisition |
| **ROAS** | Conversions Value ÷ Spend | Return on ad spend |
| **CPM** | (Spend ÷ Impressions) × 1000 | Cost per thousand impressions |

### DAX Measures (Examples)

```dax
// Total Spend
Total Spend = SUM(vw_account_performance[spend])

// CTR Percentage
CTR % = 
DIVIDE(
    SUM(vw_account_performance[clicks]),
    SUM(vw_account_performance[impressions]),
    0
) * 100

// ROAS
ROAS = 
DIVIDE(
    SUM(vw_account_performance[conversions_value]),
    SUM(vw_account_performance[spend]),
    0
)

// Previous Period Spend
Previous Period Spend = 
CALCULATE(
    [Total Spend],
    DATEADD(vw_date_dimension[date], -30, DAY)
)

// Spend Change %
Spend Change % = 
DIVIDE(
    [Total Spend] - [Previous Period Spend],
    [Previous Period Spend],
    0
) * 100
```

---

## Troubleshooting

### Common Issues

#### Issue: Views fail to create
**Solution**: Ensure the google_ads schema and tables exist. Run `AdCampaignDataSchema.sql` first to create the schema structure. If using a data sync tool, verify the schema name matches `google_ads`.

```sql
-- Find your actual schema name
SELECT DISTINCT TABLE_SCHEMA 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME LIKE '%stats';
```

#### Issue: No data in views
**Solution**: Verify data has been loaded into the schema tables:

```sql
SELECT COUNT(*) FROM google_ads.account_stats;
SELECT MIN(date), MAX(date) FROM google_ads.account_stats;
```

#### Issue: Slow PowerBI performance
**Solutions**:
1. Apply date filters in Power Query
2. Use Import mode instead of DirectQuery
3. Use summary views instead of detailed views
4. Enable query folding

#### Issue: Missing columns in views
**Solution**: Some Fivetran columns may not be present depending on connector settings. Modify views to handle missing columns:

```sql
-- Use COALESCE for potentially missing columns
COALESCE(column_name, 0) AS column_name
```

### Connection Error Codes

| Error | Solution |
|-------|----------|
| Login failed | Verify SQL Server credentials |
| Cannot connect to server | Check firewall rules, enable Azure services |
| Invalid object name | Run view creation scripts |
| Permission denied | Grant SELECT permissions on views |

---

## Documentation

- [Data Model Documentation](docs/data-model.md) - Detailed entity relationships, metric definitions, and best practices

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## License

This project is provided as-is for educational and business purposes.

---

## Support

For questions or issues:
1. Check the troubleshooting section
2. Review the data model documentation
3. Open an issue in this repository