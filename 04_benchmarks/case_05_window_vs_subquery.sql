-- setup
CREATE TEMP TABLE bench_orders AS
SELECT order_id, customer_id FROM shop.orders WHERE order_id BETWEEN 1 AND 5000;
ANALYZE bench_orders;
-- before
SELECT o.order_id, (SELECT count(*) FROM bench_orders AS p WHERE p.customer_id = o.customer_id) AS order_count
FROM bench_orders AS o;
-- after
SELECT order_id, count(*) OVER (PARTITION BY customer_id) AS order_count FROM bench_orders;
