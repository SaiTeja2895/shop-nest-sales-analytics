-- ============================================================
-- SHOP NEST E-COMMERCE SALES ANALYTICS
-- SQL Analysis Script
-- Database: PostgreSQL-compatible analytical SQL
--
-- Tables:
--   customers
--   products
--   orders
--   order_items
--
-- NOTE:
-- This script is written for PostgreSQL. The validation version
-- below uses SQLite-compatible equivalents where necessary.
-- ============================================================

-- ============================================================
-- 1. DATA QUALITY CHECKS
-- ============================================================

-- 1.1 Row counts
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

-- 1.2 Duplicate customer IDs
SELECT customer_id, COUNT(*) AS duplicate_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 1.3 Duplicate product IDs
SELECT product_id, COUNT(*) AS duplicate_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- 1.4 Duplicate order IDs
SELECT order_id, COUNT(*) AS duplicate_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 1.5 Missing values in important customer fields
SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN signup_date IS NULL THEN 1 ELSE 0 END) AS missing_signup_date,
    SUM(CASE WHEN customer_segment IS NULL THEN 1 ELSE 0 END) AS missing_customer_segment
FROM customers;

-- 1.6 Missing values in order fields
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS missing_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS missing_order_date
FROM orders;

-- 1.7 Check invalid product pricing
SELECT *
FROM products
WHERE unit_price <= 0
   OR cost_price < 0
   OR cost_price > unit_price;

-- 1.8 Check invalid order item values
SELECT *
FROM order_items
WHERE quantity <= 0
   OR unit_price <= 0
   OR discount < 0
   OR discount > 1;


-- ============================================================
-- 2. REVENUE & SALES KPIs
-- ============================================================

-- 2.1 Total revenue
SELECT ROUND(SUM(net_sales), 2) AS total_revenue
FROM order_items;

-- 2.2 Total gross sales
SELECT ROUND(SUM(gross_sales), 2) AS total_gross_sales
FROM order_items;

-- 2.3 Total discount
SELECT ROUND(SUM(discount_amount), 2) AS total_discount
FROM order_items;

-- 2.4 Total orders
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM orders;

-- 2.5 Total customers
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM customers;

-- 2.6 Total units sold
SELECT SUM(quantity) AS total_units_sold
FROM order_items;

-- 2.7 Average order value
SELECT
    ROUND(SUM(oi.net_sales) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id;

-- 2.8 Profit and profit margin
SELECT
    ROUND(SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price)), 2) AS total_profit,
    ROUND(
        100.0 * SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price))
        / NULLIF(SUM(oi.net_sales), 0),
        2
    ) AS profit_margin_pct
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id;


-- ============================================================
-- 3. MONTHLY SALES TREND
-- ============================================================

SELECT
    SUBSTR(o.order_date, 1, 7) AS sales_month,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.quantity) AS units_sold
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY SUBSTR(o.order_date, 1, 7)
ORDER BY sales_month;


-- ============================================================
-- 4. SALES BY CATEGORY
-- ============================================================

SELECT
    p.category,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    SUM(oi.quantity) AS units_sold,
    COUNT(DISTINCT oi.order_id) AS orders
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY revenue DESC;


-- ============================================================
-- 5. SALES BY SUB-CATEGORY
-- ============================================================

SELECT
    p.category,
    p.sub_category,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category, p.sub_category
ORDER BY revenue DESC;


-- ============================================================
-- 6. TOP 10 PRODUCTS BY REVENUE
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- 7. TOP 10 PRODUCTS BY PROFIT
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    ROUND(
        SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price)),
        2
    ) AS profit
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY profit DESC
LIMIT 10;


-- ============================================================
-- 8. CUSTOMER SEGMENT ANALYSIS
-- ============================================================

SELECT
    c.customer_segment,
    COUNT(DISTINCT c.customer_id) AS customers,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    ROUND(AVG(oi.net_sales), 2) AS average_line_value
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_segment
ORDER BY revenue DESC;


-- ============================================================
-- 9. TOP 10 CUSTOMERS BY REVENUE
-- ============================================================

SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.city,
    c.state,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.net_sales), 2) AS revenue
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.city,
    c.state
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- 10. SALES BY CITY
-- ============================================================

SELECT
    c.city,
    c.state,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT c.customer_id) AS customers
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city, c.state
ORDER BY revenue DESC;


-- ============================================================
-- 11. SALES BY PAYMENT METHOD
-- ============================================================

SELECT
    o.payment_method,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    ROUND(SUM(oi.net_sales) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY o.payment_method
ORDER BY revenue DESC;


-- ============================================================
-- 12. ORDER STATUS ANALYSIS
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS order_pct
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- ============================================================
-- 13. CANCELLATION & RETURN RATE
-- ============================================================

SELECT
    ROUND(
        100.0 * SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,
    ROUND(
        100.0 * SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS return_rate_pct
FROM orders;


-- ============================================================
-- 14. CATEGORY PROFITABILITY
-- ============================================================

SELECT
    p.category,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    ROUND(
        SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price)),
        2
    ) AS profit,
    ROUND(
        100.0 *
        SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price))
        / NULLIF(SUM(oi.net_sales), 0),
        2
    ) AS profit_margin_pct
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY profit DESC;


-- ============================================================
-- 15. MONTH-OVER-MONTH REVENUE
-- ============================================================

WITH monthly_sales AS (
    SELECT
        SUBSTR(o.order_date, 1, 7) AS sales_month,
        SUM(oi.net_sales) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'Delivered'
    GROUP BY SUBSTR(o.order_date, 1, 7)
)
SELECT
    sales_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        LAG(revenue) OVER (ORDER BY sales_month),
        2
    ) AS previous_month_revenue,
    ROUND(
        100.0 *
        (revenue - LAG(revenue) OVER (ORDER BY sales_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY sales_month), 0),
        2
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY sales_month;


-- ============================================================
-- 16. CUSTOMER REVENUE RANKING
-- ============================================================

WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        SUM(oi.net_sales) AS revenue
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'Delivered'
    GROUP BY c.customer_id, c.customer_name, c.customer_segment
)
SELECT
    customer_id,
    customer_name,
    customer_segment,
    ROUND(revenue, 2) AS revenue,
    DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM customer_sales
ORDER BY revenue_rank;


-- ============================================================
-- 17. PRODUCT PERFORMANCE CLASSIFICATION
-- ============================================================

WITH product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.net_sales) AS revenue,
        SUM(
            oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price)
        ) AS profit
    FROM products p
    JOIN order_items oi
        ON p.product_id = oi.product_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'Delivered'
    GROUP BY p.product_id, p.product_name, p.category
)
SELECT
    product_id,
    product_name,
    category,
    ROUND(revenue, 2) AS revenue,
    ROUND(profit, 2) AS profit,
    CASE
        WHEN revenue >= 50000 AND profit >= 10000 THEN 'High Performer'
        WHEN revenue >= 25000 THEN 'Medium Performer'
        ELSE 'Low Performer'
    END AS performance_group
FROM product_sales
ORDER BY revenue DESC;


-- ============================================================
-- 18. CUSTOMER PURCHASE FREQUENCY
-- ============================================================

SELECT
    c.customer_segment,
    ROUND(
        COUNT(DISTINCT o.order_id) * 1.0
        / COUNT(DISTINCT c.customer_id),
        2
    ) AS orders_per_customer
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_segment
ORDER BY orders_per_customer DESC;


-- ============================================================
-- 19. HIGH-REVENUE / LOW-MARGIN PRODUCTS
-- ============================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    ROUND(SUM(oi.net_sales), 2) AS revenue,
    ROUND(
        SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price)),
        2
    ) AS profit,
    ROUND(
        100.0 *
        SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price))
        / NULLIF(SUM(oi.net_sales), 0),
        2
    ) AS profit_margin_pct
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_id, p.product_name, p.category
HAVING SUM(oi.net_sales) > 10000
   AND (
        100.0 *
        SUM(oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price))
        / NULLIF(SUM(oi.net_sales), 0)
   ) < 20
ORDER BY revenue DESC;


-- ============================================================
-- 20. FINAL BUSINESS SUMMARY
-- ============================================================

WITH metrics AS (
    SELECT
        SUM(oi.net_sales) AS revenue,
        SUM(oi.quantity) AS units_sold,
        COUNT(DISTINCT o.order_id) AS orders,
        COUNT(DISTINCT o.customer_id) AS purchasing_customers,
        SUM(
            oi.quantity * (oi.unit_price * (1 - oi.discount) - p.cost_price)
        ) AS profit
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'Delivered'
)
SELECT
    ROUND(revenue, 2) AS total_revenue,
    units_sold,
    orders,
    purchasing_customers,
    ROUND(revenue / NULLIF(orders, 0), 2) AS average_order_value,
    ROUND(profit, 2) AS total_profit,
    ROUND(100.0 * profit / NULLIF(revenue, 0), 2) AS profit_margin_pct
FROM metrics;
