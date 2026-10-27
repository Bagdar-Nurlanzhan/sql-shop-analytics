-- Block B: Customers (Questions 6-10)
-- Run in the sql_practice database after 00_setup.sql
SET search_path TO shop;

-- Question 6a: Customers without any orders (count and share of all customers)
SELECT COUNT(*) AS customers_no_orders,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customers), 1) AS pct
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.customer_id IS NULL;

-- Question 6b: Customers without orders, by acquisition channel
SELECT c.channel, COUNT(*) AS customers_no_orders
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.customer_id IS NULL
GROUP BY 1;

-- Question 6b: Customers without orders, by city (empty city shown as 'Not specified')
SELECT COALESCE(c.city, 'Not specified') AS city, COUNT(*) AS customers_no_orders
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.customer_id IS NULL
GROUP BY 1;

-- Question 7a: Top 10 customers by revenue
SELECT c.full_name AS customer,
       c.city,
       COUNT(DISTINCT o.order_id) AS orders_cnt,
       SUM(i.quantity * i.unit_price) AS revenue,
       ROUND(SUM(i.quantity * i.unit_price) / COUNT(DISTINCT o.order_id)) AS avg_check
FROM customers c
JOIN orders o      ON o.customer_id = c.customer_id
JOIN order_items i ON i.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY c.customer_id, c.full_name, c.city
ORDER BY revenue DESC
LIMIT 10;

-- Question 7b: Top 10 customers by revenue among those with at least 3 orders
SELECT c.full_name AS customer,
       c.city,
       COUNT(DISTINCT o.order_id) AS orders_cnt,
       SUM(i.quantity * i.unit_price) AS revenue,
       ROUND(SUM(i.quantity * i.unit_price) / COUNT(DISTINCT o.order_id)) AS avg_check
FROM customers c
JOIN orders o      ON o.customer_id = c.customer_id
JOIN order_items i ON i.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY c.customer_id, c.full_name, c.city
HAVING COUNT(DISTINCT o.order_id) >= 3
ORDER BY revenue DESC
LIMIT 10;

-- Question 8: Repeat purchases
WITH customer_orders AS (
    SELECT customer_id,
           COUNT(*) AS orders_cnt
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
)
SELECT COUNT(*)                                    AS buyers,
       COUNT(*) FILTER (WHERE orders_cnt >= 2)     AS repeat_buyers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders_cnt >= 2) / COUNT(*), 1) AS repeat_share_pct
FROM customer_orders;

-- Question 9: Customer activity segments as of 2026-09-28
WITH customer_stats AS (
    SELECT c.customer_id,
           MAX(o.order_date)                           AS last_order,
           COALESCE(SUM(i.quantity * i.unit_price), 0) AS revenue
    FROM customers c
    LEFT JOIN orders o      ON o.customer_id = c.customer_id AND o.status = 'completed'
    LEFT JOIN order_items i ON i.order_id = o.order_id
    GROUP BY c.customer_id
),
segments AS (
    SELECT customer_id,
           revenue,
           CASE
               WHEN last_order IS NULL THEN 'never purchased'
               WHEN DATE '2026-09-28' - last_order <= 30 THEN 'active'
               WHEN DATE '2026-09-28' - last_order <= 90 THEN 'cooling down'
               ELSE 'dormant'
           END AS segment
    FROM customer_stats
)
SELECT segment,
       COUNT(*)                                                 AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)       AS customers_pct,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS revenue_pct
FROM segments
GROUP BY segment
ORDER BY customers DESC;

-- Question 10: Time between first and second purchase (average and median, days)
WITH ordered AS (
    SELECT customer_id,
           order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn,
           LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS prev_date
    FROM orders
    WHERE status = 'completed'
)
SELECT COUNT(*)                                  AS customers,
       ROUND(AVG(order_date - prev_date), 1)     AS avg_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_date - prev_date) AS median_days
FROM ordered
WHERE rn = 2;