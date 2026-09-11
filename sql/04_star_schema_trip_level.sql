/* ============================================================
   04_star_schema_trip_level.sql
   Purpose : Build the trip-level star schema for Power BI:
             one fact table (fact_trips) plus three dimension
             tables (Dim_TaxiZone, Dim_Date, Dim_Hour).
   Input   : dbo.fhvhv_2024_01_clean (cleaned, deduplicated)
             dbo.taxi_zone_lookup    (NYC TLC zone reference)
   ============================================================ */

USE fhvhv_analysis;
GO

/* ---- Step 1: Build Dim_Date (daily grain, January 2024 only) ---- */
SELECT DISTINCT
    CAST(pickup_datetime AS DATE) AS date_key,
    DATENAME(WEEKDAY, pickup_datetime) AS day_of_week,
    DATEPART(WEEKDAY, pickup_datetime) AS day_of_week_num,
    DATEPART(DAY, pickup_datetime) AS day_of_month,
    CASE WHEN DATEPART(WEEKDAY, pickup_datetime) IN (1,7) THEN 1 ELSE 0 END AS is_weekend
INTO dbo.dim_date
FROM dbo.fhvhv_2024_01_clean;
GO
/* Sample output: 31 rows (one per day in January 2024) */

/* ---- Step 2: Build Dim_Hour (24 rows, 0-23) ---- */
SELECT n AS pickup_hour,
    CASE WHEN n BETWEEN 6 AND 9   THEN 'Morning Rush'
         WHEN n BETWEEN 10 AND 15 THEN 'Midday'
         WHEN n BETWEEN 16 AND 19 THEN 'Evening Rush'
         WHEN n BETWEEN 20 AND 23 THEN 'Night'
         ELSE 'Overnight' END AS time_period
INTO dbo.dim_hour
FROM (SELECT TOP 24 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.objects) x;
GO
/* Sample output: 24 rows (one per hour) */

/* ---- Step 3: Build Dim_TaxiZone (clean, named copy of the
   existing taxi_zone_lookup reference table) ---- */
CREATE TABLE dbo.Dim_TaxiZone
(
    LocationID   INT NOT NULL,
    Borough      NVARCHAR(100),
    Zone         NVARCHAR(150),
    Service_Zone NVARCHAR(100),
    CONSTRAINT PK_Dim_TaxiZone PRIMARY KEY (LocationID)
);
GO

INSERT INTO dbo.Dim_TaxiZone (LocationID, Borough, Zone, Service_Zone)
SELECT LocationID, Borough, Zone, service_zone
FROM dbo.taxi_zone_lookup;
GO
/* Sample output: 265 rows (NYC TLC zone count) */

/* ---- Step 4: Build fact_trips (grain: one row = one trip) ---- */
SELECT
    t.PULocationID,
    t.DOLocationID,
    CAST(t.pickup_datetime AS DATE) AS pickup_date,
    DATEPART(HOUR, t.pickup_datetime) AS pickup_hour,
    t.hvfhs_license_num,
    t.trip_miles,
    t.trip_time,
    t.base_passenger_fare,
    t.tolls,
    t.bcf,
    t.sales_tax,
    t.congestion_surcharge,
    t.airport_fee,
    t.tips,
    t.driver_pay,
    t.shared_request_flag,
    t.shared_match_flag,
    t.wav_request_flag,
    t.pickup_datetime,
    t.dropoff_datetime
INTO dbo.fact_trips
FROM dbo.fhvhv_2024_01_clean t;
GO
/* Sample output: 19,658,442 rows (exact match to cleaned source) */

/* ---- Step 5: Indexes on fact_trips foreign keys ----
   Required before joining to dimensions at this scale -
   without these, every join is a full table scan across
   19.6M rows. */
CREATE INDEX IX_fact_trips_PULocationID ON dbo.fact_trips(PULocationID);
CREATE INDEX IX_fact_trips_DOLocationID ON dbo.fact_trips(DOLocationID);
CREATE INDEX IX_fact_trips_pickup_date  ON dbo.fact_trips(pickup_date);
CREATE INDEX IX_fact_trips_pickup_hour  ON dbo.fact_trips(pickup_hour);
GO

/* ---- Step 6: Verify row counts across the schema ---- */
SELECT COUNT(*) AS date_row_count FROM dbo.dim_date;        -- expect 31
SELECT COUNT(*) AS hour_row_count FROM dbo.dim_hour;        -- expect 24
SELECT COUNT(*) AS zone_row_count FROM dbo.Dim_TaxiZone;    -- expect 265
SELECT COUNT(*) AS fact_row_count FROM dbo.fact_trips;      -- expect 19,658,442
GO

/* ---- Step 7: Validate the pickup/dropoff joins to Dim_TaxiZone ----
   Confirms: (a) join does not change row count (no fan-out from
   a non-unique LocationID), (b) every PU/DO location resolves
   to a real zone (no unmatched IDs). */
SELECT COUNT(*) AS joined_row_count
FROM dbo.fact_trips t
LEFT JOIN dbo.Dim_TaxiZone pu ON t.PULocationID = pu.LocationID
LEFT JOIN dbo.Dim_TaxiZone do_ ON t.DOLocationID = do_.LocationID;
/* Sample output: 19,658,442 (unchanged - join is clean) */

SELECT COUNT(*) AS unmatched_pickup
FROM dbo.fact_trips t
LEFT JOIN dbo.Dim_TaxiZone pu ON t.PULocationID = pu.LocationID
WHERE pu.LocationID IS NULL;
/* Sample output: 0 */

SELECT COUNT(*) AS unmatched_dropoff
FROM dbo.fact_trips t
LEFT JOIN dbo.Dim_TaxiZone do_ ON t.DOLocationID = do_.LocationID
WHERE do_.LocationID IS NULL;
/* Sample output: 0 */
GO

/* ---- Step 8: Once verified, the intermediate flat table
   dbo.fhvhv_2024_01_clean can be archived/dropped, since
   dbo.fact_trips is now the model's source of truth. ---- */
