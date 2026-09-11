# Urban-Mobility-Revenue-Cost-Demand-Intelligence
SQL Server and Power BI analysis of 19.6M NYC High-Volume For-Hire Vehicle trips - revenue, driver pay, demand patterns, and fleet trends from 2015–2026.

# Urban Mobility Revenue, Cost & Demand Intelligence

## Table of Contents

- [1. Executive Summary](executive-summary)
- [2. Project Overview](project-overview)
- [3. Data Overview](data-overview)
- [4. Problem Statement](problem-statement)
- [5. Tools & Methodology](tools--methodology)
- [6. Exploratory & Diagnostic Analysis](#exploratory--diagnostic-analysis)
- [7. Data Preparation for Decision-Making](#data-preparation-for-decision-making)
- [8. Key Insights](#key-insights)
- [9. Dashboard Overview](#dashboard-overview)
- [10. Recommendations](#recommendations)
- [11. Limitations](#limitations)
- [12. Conclusion](#conclusion)
- [13. Repository Structure](#repository-structure)
---

##  Executive Summary

NYC's High-Volume For-Hire Vehicle (HVFHV) market generates millions of trips across changing demand periods, geographic locations, and operating conditions. However, total trip volume alone does not explain where demand is concentrated, how revenue relates to driver compensation, or whether fleet capacity is aligned with market activity.

This project analyzes **January 2024 HVFHV trip-level data alongside NYC TLC monthly operations data from 2015 to 2026** to identify the key drivers of demand, revenue, driver pay, geographic concentration, and fleet utilization. The goal is to turn large-scale mobility data into decision-ready insights that can support fleet allocation, driver availability, revenue monitoring, and capacity planning.

The project processed approximately **19.66 million trips**, generating **$470.35M in base passenger fares** and **$358.65M in driver pay**. The final analysis was developed using **Python, SQL Server, and Power BI**.

---

##  Project Overview

### Business Context

Urban mobility operators must balance demand, revenue, driver compensation, and available fleet capacity. Looking at these metrics independently can hide important operating patterns.

For example:

- High trip volume does not automatically mean high financial contribution.
- High-demand locations may require different fleet allocation decisions.
- Revenue growth must be evaluated alongside driver compensation.
- Fleet and driver growth should be considered alongside utilization.

This project combines detailed trip-level analysis with longer-term monthly market data to provide a broader view of mobility performance.

### Project Objective

The analysis was designed to answer the following questions:

- **When is demand highest?**
- **Where is trip activity concentrated?**
- **How do revenue and driver pay vary across operating periods and locations?**
- **Which areas contribute the most to fare and gross margin?**
- **How have fleet, driver, and utilization patterns changed over time?**

### Analytical Workflow

**Define → Acquire → Prepare → Explore → Model → Analyze → Communicate → Recommend**

---

##  Data Overview

The project combines three NYC TLC data sources.

| Dataset | Purpose |
|---|---|
| HVFHV Trip Records | Trip-level demand, fare, driver pay, distance, duration, and shared-trip analysis |
| TLC Monthly Operations Reports | Long-term trends in trips, vehicles, drivers, utilization, and shared-trip activity |
| Taxi Zone Lookup | Geographic analysis of pickup and drop-off locations |

### Trip-Level Dataset

**Source:** NYC Taxi & Limousine Commission (TLC)
**Period:** January 2024
**Final analytical records:** Approximately **19.66 million trips**

Key fields include:

- Pickup and drop-off timestamps
- Pickup and drop-off location IDs
- Trip distance
- Trip duration
- Base passenger fare
- Driver pay
- Tolls
- Taxes and surcharges
- Tips
- Shared-trip indicators
- HVFHV license class

### Monthly Operations Dataset

**Coverage:** January 2015 to May 2026

The monthly dataset was used to analyze longer-term changes in:

- Trip volume
- Vehicle availability
- Driver availability
- Vehicle utilization
- Driver utilization
- Farebox activity
- Shared-trip activity

### Geographic Reference Data

The NYC TLC taxi zone lookup table was used to connect trip location IDs with:

- Borough
- Zone
- Service zone

---

## Problem Statement

The HVFHV market operates at a scale where aggregate trip counts alone are insufficient for understanding operational performance.

A high number of trips may indicate strong demand, but it does not explain:

- Where demand is concentrated
- When fleet pressure is highest
- Which locations generate the greatest revenue
- How driver compensation compares with passenger fares
- How operating performance differs across license classes
- Whether driver and vehicle supply are changing alongside demand

This project analyzes trip-level and monthly operational data together to identify the patterns behind these outcomes and support more informed decisions around **fleet positioning, driver availability, and revenue monitoring**.

---

##  Tools & Methodology

### Tools Used

| Tool | Purpose |
|---|---|
| Python | Large-file processing and Parquet-to-CSV conversion |
| SQL Server | Data ingestion, preparation, validation, modeling, and analysis |
| Power BI | Data modeling, DAX measures, and dashboard development |
| Excel | Data dictionary and supporting documentation |

### Methodology

The project followed these stages:

1. Acquired the relevant NYC TLC datasets
2. Inspected data structure and field availability
3. Processed the large Parquet file in batches
4. Loaded the converted data into SQL Server
5. Prepared typed analytical tables
6. Performed data-quality and consistency checks
7. Reviewed invalid values, outliers, and duplicates
8. Built trip-level and monthly analytical models
9. Performed trend, segmentation, and diagnostic analysis
10. Developed DAX measures and Power BI visuals
11. Translated the analysis into business recommendations

---

##  Exploratory & Diagnostic Analysis

The analysis was designed to move beyond descriptive reporting.

### Trend Analysis

Key metrics were examined over time to understand changes in:

- Trip demand
- Revenue
- Driver pay
- Vehicles
- Drivers
- Utilization
- Shared-trip activity

Trend analysis helped identify periods of disruption, recovery, growth, and changing operating conditions.

### Segmentation Analysis

Key metrics were broken down by:

- Borough
- Pickup zone
- Drop-off zone
- Hour of day
- Day of week
- License class
- Shared-trip status

This was important because overall averages can hide meaningful differences between locations and operating segments.

### Diagnostic Analysis

Where a pattern was identified, the analysis examined additional variables to understand the possible drivers behind it.

For example:

> **Demand by hour → Revenue concentration → Driver pay concentration**

and:

> **Geographic trip volume → Revenue contribution → Operating implications**

The goal was to connect observed patterns with decisions rather than stopping at descriptive totals.

---

##  Data Preparation for Decision-Making

The raw data was not used directly for analysis.

The dataset was prepared for decision-making through:

- Data type conversion
- Datetime standardization
- Missing-value assessment
- Range validation
- Logical consistency checks
- Duplicate detection
- Outlier review
- Geographic validation
- Creation of analytical fields
- Dimensional modeling

### Large-File Processing

The January 2024 HVFHV Parquet file contained more than 19 million records and could not be efficiently loaded into memory as a single pandas DataFrame.

The file was therefore processed using Python and PyArrow in **500,000-row batches** before conversion to CSV. This allowed the complete dataset to be prepared for SQL Server ingestion without loading all records into memory simultaneously.

### SQL Server Ingestion

After conversion, the CSV was loaded into SQL Server using `BULK INSERT`.

    BULK INSERT dbo.Raw_Data
    FROM 'C:\Users\<username>\Downloads\HVFHV\fhvhv_2024_01.csv'
    WITH (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        TABLOCK
    );

The full loading process is available in `sql/01_load_raw_data.sql`.

### Example Data Validation

Invalid trip records were checked before the final analytical table was created.

    SELECT
        COUNT(*) AS Invalid_Trips
    FROM dbo.fhvhv_2024_01_typed
    WHERE trip_miles <= 0
       OR trip_time <= 0
       OR base_passenger_fare < 0
       OR driver_pay < 0;

Duplicate records were also investigated using trip timestamps and locations.

    SELECT
        pickup_datetime,
        dropoff_datetime,
        PULocationID,
        DOLocationID,
        COUNT(*) AS Trip_Count
    FROM dbo.fhvhv_2024_01_typed
    GROUP BY
        pickup_datetime,
        dropoff_datetime,
        PULocationID,
        DOLocationID
    HAVING COUNT(*) > 1;

**How much of the base fare is represented by driver pay?**

    SELECT
        SUM(base_passenger_fare) AS Total_Base_Fare,
        SUM(driver_pay) AS Total_Driver_Pay,
        SUM(base_passenger_fare) - SUM(driver_pay)
            AS Fare_Driver_Pay_Difference,
        SUM(driver_pay) /
            NULLIF(SUM(base_passenger_fare), 0) * 100
            AS Driver_Pay_Percentage
    FROM dbo.fact_trips;

This analysis established the relationship between passenger fares and driver compensation.

**How does trip performance differ by license class?**

    SELECT
        hvfhs_license_num,
        COUNT(*) AS Total_Trips,
        SUM(base_passenger_fare) AS Total_Revenue,
        AVG(base_passenger_fare) AS Avg_Base_Fare,
        AVG(driver_pay) AS Avg_Driver_Pay
    FROM dbo.fact_trips
    GROUP BY hvfhs_license_num
    ORDER BY Total_Revenue DESC;

**How does gross margin vary by borough?**

    SELECT
        z.Borough,
        COUNT(*) AS Total_Trips,
        AVG(f.base_passenger_fare) AS Avg_Base_Fare,
        AVG(f.driver_pay) AS Avg_Driver_Pay,
        SUM(f.base_passenger_fare) - SUM(f.driver_pay) AS Gross_Margin
    FROM dbo.fact_trips AS f
    JOIN dbo.Dim_TaxiZone AS z
        ON f.PULocationID = z.LocationID
    GROUP BY z.Borough
    ORDER BY Gross_Margin DESC;

**Note:** Gross Margin in this analysis represents the difference between base passenger fare and driver pay. It should not be interpreted as net profit, because the dataset does not include all operating costs.

---

##  Key Insights

### Demand Is Concentrated in Specific Operating Periods

Trip demand was not evenly distributed throughout the day. Activity increased through the afternoon and reached its strongest levels during the late afternoon and evening. This means fleet availability should be aligned with peak demand periods rather than distributed uniformly throughout the day.

### Driver Pay Represents a Significant Share of Base Fare

The January 2024 analysis found:

- 19.66M cleaned trips
- $470.35M in base passenger fares
- $358.65M in driver pay
- $23.93 average base fare
- $18.24 average driver pay
- 76.25% driver pay as a percentage of base fare

This demonstrates why revenue should be monitored alongside driver compensation when evaluating trip economics.

### Demand and Revenue Are Geographically Concentrated

Trip activity was concentrated in specific pickup and drop-off zones rather than being evenly distributed across New York City. This creates an opportunity to use geographic demand patterns to inform fleet positioning and operational planning.

### License Classes Have Different Operating Profiles

HV0003 accounted for the majority of January 2024 trip activity and base fare revenue, while HV0005 represented a smaller share of the market. Analyzing the license classes separately prevents overall market metrics from masking these differences.

### Market Activity Shows Long-Term Disruption and Recovery

The monthly operations data shows a major disruption around 2020 followed by recovery in later periods. This demonstrates why long-term capacity planning should consider both demand trends and changes in available drivers and vehicles.

---

##  Dashboard Overview

The Power BI dashboard was designed as a decision-support tool rather than a collection of unrelated visuals.

###  Executive Summary

Provides a high-level view of overall performance, including:

- Total trips
- Total revenue
- Gross margin
- Average trip distance
- Long-term trip activity

###   Operations & Revenue

Examines:

- Average base fare
- Average driver pay
- Driver Pay % of Fare
- Fare vs. driver pay by borough
- Revenue vs. driver pay by hour
- Gross margin by borough 
- Top pickup zones by revenue

###  Demand & Geographic Patterns

Focuses specifically on when and where demand occurs:

- Peak demand by day and hour
- Top pickup zones by trip volume
- Top drop-off zones by trip volume

No financial KPIs were included on this page so demand and geographic patterns remain the focus.

### Page  Fleet & Market Intelligence

Examines longer-term market and operating patterns:

- Monthly trip volume and average farebox
- Vehicle and driver utilization
- Driver and vehicle growth
- Trip duration and shared-trip trends

---

##  Recommendations

**1. Align Fleet Availability With Peak Demand**
Prioritize driver and vehicle availability during periods of consistently high demand, particularly during the late afternoon and evening.

**2. Use Geographic Patterns to Support Fleet Positioning**
Monitor high-volume pickup and drop-off zones to better align vehicle availability with where trips originate and end.

**3. Monitor Revenue Alongside Driver Pay**
Revenue growth should not be evaluated independently. Driver pay represented 76.25% of base fare in the January 2024 analysis, making compensation an important part of trip economics.

**4. Evaluate License Classes Separately**
HV0003 and HV0005 have different operating profiles. Monitoring them independently can provide a clearer view of differences in volume and financial contribution.

**5. Use Long-Term Trends for Capacity Planning**
Fleet and driver levels should be evaluated alongside trip demand and utilization to determine whether additional capacity is being deployed efficiently.

---

## Limitations

This analysis has several limitations:

- The detailed trip-level analysis covers January 2024 only.
- Monthly operations data provides longer-term trends but does not contain the same level of trip-level detail.
- The analysis does not include complete operator-level costs, so fare minus driver pay should not be treated as net profit.
- The monthly data contains reported operational metrics that may not capture every aspect of fleet performance.
- Some source fields are unavailable or incomplete across all periods and license classes.
- This project describes historical demand and market patterns; it does not build predictive models to forecast future demand.

---

##  Conclusion

This project demonstrates how large-scale urban mobility data can be transformed from raw trip records into a structured decision-support solution.

The analysis shows that total trips alone are not enough to understand market performance. Demand timing, geographic concentration, fare revenue, driver compensation, license-class performance, and fleet activity must be evaluated together.

By combining large-file processing in Python, data preparation and modeling in SQL Server, and business intelligence in Power BI, the project created an end-to-end analytical workflow from raw data to actionable insights.

The final analysis provides a framework for understanding where demand is concentrated, how trip economics vary, and how longer-term fleet and market activity can support better operational planning.

---

##  Repository Structure

    urban-mobility-revenue-cost-intelligence/
    ├── README.md
    ├── sql/
    │   ├── 01_load_raw_data.sql
    │   ├── 02_clean_typed_table.sql
    │   ├── 03_outlier_and_duplicate_cleaning.sql
    │   ├── 04_star_schema_trip_level.sql
    │   ├── 05_star_schema_monthly_operations.sql
    │   └── 06_archive_raw_tables.sql
    └── docs/
        ├── Data_Dictionary.xlsx
        └── FHVHV_Pipeline_Documentation.docx

**Note:** The Power BI (`.pbix`) file is not included in this repository due to its size. Dashboard screenshots are included in the [Dashboard Overview](#9-dashboard-overview) section above, and the file is available on request.
