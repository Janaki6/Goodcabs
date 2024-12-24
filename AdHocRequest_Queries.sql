-- Business Request - 1: City Level Fare and Trip Summary Report 

SELECT 
dc.city_name , 
COUNT(ft.trip_id) as total_trips,
ROUND((SUM(ft.fare_amount)/SUM(ft.distance_travelled_km)),2) AS avg_fare_per_km,
ROUND((SUM(ft.fare_amount)/COUNT(ft.trip_id)),2) AS avg_fare_per_trip,
CONCAT(ROUND((COUNT(ft.trip_id)*100.0/SUM(COUNT(ft.trip_id)) over()),2),"%")  AS pct_contribution_to_total_trips
FROM 
dim_city dc join fact_trips ft 
ON
dc.city_id = ft.city_id
GROUP BY dc.city_name
ORDER BY total_trips DESC;

-------------------------------------------------------------------------------------------------------
    -- Business Request - 2: Monthly City - Level Trips Target Performance Report
    WITH trips_count AS (
SELECT 
	ft.city_id AS city_id,
    MONTHNAME(mt.month) AS month_name,
    COUNT(ft.trip_id) AS actual_trips,
    mt.total_target_trips As target_trips,
CASE 
    WHEN count(ft.trip_id) > mt.total_target_trips
    THEN "Above Target" ELSE "Below Target" END AS Performance_status,
    CONCAT(ROUND(((COUNT(ft.trip_id)-mt.total_target_trips) /mt.total_target_trips)*100,2)," %") AS pct_difference
FROM 
    targets_db.monthly_target_trips mt JOIN trips_db.fact_trips ft
ON 
    mt.city_id = ft.city_id
WHERE monthname(mt.month) = monthname(ft.date)
GROUP BY 
     city_id, month_name
ORDER BY mt.month
)
SELECT 
	dc.city_name AS City_name, 
    tc.month_name, 
    tc.actual_trips, 
    tc.target_trips, 
    tc.Performance_status,
    tc.pct_difference 
FROM trips_count tc JOIN trips_db.dim_city dc 
ON 
    tc.city_id = dc.city_id
;

  ----------------------------------------------------------------------
-- Business Request - 3: City-Level Repeat Passenger Trip Frequency Report
   
   WITH passenger_cnt AS ( 
    SELECT 
    city_id, 
    trip_count,  
    SUM(repeat_passenger_count) AS passenger_count
    FROM 
    trips_db.dim_repeat_trip_distribution 
    GROUP BY city_id, trip_count
    ),
    
    repeat_trip AS (
    SELECT 
    city_id, 
    trip_count, 
    passenger_count, 
    CONCAT(CAST((passenger_count/SUM(passenger_count) OVER (PARTITION BY city_id))*100 AS DECIMAL(6,2)),"%") AS pct_contribution
    FROM passenger_cnt
    GROUP BY city_id, trip_count
    )
    
    SELECT
    dc.city_name,
    MAX(CASE WHEN trip_count = "2-Trips" THEN pct_contribution ELSE 0 END) AS "2-Trips",
    MAX(CASE WHEN trip_count = "3-Trips" THEN pct_contribution ELSE 0 END) AS "3-Trips",
    MAX(CASE WHEN trip_count = "4-Trips" THEN pct_contribution ELSE 0 END) AS "4-Trips",
    MAX(CASE WHEN trip_count = "5-Trips" THEN pct_contribution ELSE 0 END) AS "5-Trips",
    MAX(CASE WHEN trip_count = "6-Trips" THEN pct_contribution ELSE 0 END) AS "6-Trips",
    MAX(CASE WHEN trip_count = "7-Trips" THEN pct_contribution ELSE 0 END) AS "7-Trips",
    MAX(CASE WHEN trip_count = "8-Trips" THEN pct_contribution ELSE 0 END) AS "8-Trips",
    MAX(CASE WHEN trip_count = "9-Trips" THEN pct_contribution ELSE 0 END) AS "9-Trips",
    MAX(CASE WHEN trip_count = "10-Trips" THEN pct_contribution ELSE 0 END) AS "10-Trips"
    FROM 
    repeat_trip rt JOIN trips_db.dim_city dc 
    ON
    rt.city_id = dc.city_id
    GROUP BY city_name
    ;


--------------------------------------------------------------------------------------------------------------

-- Business Request-4: Identify the cities with Highest and Lowest Total New Passengers 

WITH new_passenger AS (
SELECT 
dc.city_name, 
SUM(fs.new_passengers) AS total_new_Passengers ,
RANK() OVER(ORDER BY SUM(fs.new_passengers) DESC) AS Rank_desc,
RANK() OVER(ORDER BY SUM(fs.new_passengers) ASC) AS Rank_asc
FROM 
trips_db.fact_passenger_summary fs JOIN trips_db.dim_city dc 
ON 
fs.city_id = dc.city_id
GROUP BY dc.city_id
ORDER BY total_new_Passengers DESC)

SELECT 
city_name, 
total_new_Passengers, 
CASE 
WHEN Rank_desc <= 3 THEN "Top 3"
WHEN Rank_asc <= 3 THEN "Bottom 3"
END AS city_category
FROM new_passenger
WHERE Rank_desc <= 3 or Rank_asc <= 3
;

---------------------------------------------------------------------------------------------------

-- Business Request-5: Identify the Month with Highest Revenue for ach city 

WITH revenue AS (
SELECT 
dc.city_name, 
ft.city_id,
monthname(date) AS month_name,
sum(ft.fare_amount) AS revenue
FROM trips_db.fact_trips ft JOIN trips_db.dim_city dc 
ON ft.city_id = dc.city_id
GROUP BY dc.city_name, monthname(date)
),

highest_revenue AS (
SELECT 
city_name, 
month_name AS highest_revenue_month,
revenue,
CONCAT(ROUND(revenue/SUM(revenue) OVER(PARTITION BY city_name) *100,2),"%") AS pct_contribution,
RANK() OVER(PARTITION BY city_name ORDER BY revenue DESC) AS rn 
FROM revenue
)
SELECT city_name , highest_revenue_month, revenue , pct_contribution
FROM highest_revenue 
WHERE rn =1
;

----------------------------------------------------------------------------------------------------------------
/*
Business Request -6: Repeat Passenger Rate Analysis*/
-- By City and Month Level
SELECT   
dc.city_name,
monthname(fs.month) AS month,
SUM(fs.total_passengers) AS total_passengers,
SUM(fs.repeat_passengers) AS repeat_passengers,
CONCAT(ROUND(SUM(fs.repeat_passengers)/SUM(fs.total_passengers) *100,2),"%") AS monthly_repeat_passenger_rate
FROM 
trips_db.fact_passenger_summary fs JOIN trips_db.dim_city dc 
ON fs.city_id = dc.city_id
GROUP BY dc.city_name, month
;

-- by city

SELECT   
dc.city_name,
SUM(fs.total_passengers) AS total_passengers,
SUM(fs.repeat_passengers) AS repeat_passengers,
CONCAT(ROUND(SUM(fs.repeat_passengers)/SUM(fs.total_passengers) *100,2),"%") AS city_repeat_passenger_rate
FROM 
trips_db.fact_passenger_summary fs JOIN trips_db.dim_city dc 
ON fs.city_id = dc.city_id
GROUP BY dc.city_name
;