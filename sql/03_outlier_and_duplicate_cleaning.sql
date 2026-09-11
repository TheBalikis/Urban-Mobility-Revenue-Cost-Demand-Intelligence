/* ============================================================
   03_outlier_and_duplicate_cleaning.sql
   Purpose : Remove logically-invalid records and exact
             duplicate trips from dbo.fhvhv_2024_01_clean.
             Type-valid is not the same as logically valid -
             this script checks values make real-world sense.
   ============================================================ */

USE fhvhv_analysis;
GO

/* ---- Step 1: Identify lower-bound (non-positive) anomalies ---- */
SELECT COUNT(*) AS negative_or_zero_miles FROM dbo.fhvhv_2024_01_clean WHERE trip_miles <= 0;
SELECT COUNT(*) AS negative_or_zero_time  FROM dbo.fhvhv_2024_01_clean WHERE trip_time  <= 0;
SELECT COUNT(*) AS negative_fare          FROM dbo.fhvhv_2024_01_clean WHERE base_passenger_fare < 0;
SELECT COUNT(*) AS negative_driver_pay    FROM dbo.fhvhv_2024_01_clean WHERE driver_pay < 0;
/* Sample output: 3,287 / 2 / 191 / 137
   Root cause     : canceled trips, GPS initialization errors,
                     refunded rides, pay adjustments */

/* ---- Step 2: Identify upper-bound (extreme) anomalies ---- */
SELECT
    MAX(trip_miles)                AS max_miles,
    MAX(trip_time / 3600.0)        AS max_hours,
    MAX(base_passenger_fare)       AS max_fare,
    MAX(driver_pay)                AS max_pay
FROM dbo.fhvhv_2024_01_clean;
/* Sample output (pre-clean): max_miles=417.62, max_hours=14.46,
   max_fare=1691.90, max_pay=1218.17 */

SELECT COUNT(*) AS upper_outlier_count
FROM dbo.fhvhv_2024_01_clean
WHERE trip_miles > 100
   OR trip_time > 14400        -- 4 hours in seconds
   OR base_passenger_fare > 500
   OR driver_pay > 400;
GO

/* ---- Step 3: Remove lower-bound invalid records ---- */
DELETE FROM dbo.fhvhv_2024_01_clean
WHERE trip_miles <= 0
   OR trip_time  <= 0
   OR base_passenger_fare < 0
   OR driver_pay < 0;
GO

/* ---- Step 4: Remove upper-bound extreme outliers ---- */
DELETE FROM dbo.fhvhv_2024_01_clean
WHERE trip_miles > 100
   OR trip_time > 14400
   OR base_passenger_fare > 500
   OR driver_pay > 400;
GO

/* ---- Step 5: Verify post-cleaning profile ---- */
SELECT
    MIN(trip_miles)             AS min_miles,
    MAX(trip_miles)             AS max_miles,
    AVG(trip_miles)             AS avg_miles,
    MAX(trip_time / 3600.0)     AS max_hours,
    MAX(base_passenger_fare)    AS max_fare,
    MAX(driver_pay)             AS max_pay
FROM dbo.fhvhv_2024_01_clean;
/* Sample output: min_miles=0.01, max_miles=99.98, avg_miles=4.83
   (aligns with NYC TLC operational benchmarks), max_hours=3.99,
   max_fare=499.50, max_pay=399.10 */
GO

/* ---- Step 6: Temporal consistency check ---- */
SELECT COUNT(*) AS dropoff_before_pickup
FROM dbo.fhvhv_2024_01_clean
WHERE dropoff_datetime < pickup_datetime;
/* Sample output: 0 - 100% chronologically consistent */

SELECT MIN(pickup_datetime) AS earliest, MAX(pickup_datetime) AS latest
FROM dbo.fhvhv_2024_01_clean;
/* Sample output: 2024-01-01 00:00:00 to 2024-01-31 23:59:59
   (entirely within the expected month) */
GO

/* ---- Step 7: Logical mismatch checks (fare vs distance/time) ---- */
SELECT COUNT(*) AS fare_with_no_trip
FROM dbo.fhvhv_2024_01_clean
WHERE base_passenger_fare > 0 AND (trip_miles = 0 OR trip_time = 0);
/* Sample output: 0 */

SELECT COUNT(*) AS trip_with_no_fare
FROM dbo.fhvhv_2024_01_clean
WHERE base_passenger_fare = 0 AND (trip_miles > 0 AND trip_time > 0);
/* Sample output: 7,142 */

/* Investigate: were drivers still paid on these zero-fare trips?
   Distinguishes genuine promo/comped rides from broken records. */
SELECT
    COUNT(*)                                          AS zero_fare_count,
    SUM(CASE WHEN driver_pay > 0 THEN 1 ELSE 0 END)    AS driver_was_paid,
    SUM(CASE WHEN driver_pay = 0 THEN 1 ELSE 0 END)    AS driver_not_paid,
    AVG(trip_miles)                                    AS avg_miles,
    AVG(trip_time / 60.0)                              AS avg_minutes
FROM dbo.fhvhv_2024_01_clean
WHERE base_passenger_fare = 0 AND trip_miles > 0 AND trip_time > 0;
/* Sample output: zero_fare_count=7142, driver_was_paid=7142,
   driver_not_paid=0, avg_miles=4.44, avg_minutes=16.7
   Conclusion: legitimate promo/comped rides (driver still paid,
   normal trip profile) - NOT deleted, retained in dataset. */
GO

/* ---- Step 8: Duplicate detection ----
   Groups on a combination of fields that together should
   uniquely identify a real trip. */
SELECT
    hvfhs_license_num, dispatching_base_num, pickup_datetime, dropoff_datetime,
    PULocationID, DOLocationID, trip_miles, base_passenger_fare, driver_pay,
    COUNT(*) AS occurrence_count
FROM dbo.fhvhv_2024_01_clean
GROUP BY hvfhs_license_num, dispatching_base_num, pickup_datetime, dropoff_datetime,
         PULocationID, DOLocationID, trip_miles, base_passenger_fare, driver_pay
HAVING COUNT(*) > 1;
/* Sample output: 2 groups found, each with occurrence_count = 2
   (2 duplicate pairs = 2 extra rows to remove) */
GO

/* ---- Step 9: Remove duplicates, keeping one copy of each ---- */
WITH duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY hvfhs_license_num, dispatching_base_num, pickup_datetime, dropoff_datetime,
                         PULocationID, DOLocationID, trip_miles, base_passenger_fare, driver_pay
            ORDER BY (SELECT NULL)
        ) AS rn
    FROM dbo.fhvhv_2024_01_clean
)
DELETE FROM duplicates WHERE rn > 1;
GO

/* ---- Step 10: Final verification ---- */
SELECT COUNT(*) AS final_row_count FROM dbo.fhvhv_2024_01_clean;
/* Sample output: 19,658,442
   (19,663,930 original - 5,486 outliers - 2 duplicates = 19,658,442) */
GO
