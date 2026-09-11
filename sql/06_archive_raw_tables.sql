/* ============================================================
   06_archive_raw_tables.sql
   Purpose : Once dbo.fact_trips and dbo.Fact_Monthly_Operations
             are built and verified (scripts 04 and 05), the
             intermediate/raw tables that fed them are no longer
             needed as the analytical source of truth and can be
             removed to reclaim disk space (each holds a full
             duplicate copy of ~19.6M rows).
   Caution : This step is irreversible. Only run after confirming
             every verification query in scripts 02-05 has
             passed. A rename-and-keep alternative is included
             for anyone who prefers to retain a raw backup.
   ============================================================ */

USE fhvhv_analysis;
GO

/* Option A (safer): rename instead of dropping, keeps a raw
   backup on disk under an unambiguous archive name. */
-- EXEC sp_rename 'dbo.fhvhv_2024_01_clean', 'fhvhv_2024_01_clean_archive';

/* Option B: drop outright once fully confident (used in this
   project, after all verification steps passed). */
DROP TABLE dbo.fhvhv_2024_01;         -- raw staging table (superseded by fhvhv_2024_01_clean, then by fact_trips)
DROP TABLE dbo.fhvhv_2024_01_clean;   -- flat cleaned table (superseded by fact_trips)
GO

/* Note: dbo.taxi_zone_lookup and dbo.data_reports_monthly are
   left in place, since they remain the raw reference sources
   for Dim_TaxiZone and Fact_Monthly_Operations respectively and
   may be useful for future re-verification. */
