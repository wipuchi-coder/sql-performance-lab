-- setup
CREATE TEMP TABLE bench_orders AS SELECT * FROM shop.orders;
ANALYZE bench_orders;
-- before
SELECT order_id FROM bench_orders WHERE metadata @> '{"channel":"partner"}';
-- optimize
CREATE INDEX ON bench_orders USING gin (metadata jsonb_path_ops);
-- after
SELECT order_id FROM bench_orders WHERE metadata @> '{"channel":"partner"}';
