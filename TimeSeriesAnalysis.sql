-- 1.1. Simple Trend
/*Task: You need to analyze the trend of payment transactions of Billing category from 2019 to 2020. 
First, let’s show the trend of the number of successful transactions by month. */

---- cách 1: UNION 2 bảng fact trước --> JOIN dim scenario --> gom nhóm tính toán

WITH fact_table AS ( -- 1,198,484 rows 
    SELECT *
    FROM fact_transaction_2019 -- 400k rows 
    UNION 
    SELECT *
    FROM fact_transaction_2020 )  -- 800k rows) 
SELECT 
    Year(transaction_time) AS year, Month(transaction_time) AS month
    , CONVERT(nvarchar(6), transaction_time, 112) AS time_calendar
    , COUNT(transaction_id) AS number_trans
FROM fact_table 
JOIN dim_scenario AS sce ON fact_table.scenario_id = sce.scenario_id -- scenrio : <100 
WHERE status_id = 1 AND category = 'Billing' 
GROUP BY Year(transaction_time), Month(transaction_time), CONVERT(nvarchar(6), transaction_time, 112)
ORDER BY year, month

---- cách 2: JOIN từng bảng FACT với Scenario và đặt điều kiện Billing --> UNION
WITH fact_table AS (
    SELECT fact_19.*, category
    FROM fact_transaction_2019 fact_19 
    JOIN dim_scenario sce -- < 100 dòng 
    ON fact_19.scenario_id = sce.scenario_id
    WHERE status_id = 1 AND category = 'Billing' 
    UNION
    SELECT fact_20.*, category
    FROM fact_transaction_2020 fact_20 
    JOIN dim_scenario sce 
    ON fact_20.scenario_id = sce.scenario_id
    WHERE status_id = 1 AND category = 'Billing' 
)
SELECT Year(transaction_time) AS year, Month(transaction_time) AS month
        , CONVERT(nvarchar(6), transaction_time, 112) AS time_calendar
        , COUNT(transaction_id) AS number_trans
FROM fact_table
GROUP BY Year(transaction_time), Month(transaction_time), CONVERT(nvarchar(6), transaction_time, 112)
ORDER BY year, month


-- 1.2. Comparing Component  
/* Task: You know that there are many sub-categories of Billing group. After reviewing the above result, you should break down the trend into each sub-categories.*/

WITH fact_table AS (
    SELECT *
    FROM fact_transaction_2019 
    UNION 
    SELECT *
    FROM fact_transaction_2020 )
SELECT 
    YEAR(transaction_time) AS year, MONTH(transaction_time) AS month
    , sub_category
    , COUNT(transaction_id) AS number_trans
FROM fact_table 
JOIN dim_scenario AS sce ON fact_table.scenario_id = sce.scenario_id
WHERE status_id = 1 AND category = 'Billing'
GROUP BY YEAR(transaction_time), MONTH(transaction_time), sub_category
ORDER BY year, month 

/*Then modify the result as the following table: Only select the sub-categories belong to list (Electricity, Internet and Water) */

WITH fact_table AS (
    SELECT *
    FROM fact_transaction_2019 
    UNION 
    SELECT *
    FROM fact_transaction_2020 )
, count_month AS (
    SELECT 
        YEAR(transaction_time) AS year, MONTH(transaction_time) AS month
        , sub_category
        , COUNT(transaction_id) AS number_trans
    FROM fact_table 
    JOIN dim_scenario AS sce ON fact_table.scenario_id = sce.scenario_id
    WHERE status_id = 1 AND category = 'Billing'
    GROUP BY YEAR(transaction_time), MONTH(transaction_time), sub_category
)
SELECT year, month
    , SUM ( CASE WHEN sub_category = 'Electricity' THEN number_trans ELSE 0 END ) AS electricity_trans
    , SUM ( CASE WHEN sub_category = 'Internet' THEN number_trans ELSE 0 END ) AS internet_trans
    , SUM ( CASE WHEN sub_category = 'Water' THEN number_trans ELSE 0 END ) AS water_trans
FROM count_month
GROUP BY year, month 
ORDER BY year, month 


-- 1.3.	Percent of Total Calculations: When working with time series data that has multiple parts or attributes that constitute a whole, 
-- it’s often useful to analyze each part’s contribution to the whole and whether that has changed over time. 
-- Unless the data already contains a time series of the total values, we’ll need to calculate the overall total in order to calculate the percent of total for each row. 

/*Task: Based on the previous query, you need to calculate the proportion of each sub-category (Electricity, Internet and Water) in the total for each month. */

WITH fact_table AS (
    SELECT *
    FROM fact_transaction_2019 
    UNION 
    SELECT *
    FROM fact_transaction_2020 )
, sub_count AS (
    SELECT 
        YEAR(transaction_time) year, MONTH(transaction_time) month
        , sub_category
        , COUNT(transaction_id) AS number_trans
    FROM fact_table 
    JOIN dim_scenario AS sce ON fact_table.scenario_id = sce.scenario_id
    WHERE status_id = 1 AND category = 'Billing'
    GROUP BY YEAR(transaction_time), MONTH(transaction_time), sub_category
)
, sub_month AS (
    SELECT Year 
        , month 
        , SUM( CASE WHEN sub_category = 'Electricity' THEN number_trans ELSE 0 END ) AS electricity_trans
        , SUM( CASE WHEN sub_category = 'Internet' THEN number_trans ELSE 0 END ) AS internet_trans
        , SUM( CASE WHEN sub_category = 'Water' THEN number_trans ELSE 0 END ) AS water_trans
    FROM sub_count
    GROUP BY year, month
)
, total_month AS ( 
    SELECT * 
    , electricity_trans + internet_trans + water_trans  AS total_trans_month
FROM sub_month
)
SELECT *
    , FORMAT(1.0*electricity_trans/total_trans_month, 'p') AS elec_pct
    , FORMAT(1.0*internet_trans/total_trans_month, 'p') AS iternet_pct
    , FORMAT(1.0*water_trans/total_trans_month, 'p') AS water_pct
FROM total_month

-- 1.4.	Indexing to See Percent Change over Time: Indexing data is a way to understand the changes in a time series relative to a base period (starting point). 
-- Indices are widely used in economics as well as business settings.

/*Task: Select only these sub-categories in the list (Electricity, Internet and Water), 
you need to calculate the number of successful paying customers for each month (from 2019 to 2020). 
Then find the percentage change from the first month (Jan 2019) for each subsequent month.*/

WITH fact_table AS (
    SELECT * FROM fact_transaction_2019
    UNION 
    SELECT * FROM fact_transaction_2020
)
, customer_month AS (
    SELECT MONTH(transaction_time) month, YEAR(transaction_time) year
        , COUNT( DISTINCT customer_id ) AS number_customer -- đếm số lượng khách hàng 
    FROM fact_table
    JOIN dim_scenario AS scena ON fact_table.scenario_id = scena.scenario_id
    WHERE category = 'Billing' AND status_id = 1 AND sub_category IN ('Electricity', 'Internet',  'Water')
    GROUP BY MONTH(transaction_time), YEAR(transaction_time)
)
, start_point AS (
    SELECT * 
    , FIRST_VALUE (number_customer) OVER ( ORDER BY year, month ) AS starting_point
    FROM customer_month
)
SELECT *
    , FORMAT ( number_customer *1.0/ starting_point - 1, 'p') AS pct_diff
FROM start_point


