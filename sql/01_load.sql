DROP SCHEMA IF EXISTS raw CASCADE;
CREATE SCHEMA raw;

CREATE TABLE raw.customers (
    customer_id              TEXT,
    customer_unique_id       TEXT,
    customer_zip_code_prefix TEXT,
    customer_city            TEXT,
    customer_state           TEXT
);

CREATE TABLE raw.orders (
    order_id                      TEXT,
    customer_id                   TEXT,
    order_status                  TEXT,
    order_purchase_timestamp      TEXT,
    order_approved_at             TEXT,
    order_delivered_carrier_date  TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

CREATE TABLE raw.order_items (
    order_id            TEXT,
    order_item_id       TEXT,
    product_id          TEXT,
    seller_id           TEXT,
    shipping_limit_date TEXT,
    price               TEXT,
    freight_value       TEXT
);

CREATE TABLE raw.order_payments (
    order_id             TEXT,
    payment_sequential   TEXT,
    payment_type         TEXT,
    payment_installments TEXT,
    payment_value        TEXT
);

CREATE TABLE raw.order_reviews (
    review_id               TEXT,
    order_id                TEXT,
    review_score            TEXT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TEXT,
    review_answer_timestamp TEXT
);

CREATE TABLE raw.products (
    product_id                 TEXT,
    product_category_name      TEXT,
    product_name_lenght        TEXT,
    product_description_lenght TEXT,
    product_photos_qty         TEXT,
    product_weight_g           TEXT,
    product_length_cm          TEXT,
    product_height_cm          TEXT,
    product_width_cm           TEXT
);

CREATE TABLE raw.sellers (
    seller_id              TEXT,
    seller_zip_code_prefix TEXT,
    seller_city            TEXT,
    seller_state           TEXT
);

CREATE TABLE raw.geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat             TEXT,
    geolocation_lng             TEXT,
    geolocation_city            TEXT,
    geolocation_state           TEXT
);

CREATE TABLE raw.product_category_name_translation (
    product_category_name         TEXT,
    product_category_name_english TEXT
);

\copy raw.customers                        FROM 'olist_customers_dataset.csv'        CSV HEADER
\copy raw.orders                           FROM 'olist_orders_dataset.csv'           CSV HEADER
\copy raw.order_items                      FROM 'olist_order_items_dataset.csv'      CSV HEADER
\copy raw.order_payments                   FROM 'olist_order_payments_dataset.csv'   CSV HEADER
\copy raw.order_reviews                    FROM 'olist_order_reviews_dataset.csv'    CSV HEADER
\copy raw.products                         FROM 'olist_products_dataset.csv'         CSV HEADER
\copy raw.sellers                          FROM 'olist_sellers_dataset.csv'          CSV HEADER
\copy raw.geolocation                      FROM 'olist_geolocation_dataset.csv'      CSV HEADER
\copy raw.product_category_name_translation FROM 'product_category_name_translation.csv' CSV HEADER

SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM raw.customers
UNION ALL SELECT 'orders',          COUNT(*) FROM raw.orders
UNION ALL SELECT 'order_items',     COUNT(*) FROM raw.order_items
UNION ALL SELECT 'order_payments',  COUNT(*) FROM raw.order_payments
UNION ALL SELECT 'order_reviews',   COUNT(*) FROM raw.order_reviews
UNION ALL SELECT 'products',        COUNT(*) FROM raw.products
UNION ALL SELECT 'sellers',         COUNT(*) FROM raw.sellers
UNION ALL SELECT 'geolocation',     COUNT(*) FROM raw.geolocation
UNION ALL SELECT 'category_translation', COUNT(*) FROM raw.product_category_name_translation
ORDER BY tbl;
