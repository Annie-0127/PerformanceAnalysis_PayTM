/*Based on the RFM task in the previous lesson, you need to segment the users of Billing category (from 2019 to 2020, only select successful transactions) into 9 groups*/
/*2.1.	The first step in building an RFM model is to assign Recency, Frequency and Monetary values to each customer. 
Let’s calculate these metrics for all successful paying customer of ‘Billing’ in 2019 and 2020: 
•	Recency: Difference between each customer's last payment date and '2020-12-31'
•	Frequency: Number of successful payment transactions of each customer
•	Monetary: Total charged amount of each customer  
*/

WITH temp_table AS(
SELECT transaction_id 
    , customer_id 
    , transaction_time
    , charged_amount
FROM (SELECT * FROM fact_transaction_2019
    UNION 
    SELECT * FROM fact_transaction_2020) AS fact_trans 
LEFT JOIN dim_status sta ON fact_trans.status_id = sta.status_id 
LEFT JOIN dim_scenario sce ON fact_trans.scenario_id = sce.scenario_id 
WHERE status_description = 'Success'
    AND category = 'Billing'
)
,rfm_metric AS(
    SELECT customer_id 
        , DATEDIFF(day, MAX(transaction_time), '2020-12-31') AS recency
        , COUNT(DISTINCT CONVERT(varchar, transaction_time, 102)) AS frequency
        , SUM(charged_amount*1.0) AS monetary
    FROM temp_table
    GROUP BY customer_id
)
,rfm_rank_percent AS(
    SELECT *
        , PERCENT_RANK() OVER(ORDER BY recency) AS r_percent_rank
        , PERCENT_RANK() OVER(ORDER BY frequency DESC) AS f_percent_rank
        , PERCENT_RANK() OVER(ORDER BY monetary DESC) AS m_percent_rank
    FROM rfm_metric
)
,rfm_tier AS (
    SELECT *
        , CASE WHEN r_percent_rank > 0.75 THEN 4
            WHEN r_percent_rank > 0.5 THEN 3
            WHEN r_percent_rank > 0.25 THEN 2
            ELSE 1 END AS r_tier
        , CASE WHEN f_percent_rank > 0.75 THEN 4
            WHEN f_percent_rank > 0.5 THEN 3
            WHEN f_percent_rank > 0.25 THEN 2
            ELSE 1 END AS f_tier
        , CASE WHEN m_percent_rank > 0.75 THEN 4
            WHEN m_percent_rank > 0.5 THEN 3
            WHEN m_percent_rank > 0.25 THEN 2
            ELSE 1 END m_tier
    FROM rfm_rank_percent
)
,rfm_group AS (
    SELECT *
        , CONCAT(r_tier,f_tier,m_tier) AS rfm_score 
    FROM rfm_tier
)
, segment_table AS(
    SELECT *
        , CASE WHEN rfm_score = 111 THEN 'Best customers'
            WHEN rfm_score LIKE '[3-4][3-4][1-4]' THEN 'Lost Best customers' 
            WHEN rfm_score LIKE '[3-4]2[1-4]' THEN 'Lost customers' 
            WHEN rfm_score LIKE '21[1-4]' THEN 'Almost lost' 
            WHEN rfm_score LIKE '11[2-4]' THEN 'Loyal customers' 
            WHEN rfm_score LIKE '[1-2][1-3]1' THEN 'Big Spender' 
            WHEN rfm_score LIKE '[1-2]4[1-4]' THEN 'New customers'
            WHEN rfm_score LIKE '[3-4]1[1-4]' THEN 'Hibernating'
            WHEN rfm_score LIKE '[1-2][2-3][2-4]' THEN 'Potential Loyalist'   
            ELSE 'unknown' END AS segment
    FROM rfm_group
)
SELECT segment 
    , COUNT(customer_id) AS nb_customer
    , SUM(COUNT(customer_id)) OVER() AS total_customer
    , FORMAT( COUNT(customer_id)*1.0 / SUM(COUNT(customer_id)) OVER() , 'p') AS pct_segment
FROM segment_table
GROUP BY segment
