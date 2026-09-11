/* ============================================================
   02_clean_typed_table.sql
   Purpose : Convert the all-NVARCHAR staging table into a
             properly typed table. TRY_CAST/TRY_CONVERT is used
             instead of CAST/CONVERT so that a handful of
             malformed values return NULL rather than aborting
             the entire 19.6M-row insert.
   Input   : dbo.fhvhv_2024_01   (staging, from script 01)
   Output  : dbo.fhvhv_2024_01_clean (typed)
   ============================================================ */

USE fhvhv_analysis;
GO

/* ---- Step 1: Create the typed table ---- */
CREATE TABLE dbo.fhvhv_2024_01_clean (
    hvfhs_license_num      NVARCHAR(10),
    dispatching_base_num   NVARCHAR(10),
    originating_base_num   NVARCHAR(10),
    request_datetime       DATETIME2,
    on_scene_datetime      DATETIME2,
    pickup_datetime        DATETIME2,
    dropoff_datetime       DATETIME2,
    PULocationID           INT,
    DOLocationID           INT,
    trip_miles             DECIMAL(10,2),
    trip_time              INT,
    base_passenger_fare    DECIMAL(10,2),
    tolls                  DECIMAL(10,2),
    bcf                    DECIMAL(10,2),
    sales_tax              DECIMAL(10,2),
    congestion_surcharge   DECIMAL(10,2),
    airport_fee            DECIMAL(10,2),
    tips                   DECIMAL(10,2),
    driver_pay             DECIMAL(10,2),
    shared_request_flag    CHAR(1),
    shared_match_flag      CHAR(1),
    access_a_ride_flag     CHAR(1),
    wav_request_flag       CHAR(1),
    wav_match_flag         CHAR(1)
);
GO

/* ---- Step 2: Populate with safe conversion ---- */
INSERT INTO dbo.fhvhv_2024_01_clean
SELECT
    hvfhs_license_num,
    dispatching_base_num,
    originating_base_num,
    TRY_CONVERT(DATETIME2, request_datetime),
    TRY_CONVERT(DATETIME2, on_scene_datetime),
    TRY_CONVERT(DATETIME2, pickup_datetime),
    TRY_CONVERT(DATETIME2, dropoff_datetime),
    TRY_CAST(PULocationID AS INT),
    TRY_CAST(DOLocationID AS INT),
    TRY_CAST(trip_miles AS DECIMAL(10,2)),
    TRY_CAST(trip_time AS INT),
    TRY_CAST(base_passenger_fare AS DECIMAL(10,2)),
    TRY_CAST(tolls AS DECIMAL(10,2)),
    TRY_CAST(bcf AS DECIMAL(10,2)),
    TRY_CAST(sales_tax AS DECIMAL(10,2)),
    TRY_CAST(congestion_surcharge AS DECIMAL(10,2)),
    TRY_CAST(airport_fee AS DECIMAL(10,2)),
    TRY_CAST(tips AS DECIMAL(10,2)),
    TRY_CAST(driver_pay AS DECIMAL(10,2)),
    shared_request_flag,
    shared_match_flag,
    access_a_ride_flag,
    wav_request_flag,
    wav_match_flag
FROM dbo.fhvhv_2024_01;
GO

/* ---- Step 3: Verify row counts match (nothing dropped/duplicated) ---- */
SELECT COUNT(*) AS staging_rows FROM dbo.fhvhv_2024_01;
SELECT COUNT(*) AS clean_rows   FROM dbo.fhvhv_2024_01_clean;
/* Sample output: staging_rows = 19663930, clean_rows = 19663930 (exact match) */
GO

/* ---- Step 4: Verify conversion quality per column ----
   Counts how many rows produced NULL after conversion. Zero
   NULLs = clean conversion; a non-zero count needs the raw
   values inspected before trusting the column. */
SELECT
    SUM(CASE WHEN trip_miles           IS NULL THEN 1 ELSE 0 END) AS null_miles,
    SUM(CASE WHEN pickup_datetime      IS NULL THEN 1 ELSE 0 END) AS null_pickup,
    SUM(CASE WHEN dropoff_datetime     IS NULL THEN 1 ELSE 0 END) AS null_dropoff,
    SUM(CASE WHEN base_passenger_fare  IS NULL THEN 1 ELSE 0 END) AS null_fare,
    SUM(CASE WHEN driver_pay           IS NULL THEN 1 ELSE 0 END) AS null_driver_pay
FROM dbo.fhvhv_2024_01_clean;
/* Sample output: all 0 */

SELECT
    SUM(CASE WHEN request_datetime  IS NULL THEN 1 ELSE 0 END) AS null_request_dt,
    SUM(CASE WHEN on_scene_datetime IS NULL THEN 1 ELSE 0 END) AS null_on_scene_dt,
    SUM(CASE WHEN trip_time         IS NULL THEN 1 ELSE 0 END) AS null_trip_time,
    SUM(CASE WHEN PULocationID      IS NULL THEN 1 ELSE 0 END) AS null_pu_loc,
    SUM(CASE WHEN DOLocationID      IS NULL THEN 1 ELSE 0 END) AS null_do_loc,
    SUM(CASE WHEN tolls                 IS NULL THEN 1 ELSE 0 END) AS null_tolls,
    SUM(CASE WHEN bcf                   IS NULL THEN 1 ELSE 0 END) AS null_bcf,
    SUM(CASE WHEN sales_tax             IS NULL THEN 1 ELSE 0 END) AS null_sales_tax,
    SUM(CASE WHEN congestion_surcharge  IS NULL THEN 1 ELSE 0 END) AS null_congestion,
    SUM(CASE WHEN airport_fee           IS NULL THEN 1 ELSE 0 END) AS null_airport_fee,
    SUM(CASE WHEN tips                  IS NULL THEN 1 ELSE 0 END) AS null_tips
FROM dbo.fhvhv_2024_01_clean;
/* Sample output: all 0 except null_on_scene_dt = 5,218,737
   (expected - not every FHVHV trip records an on-scene time;
   this is a legitimate data gap, not a conversion failure) */
GO

/* ---- Step 5: Spot-check a column with a manual bad-value scan ----
   Confirms TRY_CAST failures (if any) are real malformed values,
   not a systemic conversion bug. */
SELECT DISTINCT trip_miles
FROM dbo.fhvhv_2024_01
WHERE TRY_CAST(trip_miles AS DECIMAL(10,2)) IS NULL;
/* Sample output: 0 rows returned - every trip_miles value converted */
GO

/* ---- Step 6: Once verified, the raw staging table can be
   archived or dropped to reclaim disk space (see script 03). ---- */
