-- setup
CREATE TEMP TABLE bench_orders AS SELECT * FROM shop.orders;
ANALYZE bench_orders;
-- before
SELECT order_id, ordered_at FROM bench_orders
WHERE customer_id = 42 AND status = 'SHIPPED'
ORDER BY ordered_at DESC, order_id DESC LIMIT 25;
-- optimize
CREATE INDEX ON bench_orders (customer_id, status, ordered_at DESC, order_id DESC);
-- after
SELECT order_id, ordered_at FROM bench_orders
WHERE customer_id = 42 AND status = 'SHIPPED'
ORDER BY ordered_at DESC, order_id DESC LIMIT 25;
