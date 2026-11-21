BEGIN;
CREATE SCHEMA IF NOT EXISTS shop;
CREATE TABLE IF NOT EXISTS shop.customer (
    customer_id bigint PRIMARY KEY,
    email text NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS shop.product (
    product_id bigint PRIMARY KEY,
    sku text NOT NULL UNIQUE,
    name text NOT NULL
);
CREATE TABLE IF NOT EXISTS shop.orders (
    order_id bigint PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES shop.customer,
    ordered_at timestamp NOT NULL,
    status text NOT NULL CHECK (status IN ('PENDING', 'SHIPPED', 'CANCELLED')),
    metadata jsonb NOT NULL CHECK (jsonb_typeof(metadata) = 'object')
);
CREATE INDEX IF NOT EXISTS orders_customer_idx ON shop.orders (customer_id);
CREATE TABLE IF NOT EXISTS shop.order_line (
    order_id bigint REFERENCES shop.orders,
    line_no integer CHECK (line_no > 0),
    product_id bigint NOT NULL REFERENCES shop.product,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0 AND unit_price <> 'NaN'),
    PRIMARY KEY (order_id, line_no)
);
CREATE INDEX IF NOT EXISTS order_line_product_idx ON shop.order_line (product_id);
COMMIT;
