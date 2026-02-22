-- FMCG Sales Data 2022 - 2024 Analysis

#Dataset
SELECT * 
FROM fmcg_sales2;


#1 WEEKLY SALES TREND 

-- Weekly Sales per Brand per Channel

SELECT year(`date`) AS Year,
	week(`date`) AS Week,
	brand, 
    `channel`, 
    sum(units_sold) AS Total_Unitsold
FROM fmcg_sales2
GROUP BY year(`date`), week(`date`),
brand, `channel`
ORDER BY brand, year, week DESC
;

-- Rank Weekly Sales per Brand

WITH Weekly_sales AS 
(
SELECT brand, 
	year(`date`) AS Year, 
	week(`date`) AS Week, 
	sum(units_sold) AS Total_Unitsold
FROM fmcg_sales2
GROUP BY brand, year(`date`), week(`date`)
)

SELECT *
FROM (
	SELECT *, 
		RANK() OVER (PARTITION BY brand ORDER BY Total_Unitsold DESC) As Ranking
        FROM Weekly_sales
)t
WHERE Ranking = 1;

-- Most contributed Channel on the Peak Week

WITH Weekly_Channel AS 
(
SELECT brand, 
	year(`date`) AS Year, 
	week(`date`) AS Week, 
	`channel`,
	sum(units_sold) AS Total_Unitsold
FROM fmcg_sales2
GROUP BY brand, year(`date`), week(`date`), `channel`
),

Ranked AS ( 
SELECT *, 
		RANK() OVER (PARTITION BY brand ORDER BY Total_Unitsold DESC) AS Ranking
        FROM Weekly_Channel
)

SELECT *
From Ranked
WHERE Ranking = 1;


#2 PROMOTION UPLIFT ANALYSIS

-- To quantify the sales uplift attribution to promotion, relative to the baseline demand

SELECT sku, 
	brand,
	AVG(CASE WHEN promotion_flag = 0 THEN units_sold END) AS baseline_qty,
	AVG(CASE WHEN promotion_flag = 1 THEN units_sold END) AS promo_qty,
	(AVG(CASE WHEN promotion_flag = 1 THEN units_sold END) - 
	AVG(CASE WHEN promotion_flag = 0 THEN units_sold END)) AS uplift_qty,
ROUND(
	((AVG(CASE WHEN promotion_flag = 1 THEN units_sold END) - 
	AVG(CASE WHEN promotion_flag = 0 THEN units_sold END))/
    AVG(CASE WHEN promotion_flag = 0 THEN units_sold END)*100), 2
) AS uplift_percent

FROM fmcg_sales2
GROUP BY sku, brand
ORDER BY uplift_percent DESC
;


#3 PRICE ELASTICITY CHECK

-- To measure demand sensitivity to pricing adjustments 

SELECT sku, 
	brand,
	year(`date`) AS Year,
	avg(price_unit) AS Avg_price, 
	sum(units_sold) AS Total_Unitsold
FROM fmcg_sales2
GROUP BY sku, brand, year(`date`)
ORDER BY brand, year
;

WITH yearly_sales AS (
	SELECT sku, 
		brand,
		year(`date`) AS Year,
		avg(price_unit) AS Avg_price, 
		sum(units_sold) AS total_qty
	FROM fmcg_sales2
	GROUP BY sku, brand, Year
)

SELECT 
	a.sku,
    b.brand,
    a.year AS year_prev,
    b.year AS year_curr,
    a.avg_price AS price_prev,
    b.avg_price AS price_curr,
    a.total_qty AS qty_prev,
    b.total_qty AS qty_curr,
    ROUND(
    ((b.total_qty - a.total_qty) / a.total_qty * 100), 2
    ) AS pct_change_qty,
    ROUND( 
    ((b.avg_price - a.avg_price) / a.avg_price * 100), 2
    ) AS pct_change_price,
    ROUND(
    ((b.total_qty - a.total_qty) / a.total_qty) / ((b.avg_price - a.avg_price) / a.avg_price), 2
    ) AS elasticity
    
FROM yearly_sales a
JOIN yearly_sales b 
	ON a.sku = b.sku AND a.year = b.year - 1
    ORDER BY elasticity DESC
    ;
    


#4 LOST STOCK DETECTION (Stock = 0)
	-- To identify potential lost sales due to stockouts (Out-of-Stock situations)
    
-- BASIC
SELECT
	sku, 
    brand,
    COUNT(*) AS stockout_days
FROM fmcg_sales2
WHERE stock_available = 0 
GROUP BY sku, brand
ORDER BY stockout_days DESC
;

-- Stockout Rate per brand
SELECT sku, 
	brand,
    COUNT(CASE WHEN stock_available = 0 THEN 1 END) AS stockout_days,
    COUNT(*) AS total_days,
    ROUND(
		COUNT(CASE WHEN stock_available = 0 THEN 1 END) * 100 / COUNT(*),
        2
        ) AS stockout_rate_pct
FROM fmcg_sales2
GROUP BY sku, brand
ORDER BY stockout_rate_pct DESC
;

-- Stockout Rate per brand and channel
SELECT brand,
		`channel`,
    COUNT(CASE WHEN stock_available = 0 THEN 1 END) AS stockout_days
FROM fmcg_sales2
GROUP BY brand, `channel`
ORDER BY stockout_days DESC
;    



#5 New SKU 2024 Performance
	-- Identification a new SKU on the First year 2024

SELECT 
	sku,
    brand,
    MIN(YEAR(`date`)) AS first_year
FROM fmcg_sales2
GROUP BY sku, brand
HAVING MIN(YEAR(`date`)) = 2024
;
-- there is no a new sku


#6 CHANNEL MIX SHIFT

-- Channel representation as of yearly based on yearly total sales

SELECT
	`channel`,
	YEAR(`date`) AS year,
	SUM(units_sold) AS total_qty
FROM fmcg_sales2
GROUP BY `channel`, YEAR(`date`)
ORDER BY year, total_qty DESC
;

-- Channel representation as of yearly based on yearly total sales (In percentage)

WITH yearly_total AS (
	SELECT
	YEAR(`date`) AS year,
	SUM(units_sold) AS total_year_qty
    FROM fmcg_sales2
    GROUP BY YEAR(`date`) 
)

SELECT 
	s.`channel`, 
    YEAR(s.`date`) AS year,
	SUM(s.units_sold) AS channel_qty,
    ROUND(SUM(s.units_sold) * 100.0 / y.total_year_qty, 2) AS channel_share_pct
FROM fmcg_sales2 s 
JOIN yearly_total y ON YEAR(s.`date`) = y.year
GROUP BY s.`channel`, YEAR(s.`date`), y.total_year_qty
ORDER BY year, channel_share_pct DESC
;

-- Channel representation as of yearly based on yearly total sales Per brand channel

SELECT 
	brand,
    `channel`,
    YEAR(`date`) AS year,
    SUM(units_sold) AS total_qty
FROM fmcg_sales2
GROUP BY brand, `channel`, YEAR(`date`)
ORDER BY brand, year, total_qty DESC
;    



#7 REGIONAL SEASONALITY 
	-- Analyze seasonal trend each region
SELECT 
	region,
    YEAR (`date`) AS year,
    MONTH (`date`)AS month,
    SUM(units_sold) AS total_qty
FROM fmcg_sales2
GROUP BY region, YEAR(`date`), MONTH(`date`)
ORDER BY region, year, month
;

-- Annual Market Share Regional 
WITH yearly_total AS (
	SELECT
	YEAR(`date`) AS year,
	SUM(units_sold) AS total_year_qty
    FROM fmcg_sales2
    GROUP BY YEAR(`date`) 
)

SELECT 
	s.region,
    YEAR(s.`date`) AS year,
    SUM(units_sold) AS region_qty,
    ROUND(SUM(s.units_sold) * 100 / y.total_year_qty, 2) AS region_share_pct
FROM fmcg_sales2 s
JOIN yearly_total y ON Year(s.`date`) = y.year
GROUP BY s.region, YEAR(s.`date`), y.total_year_qty
ORDER BY year, region_share_pct DESC
;    
    
-- Detect Regional Seasonality Pettern

SELECT
	region,
    MONTH(`date`) AS month,
    SUM(units_sold) AS monthly_qty
FROM fmcg_sales2
GROUP BY region, MONTH(`date`)
ORDER BY region, month
;



#8 Pack Type Behaviour  
-- Evaluate how pack types influence responsiveness to sales performance

SELECT 
	pack_type,
    promotion_flag,
    SUM(units_sold) AS total_qty
FROM fmcg_sales2
GROUP BY pack_type, promotion_flag
ORDER BY pack_type, promotion_flag
;

-- Uplift per Pack Type 

SELECT pack_type,
	AVG(CASE WHEN promotion_flag = 0 THEN units_sold END) AS baseline_qty,
	AVG(CASE WHEN promotion_flag = 1 THEN units_sold END) AS promo_qty,
	ROUND(
	((AVG(CASE WHEN promotion_flag = 1 THEN units_sold END) - 
	AVG(CASE WHEN promotion_flag = 0 THEN units_sold END))/
    AVG(CASE WHEN promotion_flag = 0 THEN units_sold END)*100), 2
) AS uplift_percent

FROM fmcg_sales2
GROUP BY pack_type
ORDER BY uplift_percent DESC
;

-- Uplift per Pack Type breakdown per channel
-- channel mana yang paling responsive per pack type

SELECT pack_type,
	`channel`,
	AVG(CASE WHEN promotion_flag = 0 THEN units_sold END) AS baseline_qty,
	AVG(CASE WHEN promotion_flag = 1 THEN units_sold END) AS promo_qty,
	ROUND(
	((AVG(CASE WHEN promotion_flag = 1 THEN units_sold END) - 
	AVG(CASE WHEN promotion_flag = 0 THEN units_sold END))/
    AVG(CASE WHEN promotion_flag = 0 THEN units_sold END)*100), 2
) AS uplift_percent

FROM fmcg_sales2
GROUP BY pack_type, `channel`
ORDER BY uplift_percent DESC
;



#9 Delivery Performance & Impact on Stock / Sales

-- Assess the impact of delivery lead times on stockouts

SELECT 
	sku, 
    brand, 
    AVG(delivery_days) AS avg_delivery_days,
    COUNT( CASE WHEN stock_available = 0 THEN 1 END) AS stockout_days
FROM fmcg_sales2
GROUP BY sku, brand
ORDER BY stockout_days DESC
;

-- Delivery Qty vs Stockout

SELECT 
	sku, 
    brand, 
    AVG(delivered_qty) AS avg_delivery_qty,
    COUNT( CASE WHEN stock_available = 0 THEN 1 END) AS stockout_days
FROM fmcg_sales2
GROUP BY sku, brand
ORDER BY stockout_days DESC
;


