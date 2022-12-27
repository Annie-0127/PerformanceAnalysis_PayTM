
-- 1.1 
-- Basic retention curve
/* 1.1 A: 	As you know that 'Telco Card' is the most product in the Telco group (accounting for more than 99% of the total). 
 You want to evaluate the quality of user acquisition in Jan 2019 by the retention metric.
 First, you need to know how many users are retained in each subsequent month from the first month (Jan 2019) they pay the successful transaction (only get data of 2019). 
*/
-- Way 1: 
-- b1: Đi tìm tập customers 1/2019 mua Telco card thành công : 2,111 customers 
WITH customer_list AS (
    SELECT DISTINCT customer_id
    FROM fact_transaction_2019 fact 
    JOIN dim_scenario sce ON fact.scenario_id = sce.scenario_id
    WHERE sub_category = 'Telco Card' AND status_id = 1 AND MONTH(transaction_time) = 1
)
, full_trans AS ( -- b2: Đi tìm tất cả giao dịch của tập trên : JOIN với fact_2019: 19,634 trans của tập trên 
    SELECT fact.*
    FROM customer_list 
    JOIN fact_transaction_2019 fact 
        ON customer_list.customer_id = fact.customer_id
    JOIN dim_scenario sce 
        ON fact.scenario_id = sce.scenario_id
    WHERE sub_category = 'Telco Card' AND status_id = 1
) -- b3: Đếm xem từng tháng có bao nhiêu khách hàng
SELECT MONTH(transaction_time) - 1 AS subsequence_month
    , COUNT( DISTINCT customer_id) AS retained_users
FROM full_trans 
GROUP BY MONTH(transaction_time) - 1 
ORDER BY subsequence_month 

-- way2: Mình sẽ tìm tháng đầu tiên của mỗi khách hàng thanh toán Telco card --> Chọn ra tập khách hàng 
-- có tháng đầu tiên là 1 
WITH period_table AS (
    SELECT customer_id
        , transaction_id
        , transaction_time
        , MIN( MONTH (transaction_time)) OVER (PARTITION BY customer_id) AS first_month
        , DATEDIFF(month, MIN( transaction_time) OVER (PARTITION BY customer_id), transaction_time) AS subsequence_month
    FROM fact_transaction_2019 fact 
    JOIN dim_scenario sce ON fact.scenario_id = sce.scenario_id
    WHERE sub_category = 'Telco Card' AND status_id = 1
    -- ORDER BY customer_id, transaction_time
)
SELECT subsequence_month
    , COUNT( DISTINCT customer_id) AS retained_users
FROM period_table
WHERE first_month = 1
GROUP BY subsequence_month
ORDER BY subsequence_month


-- 1.1 B: You realize that the number of retained customers has decreased over time. Let’s calculate retention =  number of retained customers / total users of the first month. 
WITH period_table AS (
    SELECT customer_id, transaction_id, transaction_time
        , MIN(transaction_time) OVER( PARTITION BY customer_id) AS first_time
        , DATEDIFF(month, MIN(transaction_time) OVER( PARTITION BY customer_id), transaction_time) AS subsequent_month
    FROM fact_transaction_2019 fact 
    JOIN dim_scenario sce ON fact.scenario_id = sce.scenario_id
    WHERE sub_category = 'Telco Card' AND status_id = 1
)
, retained_user AS (
    SELECT subsequent_month
        , COUNT( DISTINCT customer_id) AS retained_users
    FROM period_table
    WHERE MONTH(first_time) = 1
    GROUP BY subsequent_month
-- ORDER BY subsequent_month
)
SELECT *
    , FIRST_VALUE(retained_users) OVER( ORDER BY subsequent_month) AS original_users
    , MAX(retained_users) OVER() AS original_users_2
    , (SELECT COUNT(DISTINCT customer_id)
        FROM period_table 
        WHERE MONTH(first_time) = 1) AS original_users_3
    , FORMAT(1.0*retained_users/FIRST_VALUE(retained_users) OVER( ORDER BY subsequent_month ASC), 'p') AS pct_retained_users
FROM retained_user



