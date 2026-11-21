BEGIN;
-- El cargador COPY reutiliza los mismos datos padre y el mismo cálculo de líneas.
LOCK TABLE shop.orders IN SHARE ROW EXCLUSIVE MODE;
INSERT INTO shop.customer
SELECT i, 'customer-' || i || '@example.test' FROM generate_series(1, 1000) AS g(i)
ON CONFLICT (customer_id) DO NOTHING;
INSERT INTO shop.product
SELECT i, 'SKU-' || i, 'Product ' || i FROM generate_series(1, 500) AS g(i)
ON CONFLICT (product_id) DO NOTHING;

-- COPY ORDERS BEGIN
INSERT INTO shop.orders (order_id, customer_id, ordered_at, status, metadata)
SELECT i, 1 + (i * 7919::bigint % 1000),
       timestamp '2024-01-01' + (i * 104729::bigint % 31622400) * interval '1 second',
       CASE WHEN i % 101 = 0 THEN 'PENDING'
            WHEN i % 17 = 0 THEN 'CANCELLED' ELSE 'SHIPPED' END,
       jsonb_build_object('channel', CASE WHEN i % 211 = 0 THEN 'partner' ELSE 'web' END,
                          'batch', i % 367, 'reference', md5(i::text))
FROM generate_series(1, 200000) AS g(i)
ON CONFLICT (order_id) DO NOTHING;
-- COPY ORDERS END

INSERT INTO shop.order_line (order_id, line_no, product_id, quantity, unit_price)
SELECT order_id, 1, 1 + order_id % 500, 1 + order_id % 4, (100 + order_id % 9900) / 100.0
FROM shop.orders WHERE order_id BETWEEN 1 AND 200000
ON CONFLICT (order_id, line_no) DO NOTHING;
COMMIT;
ANALYZE shop.orders;
ANALYZE shop.order_line;
