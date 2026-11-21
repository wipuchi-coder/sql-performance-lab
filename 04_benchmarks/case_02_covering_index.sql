-- setup
CREATE TEMP TABLE bench_orders AS SELECT * FROM shop.orders;
CREATE INDEX bench_cover ON bench_orders (customer_id, ordered_at DESC, order_id DESC);
-- vacuum
VACUUM (ANALYZE) bench_orders;
-- before
SELECT order_id, ordered_at, status FROM bench_orders
WHERE customer_id = 42 ORDER BY ordered_at DESC, order_id DESC LIMIT 50;
-- optimize
DROP INDEX pg_temp.bench_cover;
CREATE INDEX bench_cover ON bench_orders (customer_id, ordered_at DESC, order_id DESC) INCLUDE (status);
-- after
SELECT order_id, ordered_at, status FROM bench_orders
WHERE customer_id = 42 ORDER BY ordered_at DESC, order_id DESC LIMIT 50;
