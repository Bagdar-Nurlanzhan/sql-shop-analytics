-- Block C: Trends and rankings (Questions 11-15)
SET search_path TO shop;

-- Question 11: Month-over-month revenue growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(i.quantity * i.unit_price)          AS revenue
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY 1
)
SELECT month,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS growth_pct
FROM monthly
ORDER BY month;

-- Question 12: Running revenue total within each year
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(i.quantity * i.unit_price)          AS revenue
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY 1
)
SELECT month,
       revenue,
       SUM(revenue) OVER (PARTITION BY EXTRACT(YEAR FROM month)
                          ORDER BY month) AS ytd_revenue
FROM monthly
ORDER BY month;

-- Question 13: Top 3 products by revenue in each category
WITH product_revenue AS (
    SELECT c.category_name,
           p.product_name,
           SUM(i.quantity * i.unit_price) AS revenue
    FROM order_items i
    JOIN orders o     ON o.order_id = i.order_id
    JOIN products p   ON p.product_id = i.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE o.status = 'completed'
    GROUP BY c.category_name, p.product_id, p.product_name
),
ranked AS (
    SELECT category_name,
           product_name,
           revenue,
           ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS rank_in_category
    FROM product_revenue
)
SELECT category_name, rank_in_category, product_name, revenue
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category_name, rank_in_category;

-- Question 14a: Revenue, profit and margin by category
WITH category_stats AS (
    SELECT c.category_name,
           SUM(i.quantity * i.unit_price)             AS revenue,
           SUM(i.quantity * (i.unit_price - p.cost))  AS profit
    FROM order_items i
    JOIN orders o     ON o.order_id = i.order_id
    JOIN products p   ON p.product_id = i.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE o.status = 'completed'
    GROUP BY c.category_name
)
SELECT category_name,
       revenue,
       profit,
       ROUND(100.0 * profit / revenue, 1) AS margin_pct
FROM category_stats
ORDER BY margin_pct DESC;

-- Question 14b: Categories with margin below the store average
-- (store average = total profit / total revenue, not the mean of category percentages)
WITH category_stats AS (
    SELECT c.category_name,
           SUM(i.quantity * i.unit_price)             AS revenue,
           SUM(i.quantity * (i.unit_price - p.cost))  AS profit
    FROM order_items i
    JOIN orders o     ON o.order_id = i.order_id
    JOIN products p   ON p.product_id = i.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE o.status = 'completed'
    GROUP BY c.category_name
)
SELECT category_name,
       ROUND(100.0 * profit / revenue, 1) AS margin_pct
FROM category_stats
WHERE profit / revenue < (SELECT SUM(profit) / SUM(revenue) FROM category_stats);

-- Question 15a: Share of cancelled and returned orders by acquisition channel
SELECT c.channel,
       COUNT(*)                                                AS orders,
       COUNT(*) FILTER (WHERE o.status = 'cancelled')          AS cancelled,
       COUNT(*) FILTER (WHERE o.status = 'returned')           AS returned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.status IN ('cancelled', 'returned'))
             / COUNT(*), 1)                                    AS problem_pct
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.channel
ORDER BY problem_pct DESC;

-- Question 15b: Same by city (cities with at least 30 orders)
SELECT COALESCE(c.city, 'Not specified')                        AS city,
       COUNT(*)                                                AS orders,
       COUNT(*) FILTER (WHERE o.status = 'cancelled')          AS cancelled,
       COUNT(*) FILTER (WHERE o.status = 'returned')           AS returned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.status IN ('cancelled', 'returned'))
             / COUNT(*), 1)                                    AS problem_pct
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY 1
HAVING COUNT(*) >= 30
ORDER BY problem_pct DESC;
