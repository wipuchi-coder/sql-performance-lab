-- setup
CREATE TEMP TABLE bench_orders AS SELECT * FROM shop.orders;
CREATE INDEX bench_queue ON bench_orders (status, ordered_at, order_id);
ANALYZE bench_orders;
-- before
SELECT order_id, ordered_at FROM bench_orders
WHERE status = 'PENDING' ORDER BY ordered_at, order_id LIMIT 100;
-- optimize
DROP INDEX pg_temp.bench_queue;
CREATE INDEX bench_queue ON bench_orders (ordered_at, order_id) WHERE status = 'PENDING';
-- after
SELECT order_id, ordered_at FROM bench_orders
WHERE status = 'PENDING' ORDER BY ordered_at, order_id LIMIT 100;
-- size
SELECT pg_relation_size('pg_temp.bench_queue');
