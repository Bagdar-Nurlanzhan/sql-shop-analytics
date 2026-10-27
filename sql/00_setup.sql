DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;
SET search_path TO shop;

SELECT setseed(0.42);   -- fix the random generator so everyone gets the same data

-- ---------- 1. Tables ----------
CREATE TABLE categories (
    category_id   SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
);


CREATE TABLE products (
    product_id   SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category_id  INT NOT NULL REFERENCES categories(category_id),
    price        NUMERIC(10, 2) NOT NULL,   -- current catalog price
    cost         NUMERIC(10, 2) NOT NULL    -- cost of one unit
);

CREATE TABLE customers (
    customer_id       SERIAL PRIMARY KEY,
    full_name         VARCHAR(100) NOT NULL,
    city              VARCHAR(50),           -- missing for some customers
    channel           VARCHAR(20) NOT NULL,  -- acquisition channel
    registration_date DATE NOT NULL
);

CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    order_date  DATE NOT NULL,
    status      VARCHAR(20) NOT NULL         -- completed / cancelled / returned
);

CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id      INT NOT NULL REFERENCES orders(order_id),
    product_id    INT NOT NULL REFERENCES products(product_id),
    quantity      INT NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10, 2) NOT NULL    -- price the item was actually sold at
);

-- ---------- 2. Categories and products ----------
INSERT INTO categories (category_name) VALUES
    ('Electronics'), ('Clothing'), ('Home & Kitchen'), ('Beauty'), ('Sports');

INSERT INTO products (product_name, category_id, price, cost) VALUES
    ('Smartphone Nova X',           1, 189000, 160000),
    ('Oversized Hoodie',            2,  14500,   6000),
    ('Immersion Blender',           3,  12900,   8000),
    ('Vitamin C Serum',             4,   7800,   2600),
    ('Running Shoes',               5,  32000,  18000),
    ('Wireless Headphones',         1,  24500,  17000),
    ('Straight Jeans',              2,  18900,   8500),
    ('Cookware Set (5 pcs)',        3,  27500,  17000),
    ('Moisturizing Face Cream',     4,   5900,   1800),
    ('Dumbbells 2x5 kg',            5,  15900,   9500),
    ('Laptop Air 14',               1, 425000, 385000),
    ('Mid-season Jacket',           2,  39900,  21000),
    ('Capsule Coffee Machine',      3,  58000,  41000),
    ('Repair Shampoo',              4,   3200,   1100),
    ('Yoga Mat',                    5,   8500,   3200),
    ('Smartwatch',                  1,  46000,  33000),
    ('Basic T-Shirt',               2,   4900,   1700),
    ('Upright Vacuum Cleaner',      3,  89000,  64000),
    ('Eau de Parfum 50 ml',         4,  21500,   9000),
    ('Exercise Bike',               5, 118000,  82000),
    ('Tablet 10"',                  1, 135000, 112000),
    ('Summer Dress',                2,  16500,   6800),
    ('Knife Set',                   3,   9900,   4100),
    ('Mascara',                     4,   4300,   1400),
    ('Resistance Bands Set',        5,   5600,   1900),
    ('65W Charger',                 1,  11800,   6900),
    ('City Sneakers',               2,  27900,  14500),
    ('Fleece Blanket',              3,   6800,   2700),
    ('Hair Mask',                   4,   6100,   2000),
    ('Treadmill',                   5, 245000, 180000);

-- ---------- 3. Customers (600) ----------
INSERT INTO customers (full_name, city, channel, registration_date)
SELECT
    (ARRAY['Aigerim','Daniyar','Maria','Yerlan','Assel','Timur','Dinara','Nurlan',
           'Aizhan','Bauyrzhan','Saltanat','Arman','Aliya','Marat','Zhanar','Sanzhar',
           'Anna','Dmitry','Madina','Ruslan','Kamila','Aidos','Olga','Yerzhan'])
        [(s.i - 1) % 24 + 1]
    || ' ' ||
    substr('ABCDEFGHIJKLMNOPQRSTUVWXY', ((s.i - 1) / 24) % 25 + 1, 1) || '.',
    CASE WHEN s.r_city < 0.03 THEN NULL
         WHEN s.r_city < 0.38 THEN 'Almaty'
         WHEN s.r_city < 0.63 THEN 'Astana'
         WHEN s.r_city < 0.75 THEN 'Shymkent'
         WHEN s.r_city < 0.85 THEN 'Karaganda'
         WHEN s.r_city < 0.93 THEN 'Aktobe'
         ELSE 'Pavlodar' END,
    CASE WHEN s.r_ch < 0.40 THEN 'organic'
         WHEN s.r_ch < 0.70 THEN 'ads'
         WHEN s.r_ch < 0.85 THEN 'referral'
         ELSE 'social' END,
    DATE '2025-01-01' + floor(s.r_reg * 623)::int
FROM (
    SELECT i, random() AS r_city, random() AS r_ch, random() AS r_reg
    FROM generate_series(1, 600) AS i
) AS s
ORDER BY 4, s.i;

-- ---------- 4. Orders (1600) ----------
-- Some customers buy a lot, some never buy at all.
INSERT INTO orders (customer_id, order_date, status)
SELECT c.customer_id,
       c.registration_date
           + floor(g.r_day * (DATE '2026-09-27' - c.registration_date + 1))::int,
       CASE WHEN g.r_status < 0.08 THEN 'cancelled'
            WHEN g.r_status < 0.12 THEN 'returned'
            ELSE 'completed' END
FROM (
    SELECT 1 + floor(power(random(), 1.4) * 600)::int AS customer_id,
           random() AS r_day,
           random() AS r_status
    FROM generate_series(1, 1600)
) AS g
JOIN customers c ON c.customer_id = g.customer_id
ORDER BY 2, 1, g.r_status;

-- ---------- 5. Order items ----------
-- Each order has 1 to 4 different products. Product #30 is never sold.
-- Roughly every fourth item is sold below the catalog price (a discount).
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id,
       p.product_id,
       1 + floor(power(random(), 3) * 3)::int,
       ROUND(p.price * (CASE WHEN random() < 0.25
                             THEN 0.85 + random() * 0.10
                             ELSE 1 END)::numeric, 2)
FROM (
    SELECT order_id,
           floor(power(random(), 1.3) * 29)::int          AS base,
           1 + floor(power(random(), 2) * 4)::int         AS n_items
    FROM orders
) AS o
CROSS JOIN LATERAL generate_series(1, o.n_items) AS g(k)
JOIN products p ON p.product_id = ((o.base + (g.k - 1) * 7) % 29) + 1
ORDER BY o.order_id, p.product_id;