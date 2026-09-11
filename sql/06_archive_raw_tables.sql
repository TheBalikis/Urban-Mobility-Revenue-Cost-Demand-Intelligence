/* ============================================================
   06_archive_raw_tables.sql
   Purpose : Once dbo.fact_trips and dbo.Fact_Monthly_Operations
             are built and verified (scripts 04 and 05), the
             intermediate/raw tables that fed them are no longer
             needed as the analytical source of truth and can be
             removed to reclaim disk space (each holds a full
             duplicate copy of ~19.6M rows).
   ============================================================ */

USE fhvhv_analysis;
GO

DROP TABLE dbo.fhvhv_2024_01;         -- raw staging table (superseded by fhvhv_2024_01_clean, then by fact_trips)
DROP TABLE dbo.fhvhv_2024_01_clean;   -- flat cleaned table (superseded by fact_trips)
GO

/* Note: dbo.taxi_zone_lookup and dbo.data_reports_monthly are
   left in place, since they remain the raw reference sources
   for Dim_TaxiZone and Fact_Monthly_Operations respectively and
   may be useful for future re-verification. */
