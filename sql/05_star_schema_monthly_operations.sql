/* ============================================================
   05_star_schema_monthly_operations.sql
   Purpose : Build the second, independent star-schema branch
             covering long-run monthly operations (Jan 2015 -
             May 2026), filtered to the FHV - High Volume
             license class, for trend/forecast analysis.
   Input   : dbo.data_reports_monthly (raw monthly TLC report,
             all license classes, text-typed columns)
   Output  : dbo.Fact_Monthly_Operations, dbo.Dim_Month
   Note    : This branch has a different grain (monthly) than
             fact_trips (trip-level) and does NOT share a
             relationship with it or with Dim_Date/Dim_Hour.
   ============================================================ */

USE fhvhv_analysis;
GO

/* ---- Step 1: Confirm the exact license-class label to filter on ---- */
SELECT DISTINCT License_Class FROM dbo.data_reports_monthly;
/* Confirms the label used below: 'FHV - High Volume' */
GO

/* ---- Step 2: Create the typed monthly fact table ---- */
CREATE TABLE dbo.Fact_Monthly_Operations
(
    Month_Year                      DATE NOT NULL,
    License_Class                   NVARCHAR(100) NOT NULL,
    Trips_Per_Day                   INT NULL,
    Farebox_Per_Day                 DECIMAL(18,2) NULL,
    Unique_Drivers                  INT NULL,
    Unique_Vehicles                 INT NULL,
    Vehicles_Per_Day                DECIMAL(18,2) NULL,
    Avg_Days_Vehicles_On_Road       DECIMAL(18,2) NULL,
    Avg_Hours_Per_Day_Per_Vehicle   DECIMAL(18,2) NULL,
    Avg_Days_Drivers_On_Road        DECIMAL(18,2) NULL,
    Avg_Hours_Per_Day_Per_Driver    DECIMAL(18,2) NULL,
    Avg_Minutes_Per_Trip            DECIMAL(18,2) NULL,
    Percent_Trips_Paid_Credit_Card  DECIMAL(18,4) NULL,
    Trips_Per_Day_Shared            DECIMAL(18,2) NULL
);
GO

/* ---- Step 3: Insert FHV - High Volume rows with safe conversion ---- */
INSERT INTO dbo.Fact_Monthly_Operations
(
    Month_Year, License_Class, Trips_Per_Day, Farebox_Per_Day, Unique_Drivers,
    Unique_Vehicles, Vehicles_Per_Day, Avg_Days_Vehicles_On_Road,
    Avg_Hours_Per_Day_Per_Vehicle, Avg_Days_Drivers_On_Road,
    Avg_Hours_Per_Day_Per_Driver, Avg_Minutes_Per_Trip,
    Percent_Trips_Paid_Credit_Card, Trips_Per_Day_Shared
)
SELECT
    TRY_CONVERT(DATE, [Month_Year] + '-01') AS Month_Year,
    [License_Class],
    TRY_CONVERT(INT, [Trips_Per_Day]),
    TRY_CONVERT(DECIMAL(18,2), [Farebox_Per_Day]),
    TRY_CONVERT(INT, [Unique_Drivers]),
    TRY_CONVERT(INT, [Unique_Vehicles]),
    TRY_CONVERT(DECIMAL(18,2), [Vehicles_Per_Day]),
    TRY_CONVERT(DECIMAL(18,2), [Avg_Days_Vehicles_On_Road]),
    TRY_CONVERT(DECIMAL(18,2), [Avg_Hours_Per_Day_Per_Vehicle]),
    TRY_CONVERT(DECIMAL(18,2), [Avg_Days_Drivers_On_Road]),
    TRY_CONVERT(DECIMAL(18,2), [Avg_Hours_Per_Day_Per_Driver]),
    TRY_CONVERT(DECIMAL(18,2), [Avg_Minutes_Per_Trip]),
    NULL,   -- populated in Step 5 below (needs %-stripping first)
    NULL    -- populated in Step 6 below (needs comma-stripping first)
FROM dbo.data_reports_monthly
WHERE [License_Class] = 'FHV - High Volume';
GO
/* Sample output: 137 rows inserted (Jan 2015 - May 2026, no gaps:
   11 full years x 12 + 5 months into 2026 = 137) */

/* ---- Step 4: Verify span and row count ---- */
SELECT MIN(Month_Year) AS First_Month, MAX(Month_Year) AS Last_Month, COUNT(*) AS Total_Rows
FROM dbo.Fact_Monthly_Operations;
/* Sample output: 2015-01-01, 2026-05-01, 137 */
GO

/* ---- Step 5: Fix Percent_Trips_Paid_Credit_Card ----
   IMPORTANT FINDING: the source column contains a literal '%'
   character (e.g. '79%') which TRY_CONVERT cannot parse, AND
   -- separately -- every row where License_Class = 'FHV - High
   Volume' has '-' (no data) for this field. TLC does not appear
   to publish this metric for the FHV-HV class (card-only
   platforms by design). This column will remain 100% NULL for
   this table - that is a genuine source-data limitation, not a
   bug, and the field is excluded from all Power BI visuals. */
UPDATE f
SET f.Percent_Trips_Paid_Credit_Card =
    TRY_CONVERT(DECIMAL(18,4), REPLACE(s.Percent_of_Trips_Paid_with_Credit_Card, '%', '')) / 100
FROM dbo.Fact_Monthly_Operations f
JOIN dbo.data_reports_monthly s
    ON TRY_CONVERT(DATE, s.Month_Year + '-01') = f.Month_Year
   AND s.License_Class = 'FHV - High Volume';
GO

SELECT COUNT(*) AS total_rows, COUNT(Percent_Trips_Paid_Credit_Card) AS non_null_rows
FROM dbo.Fact_Monthly_Operations;
/* Sample output: 137 / 0 - confirmed: source has no data for
   this license class (see note above); NOT a conversion bug. */

/* Confirms the above conclusion directly against the source: */
SELECT COUNT(*) AS expected_non_null
FROM dbo.data_reports_monthly
WHERE License_Class = 'FHV - High Volume'
  AND Percent_of_Trips_Paid_with_Credit_Card <> '-';
/* Sample output: 0 */
GO

/* ---- Step 6: Fix Trips_Per_Day_Shared ----
   IMPORTANT FINDING: the source column contains thousands
   separators (e.g. '7,191') which TRY_CONVERT cannot parse
   without stripping the comma first. Unlike credit-card %,
   this field DOES have real data once the comma is removed. */
UPDATE f
SET f.Trips_Per_Day_Shared =
    TRY_CONVERT(DECIMAL(18,2), REPLACE(s.Trips_Per_Day_Shared, ',', ''))
FROM dbo.Fact_Monthly_Operations f
JOIN dbo.data_reports_monthly s
    ON TRY_CONVERT(DATE, s.Month_Year + '-01') = f.Month_Year
   AND s.License_Class = 'FHV - High Volume';
GO

SELECT AVG(Trips_Per_Day) AS avg_total, AVG(Trips_Per_Day_Shared) AS avg_shared
FROM dbo.Fact_Monthly_Operations;
/* Sample output: avg_total ~511,891, avg_shared ~46,661
   (~9.1% shared-trip rate overall - plausible, real result) */
GO

/* Note: Trips_Per_Day_Shared is NULL for Jan 2015 - May 2017
   (shared-ride feature not yet tracked) and briefly in
   2020-2021 (COVID-related suspension of shared rides). These
   gaps are genuine and should be noted in the report, not
   treated as errors. */

/* ---- Step 7: Build Dim_Month (monthly grain, matches
   Fact_Monthly_Operations exactly: Jan 2015 - May 2026) ---- */
WITH MonthSeries AS (
    SELECT CAST('2015-01-01' AS DATE) AS month_key
    UNION ALL
    SELECT DATEADD(MONTH, 1, month_key)
    FROM MonthSeries
    WHERE month_key < '2026-05-01'
)
SELECT
    month_key,
    DATEPART(YEAR, month_key) AS year_num,
    DATEPART(MONTH, month_key) AS month_num,
    DATENAME(MONTH, month_key) AS month_name,
    CAST(DATENAME(MONTH, month_key) + ' ' + CAST(DATEPART(YEAR, month_key) AS VARCHAR(4)) AS VARCHAR(20)) AS month_year_label,
    CASE WHEN DATEPART(MONTH, month_key) IN (12,1,2) THEN 'Winter'
         WHEN DATEPART(MONTH, month_key) IN (3,4,5) THEN 'Spring'
         WHEN DATEPART(MONTH, month_key) IN (6,7,8) THEN 'Summer'
         ELSE 'Fall' END AS season
INTO dbo.Dim_Month
FROM MonthSeries
OPTION (MAXRECURSION 0);
GO

/* SELECT ... INTO always creates nullable columns regardless of
   actual data, so the PK constraint must tighten the column
   to NOT NULL first: */
ALTER TABLE dbo.Dim_Month ALTER COLUMN month_key DATE NOT NULL;
GO
ALTER TABLE dbo.Dim_Month ADD CONSTRAINT PK_Dim_Month PRIMARY KEY (month_key);
GO

/* ---- Step 8: Verify Dim_Month and the join to Fact_Monthly_Operations ---- */
SELECT COUNT(*) AS month_row_count FROM dbo.Dim_Month;
/* Sample output: 137 */

SELECT COUNT(*) AS matched_rows
FROM dbo.Fact_Monthly_Operations f
JOIN dbo.Dim_Month d ON f.Month_Year = d.month_key;
/* Sample output: 137 (every fact row matches, none orphaned) */
GO
