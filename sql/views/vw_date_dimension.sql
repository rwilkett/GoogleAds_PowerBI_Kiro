/*
================================================================================
VIEW: vw_date_dimension
DESCRIPTION: Date dimension table for time-based filtering and period comparisons
             in the Google Ads PowerBI dashboard.
FIVETRAN SCHEMA: This view creates a date spine based on the date range found
                 in Google Ads data.
================================================================================
*/

CREATE OR ALTER VIEW [dbo].[vw_date_dimension]
AS
WITH DateRange AS (
    -- Get the min and max dates from Google Ads data
    SELECT 
        MIN(date) AS min_date,
        MAX(date) AS max_date
    FROM google_ads.account_stats
),
DateSpine AS (
    -- Generate all dates between min and max
    SELECT 
        DATEADD(DAY, n.number, dr.min_date) AS date_key
    FROM DateRange dr
    CROSS JOIN master.dbo.spt_values n
    WHERE n.type = 'P'
        AND n.number <= DATEDIFF(DAY, dr.min_date, dr.max_date)
)
SELECT 
    -- Primary key
    CONVERT(INT, FORMAT(ds.date_key, 'yyyyMMdd')) AS date_id,
    ds.date_key AS [date],
    
    -- Day attributes
    DATENAME(WEEKDAY, ds.date_key) AS day_name,
    DATEPART(WEEKDAY, ds.date_key) AS day_of_week,
    DATEPART(DAY, ds.date_key) AS day_of_month,
    DATEPART(DAYOFYEAR, ds.date_key) AS day_of_year,
    CASE 
        WHEN DATEPART(WEEKDAY, ds.date_key) IN (1, 7) THEN 0 
        ELSE 1 
    END AS is_weekday,
    
    -- Week attributes
    DATEPART(WEEK, ds.date_key) AS week_of_year,
    DATEPART(ISO_WEEK, ds.date_key) AS iso_week_of_year,
    DATEADD(DAY, 1 - DATEPART(WEEKDAY, ds.date_key), ds.date_key) AS week_start_date,
    DATEADD(DAY, 7 - DATEPART(WEEKDAY, ds.date_key), ds.date_key) AS week_end_date,
    
    -- Month attributes
    DATEPART(MONTH, ds.date_key) AS month_number,
    DATENAME(MONTH, ds.date_key) AS month_name,
    LEFT(DATENAME(MONTH, ds.date_key), 3) AS month_name_short,
    DATEFROMPARTS(YEAR(ds.date_key), MONTH(ds.date_key), 1) AS month_start_date,
    EOMONTH(ds.date_key) AS month_end_date,
    
    -- Quarter attributes
    DATEPART(QUARTER, ds.date_key) AS quarter_number,
    'Q' + CAST(DATEPART(QUARTER, ds.date_key) AS VARCHAR(1)) AS quarter_name,
    DATEFROMPARTS(YEAR(ds.date_key), (DATEPART(QUARTER, ds.date_key) - 1) * 3 + 1, 1) AS quarter_start_date,
    EOMONTH(DATEFROMPARTS(YEAR(ds.date_key), DATEPART(QUARTER, ds.date_key) * 3, 1)) AS quarter_end_date,
    
    -- Year attributes
    DATEPART(YEAR, ds.date_key) AS [year],
    DATEFROMPARTS(YEAR(ds.date_key), 1, 1) AS year_start_date,
    DATEFROMPARTS(YEAR(ds.date_key), 12, 31) AS year_end_date,
    
    -- Fiscal year (assuming calendar year = fiscal year; adjust offset as needed)
    DATEPART(YEAR, ds.date_key) AS fiscal_year,
    DATEPART(QUARTER, ds.date_key) AS fiscal_quarter,
    
    -- Period comparison helpers
    FORMAT(ds.date_key, 'yyyy-MM') AS year_month,
    FORMAT(ds.date_key, 'yyyy-Qq') AS year_quarter,
    CONVERT(VARCHAR(7), ds.date_key, 120) AS year_month_sort,
    
    -- Relative date flags (based on current date)
    CASE WHEN ds.date_key = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS is_today,
    CASE WHEN ds.date_key = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END AS is_yesterday,
    CASE WHEN ds.date_key >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) 
         AND ds.date_key < CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS is_last_7_days,
    CASE WHEN ds.date_key >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) 
         AND ds.date_key < CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS is_last_30_days,
    CASE WHEN YEAR(ds.date_key) = YEAR(GETDATE()) 
         AND MONTH(ds.date_key) = MONTH(GETDATE()) THEN 1 ELSE 0 END AS is_current_month,
    CASE WHEN YEAR(ds.date_key) = YEAR(DATEADD(MONTH, -1, GETDATE())) 
         AND MONTH(ds.date_key) = MONTH(DATEADD(MONTH, -1, GETDATE())) THEN 1 ELSE 0 END AS is_previous_month,
    CASE WHEN YEAR(ds.date_key) = YEAR(GETDATE()) THEN 1 ELSE 0 END AS is_current_year,
    CASE WHEN YEAR(ds.date_key) = YEAR(GETDATE()) - 1 THEN 1 ELSE 0 END AS is_previous_year,
    
    -- Days ago calculation
    DATEDIFF(DAY, ds.date_key, CAST(GETDATE() AS DATE)) AS days_ago
    
FROM DateSpine ds;
GO

-- Add description for the view
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Date dimension view for Google Ads PowerBI dashboard supporting time-based filtering and period comparisons.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'VIEW', @level1name = N'vw_date_dimension';
GO
