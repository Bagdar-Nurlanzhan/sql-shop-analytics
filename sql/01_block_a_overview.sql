-- Block A: Store overview (Questions 1-5)
-- Run in the sql_practice database after 00_setup.sql
SET search_path TO shop;

-- Question 1: Store summary (completed orders only)
SELECT COUNT(DISTINCT o.order_id)      AS orders,
       COUNT(DISTINCT o.customer_id)   AS buyers,
       SUM(i.quantity * i.unit_price)  AS revenue,
       ROUND(SUM(i.quantity * i.unit_price) / COUNT(DISTINCT o.order_id)) AS avg_check,
       ROUND(COUNT(i.order_item_id)::numeric / COUNT(DISTINCT o.order_id), 2) AS items_per_order
FROM orders o
JOIN order_items i ON i.order_id = o.order_id
WHERE o.status = 'completed';

-- Question 2: Revenue by month
SELECT DATE_TRUNC('month', o.order_date)::date AS month,
       COUNT(DISTINCT o.order_id)              AS orders,
       SUM(i.quantity * i.unit_price)          AS revenue
FROM orders o
JOIN order_items i ON i.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY 1
ORDER BY 1;

-- Question 3: Revenue by category and share of total
SELECT c.category_name                                  AS category,
       SUM(i.quantity * i.unit_price)                   AS revenue,
       ROUND(100 * SUM(i.quantity * i.unit_price)
             / SUM(SUM(i.quantity * i.unit_price)) OVER (), 1) AS pct
FROM order_items i
JOIN orders o     ON o.order_id = i.order_id
JOIN products p   ON p.product_id = i.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.status = 'completed'
GROUP BY 1
ORDER BY SUM(i.quantity * i.unit_price) DESC;

-- Question 4: Top 10 products by revenue
SELECT p.product_name                  AS product,
       c.category_name                 AS category,
       SUM(i.quantity * i.unit_price)  AS revenue,
       SUM(i.quantity)                 AS units_sold,
       COUNT(DISTINCT o.order_id)      AS orders_count
FROM order_items i
JOIN orders o     ON o.order_id = i.order_id
JOIN products p   ON p.product_id = i.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.status = 'completed'
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY revenue DESC
LIMIT 10;

-- Question 5: Products that never sold (way 1: LEFT JOIN + IS NULL)
SELECT p.product_name AS product,
       c.category_name AS category,
       p.price
FROM products p
JOIN categories c ON c.category_id = p.category_id
LEFT JOIN order_items i ON i.product_id = p.product_id
WHERE i.product_id IS NULL;

-- Question 5: Products that never sold (way 2: NOT EXISTS)
SELECT p.product_name AS product,
       c.category_name AS category,
       p.price
FROM products p
JOIN categories c ON c.category_id = p.category_id
WHERE NOT EXISTS (
    SELECT 1 FROM order_items i WHERE i.product_id = p.product_id
);