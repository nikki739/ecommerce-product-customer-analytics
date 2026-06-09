 -- ==========================================================
 --  PRODUCT ANALYTICS PROJECT
 --  Dataset: Olist E-Commerce Dataset
 --  Database: PostgreSQL

 --  Objective:
 --  Analyze revenue, customer behavior, product performance,
 --  and customer retention using SQL.
 -- ========================================================== 

-- ==========================================================
-- DATA VALIDATION & EXPLORATION
-- ========================================================== 

-- Checking total records in each table
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM payments;
SELECT COUNT(*) FROM sellers;
SELECT COUNT(*) FROM reviews;

-- Preview sample records
SELECT * FROM customers LIMIT 5;
SELECT * FROM products LIMIT 5;
SELECT * FROM orders LIMIT 5;
SELECT * FROM order_items LIMIT 5;
SELECT * FROM payments LIMIT 5;
SELECT * FROM sellers LIMIT 5;
SELECT * FROM reviews LIMIT 5;

-- ==========================================================
-- CUSTOMER VALIDATION
-- ========================================================== 

-- Counting unique customers, orders, and products
SELECT 
    COUNT(DISTINCT customer_id) customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- Unique customers are around 96K, having an order count of 99K

SELECT 
    COUNT(*) total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM orders;

SELECT 
    COUNT(*) total_rows,
    COUNT(DISTINCT product_id) AS unique_products
FROM products;

-- Identifying customers with multiple orders
SELECT 
    c.customer_unique_id, COUNT(*) AS total_orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(*) > 1
ORDER BY total_orders DESC
LIMIT 10;

-- ========================================================== 
-- Business KPI ANALYSIS
-- ========================================================== 

-- Total Revenue
SELECT ROUND(SUM(payment_value),2) as total_revenue
FROM payments;

-- Total orders
SELECT COUNT(*) as total_orders 
FROM orders;

-- Total customers
SELECT COUNT(DISTINCT customer_unique_id) as total_customers
FROM customers;

-- Average order value (AOV)
SELECT ROUND(SUM(payment_value) / COUNT(DISTINCT order_id),2) as average_order_value
FROM payments;

-- Average items per order
SELECT ROUND(COUNT(*):: numeric / COUNT(DISTINCT order_id),2) as avg_item_per_order
FROM order_items;

-- ========================================================== 
-- DATA QUALITY CHECKS
-- ========================================================== 

-- Checking delivery-related missing values
SELECT 
	COUNT(*) as total_orders,
	COUNT(order_approved_at) as approved,
	COUNT(order_delivered_carrier_date) as carrier_date,
	COUNT(order_delivered_customer_date) as delivered_date
FROM orders;

-- Order status distribution
SELECT 
    order_status, COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Missing product categories
SELECT COUNT(*) FROM products
WHERE product_category_name IS NULL;

-- Missing review comments
SELECT COUNT(*) FROM reviews
WHERE review_comment_message IS NULL;

-- ========================================================== 
-- REVENUE ANALYSIS
-- ========================================================== 

-- Monthly revenue trend
SELECT 
	DATE_TRUNC('month', o.order_purchase_timestamp) as month,
	ROUND(SUM(p.payment_value),2) as revenue
FROM orders o 
JOIN payments p on o.order_id = p.order_id
GROUP BY 1
ORDER BY 1;

-- Peak revenue months
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;

-- ========================================================== 
-- CUSTOMER ANALYTICS
-- ========================================================== 

-- New vs Repeat customers
WITH customer_orders AS (
	SELECT c.customer_unique_id,
		   COUNT(DISTINCT o.order_id) as total_orders
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
	GROUP BY 1
)
SELECT 
	CASE WHEN total_orders = 1 THEN 'One-Time Customer'
		 ELSE 'Repeat Customer'
	END as customer_type,
	COUNT(*) AS customers
FROM customer_orders
GROUP BY customer_type;

-- Repeat Customer Rate
WITH customer_orders AS (
	SELECT c.customer_unique_id,
		   COUNT(DISTINCT o.order_id) as total_orders
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
	GROUP BY 1
)
SELECT 
	COUNT(*) FILTER (WHERE total_orders > 1) as repeat_customers,
	COUNT(*) as total_customers,
	ROUND((COUNT(*) FILTER (WHERE total_orders > 1) * 100.0) / COUNT(*), 2) as repeat_customer_rate
FROM customer_orders;

-- Customer Order Frequency Distribution
WITH customer_orders AS (
	SELECT c.customer_unique_id,
		   COUNT(DISTINCT o.order_id) as total_orders
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
	GROUP BY 1
)
SELECT 
	total_orders, COUNT(*) AS customers
FROM customer_orders
GROUP BY total_orders
ORDER BY total_orders;

-- ==========================================================
-- PRODUCT ANALYTICS
-- ==========================================================

-- Top Categories by Units Sold
SELECT 
    t.product_category_name_english, COUNT(*) AS items_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY items_sold DESC
LIMIT 15;

-- Top Categories by Revenue
SELECT 
    t.product_category_name_english,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY revenue DESC
LIMIT 15;

-- Revenue Contribution %
WITH category_revenue AS(
	SELECT
		t.product_category_name_english,
		ROUND(SUM(oi.price),2) as revenue
	FROM order_items oi 
	JOIN products p ON oi.product_id = p.product_id
	JOIN category_name_translation t ON p.product_category_name = t.product_category_name
	GROUP BY t.product_category_name_english
)
SELECT 
	product_category_name_english,
	ROUND(revenue * 100.0 / SUM(revenue) OVER(), 2) as revenue_percentage
FROM category_revenue
ORDER BY revenue DESC
LIMIT 10;

-- ==========================================================
-- RETENTION ANALYSIS
-- ==========================================================

-- Average Days Between Purchases
WITH customer_orders AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		MAX(o.order_purchase_timestamp) AS last_order_date,
		COUNT(DISTINCT o.order_id) AS total_orders
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
	GROUP BY c.customer_unique_id
)
SELECT 
	ROUND(AVG(EXTRACT(DAY FROM(last_order_date - first_order_date))),2) AS avg_days_between_first_and_last_purchase
FROM customer_orders
WHERE total_orders > 1;

-- Customer Acquisition Trend
WITH first_purchase AS(
	SELECT 
		c.customer_unique_id,
		MIN(DATE_TRUNC('month', o.order_purchase_timestamp)) AS first_order_month
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
	GROUP BY c.customer_unique_id
)
SELECT 
	first_order_month, COUNT(*) as customers
FROM first_purchase
GROUP BY first_order_month
ORDER BY first_order_month;

-- ==========================================================
-- COHORT ANALYSIS
-- ==========================================================

-- Creating customer first purchase month table
WITH customer_months AS(
	SELECT 
		c.customer_unique_id,
		MIN(DATE_TRUNC('month', o.order_purchase_timestamp))::date AS order_month
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT * 
FROM customer_months
LIMIT 10;

-- Creating cohort table
WITH customer_months AS(
	SELECT 
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
)
SELECT 
	customer_unique_id,
	MIN(order_month) AS cohort_month
FROM customer_months
GROUP BY customer_unique_id
LIMIT 10;

-- Calculating Cohort index
WITH customer_months AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
),

cohort_table AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_unique_id
)
SELECT
    cm.customer_unique_id,
    ct.cohort_month,
    cm.order_month,

    (
        EXTRACT(YEAR FROM age(cm.order_month, ct.cohort_month))*12
        +
        EXTRACT(MONTH FROM age(cm.order_month, ct.cohort_month))
    ) AS cohort_index

FROM customer_months cm
JOIN cohort_table ct
ON cm.customer_unique_id = ct.customer_unique_id
LIMIT 20;

-- Building cohort matrix dataset
WITH customer_months AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
),

cohort_table AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_unique_id
),

cohort_data AS (
    SELECT
        cm.customer_unique_id,
        ct.cohort_month,
        cm.order_month,

        (
            EXTRACT(YEAR FROM age(cm.order_month, ct.cohort_month))*12
            +
            EXTRACT(MONTH FROM age(cm.order_month, ct.cohort_month))
        ) AS cohort_index

    FROM customer_months cm
    JOIN cohort_table ct ON cm.customer_unique_id = ct.customer_unique_id
)

SELECT
    cohort_month,
    cohort_index,
    COUNT(DISTINCT customer_unique_id) AS customers
FROM cohort_data
GROUP BY cohort_month, cohort_index
ORDER BY cohort_month, cohort_index;

-- ==========================================================
-- CUSTOMER LIFETIME VALUE
-- ==========================================================

-- Calculating average revenue generated per customer
SELECT 
	ROUND(SUM(p.payment_value)/ COUNT(DISTINCT c.customer_unique_id),2) as customer_lifetime_value
FROM payments p 
JOIN orders o ON p.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id;

-- ==========================================================
-- CUSTOMER REVENUE SEGMENTATION
-- ==========================================================

-- Revenue by customer type
WITH customer_revenue AS(
	SELECT
		c.customer_unique_id,
		COUNT(DISTINCT o.order_id) AS total_orders,
		SUM(p.payment_value) AS revenue
	FROM customers c
	JOIN orders o ON c.customer_id = o.customer_id
	JOIN payments p ON o.order_id = p.order_id
	GROUP BY c.customer_unique_id
)
SELECT 
	CASE WHEN total_orders = 1 THEN 'One-Time Customer'
		 ELSE 'Repeat Customer'
	END AS customer_type,
	COUNT(*) AS customers,
	ROUND(SUM(revenue),2) as total_revenue,
	ROUND(AVG(revenue),2) as avg_customer_revenue
FROM customer_revenue
GROUP BY customer_type;

-- Top revenue customers
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(p.payment_value) AS revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    ROUND(revenue,2) AS revenue
FROM customer_revenue
ORDER BY revenue DESC
LIMIT 20;

-- Revenue decile analysis
WITH customer_revenue AS(
	SELECT 
		c.customer_unique_id,
		SUM(p.payment_value) AS revenue
	FROM customers c 
	JOIN orders o ON c.customer_id = o.customer_id
	JOIN payments p ON o.order_id = p.order_id
	GROUP BY c.customer_unique_id
)
, ranked_customers AS(
SELECT 
	customer_unique_id,
	revenue,
	NTILE(10) OVER(ORDER BY revenue DESC) AS revenue_decile
FROM customer_revenue
)
SELECT 
	revenue_decile,
	COUNT(*) AS customers,
	ROUND(SUM(revenue),2) AS total_revenue
FROM ranked_customers
GROUP BY revenue_decile
ORDER BY revenue_decile;

-- ==========================================================
-- POWER BI REPORTING VIEWS
-- ==========================================================

-- Monthly revenue View
CREATE VIEW vw_monthly_revenue AS
SELECT 
	   DATE_TRUNC('month', o.order_purchase_timestamp)::date as month,
	   COUNT(DISTINCT o.order_id) AS orders,
	   ROUND(SUM(p.payment_value),2) AS revenue
FROM orders o 
JOIN payments p ON o.order_id = p.order_id
GROUP BY 1;

-- Customer acquisition View
CREATE VIEW vw_customer_acquisition AS 
WITH first_purchase AS(
	SELECT c.customer_unique_id,
		   MIN(DATE_TRUNC('month', o.order_purchase_timestamp))::date AS first_order_month
	FROM orders o 
	JOIN customers c ON o.customer_id = c.customer_id
	GROUP BY c.customer_unique_id
)
SELECT first_order_month,
	   COUNT(*) AS customers
FROM first_purchase
GROUP BY first_order_month;

-- Category Revenue View
CREATE VIEW vw_category_revenue AS
SELECT t.product_category_name_english,
	   COUNT(*) AS items_sold,
	   ROUND(SUM(oi.price),2) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english;

-- Cohort Analysis View
CREATE VIEW vw_cohort_analysis AS
WITH customer_months AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
)
,cohort_table AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_unique_id
)
,cohort_data AS (
    SELECT
        cm.customer_unique_id,
        ct.cohort_month,
        cm.order_month,
        (
            EXTRACT(YEAR FROM age(cm.order_month, ct.cohort_month))*12
            +
            EXTRACT(MONTH FROM age(cm.order_month, ct.cohort_month))
        ) AS cohort_index
    FROM customer_months cm
    JOIN cohort_table ct ON cm.customer_unique_id = ct.customer_unique_id
)
SELECT
    cohort_month,
    cohort_index,
    COUNT(DISTINCT customer_unique_id) AS customers
FROM cohort_data
GROUP BY cohort_month, cohort_index
ORDER BY cohort_month, cohort_index;



