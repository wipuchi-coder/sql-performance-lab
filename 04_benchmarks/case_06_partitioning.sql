-- setup
CREATE TEMP TABLE bench_orders AS SELECT * FROM shop.orders;
ANALYZE bench_orders;
-- before
SELECT count(*) FROM bench_orders
WHERE ordered_at >= timestamp '2024-06-01' AND ordered_at < timestamp '2024-07-01';
-- optimize
CREATE TEMP TABLE bench_partitioned (LIKE bench_orders) PARTITION BY RANGE (ordered_at);
DO $$
DECLARE
    month_start timestamp;
BEGIN
    FOR month_start IN SELECT generate_series(timestamp '2024-01-01', timestamp '2024-12-01', interval '1 month')
    LOOP
        EXECUTE format('CREATE TEMP TABLE %I PARTITION OF bench_partitioned FOR VALUES FROM (%L) TO (%L)',
                       'bench_' || to_char(month_start, 'YYYY_MM'), month_start, month_start + interval '1 month');
    END LOOP;
END;
$$;
INSERT INTO bench_partitioned SELECT * FROM bench_orders;
ANALYZE bench_partitioned;
-- after
SELECT count(*) FROM bench_partitioned
WHERE ordered_at >= timestamp '2024-06-01' AND ordered_at < timestamp '2024-07-01';
