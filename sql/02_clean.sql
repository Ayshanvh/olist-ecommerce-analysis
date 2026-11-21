DROP SCHEMA IF EXISTS clean CASCADE;
CREATE SCHEMA clean;

CREATE TABLE clean.customers AS
SELECT DISTINCT ON (c.customer_id)
       TRIM(c.customer_id)                                  AS customer_id,
       TRIM(c.customer_unique_id)                           AS customer_unique_id,
       LPAD(NULLIF(TRIM(c.customer_zip_code_prefix), ''), 5, '0') AS zip_prefix,
       LOWER(NULLIF(TRIM(c.customer_city), ''))             AS city,
       UPPER(NULLIF(TRIM(c.customer_state), ''))            AS state
FROM raw.customers c
WHERE NULLIF(TRIM(c.customer_id), '') IS NOT NULL
ORDER BY c.customer_id;

ALTER TABLE clean.customers ADD PRIMARY KEY (customer_id);

CREATE TABLE clean.orders AS
WITH typed AS (
    SELECT DISTINCT ON (o.order_id)
           TRIM(o.order_id)                                              AS order_id,
           TRIM(o.customer_id)                                           AS customer_id,
           LOWER(NULLIF(TRIM(o.order_status), ''))                       AS order_status,
           NULLIF(TRIM(o.order_purchase_timestamp), '')::timestamp       AS purchase_ts,
           NULLIF(TRIM(o.order_approved_at), '')::timestamp              AS approved_ts,
           NULLIF(TRIM(o.order_delivered_carrier_date), '')::timestamp   AS carrier_ts,
           NULLIF(TRIM(o.order_delivered_customer_date), '')::timestamp  AS delivered_ts,
           NULLIF(TRIM(o.order_estimated_delivery_date), '')::timestamp  AS estimated_ts
    FROM raw.orders o
    WHERE NULLIF(TRIM(o.order_id), '') IS NOT NULL
    ORDER BY o.order_id
)
SELECT t.*,
       DATE_TRUNC('month', t.purchase_ts)::date                          AS purchase_month,

       ROUND((EXTRACT(EPOCH FROM (t.delivered_ts - t.purchase_ts)) / 86400)::numeric, 2)
                                                                         AS delivery_days,

       (t.delivered_ts::date - t.estimated_ts::date)                     AS days_vs_estimate,
       CASE WHEN t.delivered_ts IS NULL THEN NULL
            ELSE t.delivered_ts::date > t.estimated_ts::date END         AS is_late,

       COALESCE(t.approved_ts  < t.purchase_ts, FALSE)                   AS a_approved_before_purchase,
       COALESCE(t.carrier_ts   < t.purchase_ts, FALSE)                   AS a_carrier_before_purchase,
       COALESCE(t.delivered_ts < t.purchase_ts, FALSE)                   AS a_delivered_before_purchase,
       COALESCE(t.delivered_ts < t.carrier_ts,  FALSE)                   AS a_delivered_before_carrier,
       (t.order_status = 'delivered' AND t.delivered_ts IS NULL)         AS a_delivered_no_date,
       (t.order_status <> 'delivered' AND t.delivered_ts IS NOT NULL)    AS a_date_but_not_delivered
FROM typed t;

ALTER TABLE clean.orders ADD PRIMARY KEY (order_id);
ALTER TABLE clean.orders ADD COLUMN has_anomaly BOOLEAN;
UPDATE clean.orders
SET has_anomaly = (a_approved_before_purchase OR a_carrier_before_purchase
                OR a_delivered_before_purchase OR a_delivered_before_carrier
                OR a_delivered_no_date OR a_date_but_not_delivered);

CREATE TABLE clean.order_items AS
SELECT DISTINCT ON (i.order_id, i.order_item_id)
       TRIM(i.order_id)                                         AS order_id,
       NULLIF(TRIM(i.order_item_id), '')::int                   AS order_item_id,
       TRIM(i.product_id)                                       AS product_id,
       TRIM(i.seller_id)                                        AS seller_id,
       NULLIF(TRIM(i.shipping_limit_date), '')::timestamp       AS shipping_limit_ts,
       NULLIF(TRIM(i.price), '')::numeric(12,2)                 AS price,
       NULLIF(TRIM(i.freight_value), '')::numeric(12,2)         AS freight_value,
       (COALESCE(NULLIF(TRIM(i.price), '')::numeric, 0) <= 0
        OR COALESCE(NULLIF(TRIM(i.freight_value), '')::numeric, 0) < 0) AS a_bad_amount
FROM raw.order_items i
WHERE NULLIF(TRIM(i.order_id), '') IS NOT NULL
ORDER BY i.order_id, i.order_item_id;

ALTER TABLE clean.order_items ADD PRIMARY KEY (order_id, order_item_id);

CREATE TABLE clean.order_payments AS
SELECT DISTINCT ON (p.order_id, p.payment_sequential)
       TRIM(p.order_id)                                          AS order_id,
       NULLIF(TRIM(p.payment_sequential), '')::int               AS payment_sequential,
       CASE WHEN LOWER(TRIM(p.payment_type)) IN ('not_defined', '') OR p.payment_type IS NULL
            THEN 'unknown' ELSE LOWER(TRIM(p.payment_type)) END  AS payment_type,
       NULLIF(TRIM(p.payment_installments), '')::int             AS installments,
       NULLIF(TRIM(p.payment_value), '')::numeric(12,2)          AS payment_value,
       (COALESCE(NULLIF(TRIM(p.payment_value), '')::numeric, 0) <= 0) AS a_zero_value
FROM raw.order_payments p
WHERE NULLIF(TRIM(p.order_id), '') IS NOT NULL
ORDER BY p.order_id, p.payment_sequential;

ALTER TABLE clean.order_payments ADD PRIMARY KEY (order_id, payment_sequential);

CREATE TABLE clean.order_reviews AS
SELECT DISTINCT ON (r.order_id)
       TRIM(r.review_id)                                             AS review_id,
       TRIM(r.order_id)                                              AS order_id,
       CASE WHEN NULLIF(TRIM(r.review_score), '')::int BETWEEN 1 AND 5
            THEN NULLIF(TRIM(r.review_score), '')::int END           AS review_score,
       NULLIF(TRIM(r.review_comment_title), '')                      AS comment_title,
       NULLIF(TRIM(r.review_comment_message), '')                    AS comment_message,
       NULLIF(TRIM(r.review_creation_date), '')::timestamp           AS review_created_ts,
       NULLIF(TRIM(r.review_answer_timestamp), '')::timestamp        AS review_answered_ts
FROM raw.order_reviews r
WHERE NULLIF(TRIM(r.order_id), '') IS NOT NULL
ORDER BY r.order_id,
         NULLIF(TRIM(r.review_answer_timestamp), '')::timestamp DESC NULLS LAST,
         r.review_id;

ALTER TABLE clean.order_reviews ADD PRIMARY KEY (order_id);

CREATE TABLE clean.category_translation AS
SELECT DISTINCT ON (t.product_category_name)
       LOWER(TRIM(t.product_category_name))          AS category_pt,
       LOWER(TRIM(t.product_category_name_english))  AS category_en
FROM raw.product_category_name_translation t
WHERE NULLIF(TRIM(t.product_category_name), '') IS NOT NULL
ORDER BY t.product_category_name;

ALTER TABLE clean.category_translation ADD PRIMARY KEY (category_pt);

CREATE TABLE clean.products AS
SELECT DISTINCT ON (p.product_id)
       TRIM(p.product_id)                                           AS product_id,
       COALESCE(LOWER(NULLIF(TRIM(p.product_category_name), '')), 'unknown') AS category_pt,
       COALESCE(ct.category_en,
                LOWER(NULLIF(TRIM(p.product_category_name), '')),
                'unknown')                                          AS category_en,
       NULLIF(TRIM(p.product_name_lenght), '')::int                 AS name_length,
       NULLIF(TRIM(p.product_description_lenght), '')::int          AS description_length,
       NULLIF(TRIM(p.product_photos_qty), '')::int                  AS photos_qty,
       NULLIF(TRIM(p.product_weight_g), '')::numeric                AS weight_g,
       NULLIF(TRIM(p.product_length_cm), '')::numeric               AS length_cm,
       NULLIF(TRIM(p.product_height_cm), '')::numeric               AS height_cm,
       NULLIF(TRIM(p.product_width_cm), '')::numeric                AS width_cm
FROM raw.products p
LEFT JOIN clean.category_translation ct
       ON ct.category_pt = LOWER(TRIM(p.product_category_name))
WHERE NULLIF(TRIM(p.product_id), '') IS NOT NULL
ORDER BY p.product_id;

ALTER TABLE clean.products ADD PRIMARY KEY (product_id);

CREATE TABLE clean.sellers AS
SELECT DISTINCT ON (s.seller_id)
       TRIM(s.seller_id)                                              AS seller_id,
       LPAD(NULLIF(TRIM(s.seller_zip_code_prefix), ''), 5, '0')       AS zip_prefix,
       LOWER(NULLIF(TRIM(s.seller_city), ''))                         AS city,
       UPPER(NULLIF(TRIM(s.seller_state), ''))                        AS state
FROM raw.sellers s
WHERE NULLIF(TRIM(s.seller_id), '') IS NOT NULL
ORDER BY s.seller_id;

ALTER TABLE clean.sellers ADD PRIMARY KEY (seller_id);

CREATE TABLE clean.geolocation AS
SELECT LPAD(TRIM(g.geolocation_zip_code_prefix), 5, '0')              AS zip_prefix,
       AVG(NULLIF(TRIM(g.geolocation_lat), '')::double precision)     AS lat,
       AVG(NULLIF(TRIM(g.geolocation_lng), '')::double precision)     AS lng,
       MODE() WITHIN GROUP (ORDER BY LOWER(TRIM(g.geolocation_city))) AS city,
       MODE() WITHIN GROUP (ORDER BY UPPER(TRIM(g.geolocation_state))) AS state,
       COUNT(*)                                                       AS raw_row_count
FROM raw.geolocation g
WHERE NULLIF(TRIM(g.geolocation_zip_code_prefix), '') IS NOT NULL
GROUP BY LPAD(TRIM(g.geolocation_zip_code_prefix), 5, '0');

ALTER TABLE clean.geolocation ADD PRIMARY KEY (zip_prefix);

ALTER TABLE clean.orders         ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES clean.customers (customer_id) NOT VALID;
ALTER TABLE clean.order_items    ADD CONSTRAINT fk_items_order
    FOREIGN KEY (order_id)    REFERENCES clean.orders (order_id)       NOT VALID;
ALTER TABLE clean.order_items    ADD CONSTRAINT fk_items_product
    FOREIGN KEY (product_id)  REFERENCES clean.products (product_id)   NOT VALID;
ALTER TABLE clean.order_items    ADD CONSTRAINT fk_items_seller
    FOREIGN KEY (seller_id)   REFERENCES clean.sellers (seller_id)     NOT VALID;
ALTER TABLE clean.order_payments ADD CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id)    REFERENCES clean.orders (order_id)       NOT VALID;
ALTER TABLE clean.order_reviews  ADD CONSTRAINT fk_reviews_order
    FOREIGN KEY (order_id)    REFERENCES clean.orders (order_id)       NOT VALID;

CREATE TABLE clean.cleaning_log (
    step_no       SERIAL PRIMARY KEY,
    table_name    TEXT,
    issue         TEXT,
    rows_affected BIGINT,
    decision      TEXT
);

INSERT INTO clean.cleaning_log (table_name, issue, rows_affected, decision)
SELECT 'customers', 'təkrarlanan customer_id', (SELECT COUNT(*) FROM raw.customers) - (SELECT COUNT(*) FROM clean.customers), 'silindi (1 sətir qaldı)'
UNION ALL
SELECT 'orders', 'təkrarlanan order_id', (SELECT COUNT(*) FROM raw.orders) - (SELECT COUNT(*) FROM clean.orders), 'silindi (1 sətir qaldı)'
UNION ALL
SELECT 'order_items', 'təkrarlanan (order_id, order_item_id)', (SELECT COUNT(*) FROM raw.order_items) - (SELECT COUNT(*) FROM clean.order_items), 'silindi'
UNION ALL
SELECT 'order_payments', 'təkrarlanan (order_id, payment_sequential)', (SELECT COUNT(*) FROM raw.order_payments) - (SELECT COUNT(*) FROM clean.order_payments), 'silindi'
UNION ALL
SELECT 'order_reviews', 'bir sifarişə bir neçə rəy / təkrar review_id', (SELECT COUNT(*) FROM raw.order_reviews) - (SELECT COUNT(*) FROM clean.order_reviews), 'sifariş başına son rəy saxlanıldı'
UNION ALL
SELECT 'products', 'təkrarlanan product_id', (SELECT COUNT(*) FROM raw.products) - (SELECT COUNT(*) FROM clean.products), 'silindi'
UNION ALL
SELECT 'sellers', 'təkrarlanan seller_id', (SELECT COUNT(*) FROM raw.sellers) - (SELECT COUNT(*) FROM clean.sellers), 'silindi'
UNION ALL
SELECT 'geolocation', 'eyni zip prefiksə düşən çoxlu sətir', (SELECT COUNT(*) FROM raw.geolocation) - (SELECT COUNT(*) FROM clean.geolocation), 'zip prefiks başına 1 sətirdə birləşdirildi'
;

INSERT INTO clean.cleaning_log (table_name, issue, rows_affected, decision)
SELECT 'orders', 'order_approved_at boşdur', COUNT(*), 'NULL saxlanıldı (təsdiqlənməmiş sifariş)'
FROM clean.orders WHERE approved_ts IS NULL
UNION ALL
SELECT 'orders', 'çatdırılma tarixi boşdur (status delivered deyil)', COUNT(*), 'NULL saxlanıldı (hələ çatmayıb/ləğv)'
FROM clean.orders WHERE delivered_ts IS NULL AND order_status <> 'delivered'
UNION ALL
SELECT 'products', 'məhsul kateqoriyası boşdur', COUNT(*), $$'unknown' kimi işarələndi$$
FROM clean.products WHERE category_pt = 'unknown'
UNION ALL
SELECT 'products', 'ingiliscə kateqoriya adı tapılmadı (portuqalca qaldı)', COUNT(*), 'portuqalca ad saxlanıldı'
FROM clean.products p
WHERE p.category_pt <> 'unknown'
  AND NOT EXISTS (SELECT 1 FROM clean.category_translation ct WHERE ct.category_pt = p.category_pt)
UNION ALL
SELECT 'order_reviews', 'rəy mətni boşdur', COUNT(*), 'NULL saxlanıldı (çoxu rəy yazmır)'
FROM clean.order_reviews WHERE comment_message IS NULL
UNION ALL
SELECT 'order_payments', $$payment_type 'not_defined'$$, COUNT(*), $$'unknown' kimi işarələndi$$
FROM clean.order_payments WHERE payment_type = 'unknown';

INSERT INTO clean.cleaning_log (table_name, issue, rows_affected, decision)
SELECT 'orders', 'təsdiq tarixi sifariş tarixindən əvvəldir', COUNT(*) FILTER (WHERE a_approved_before_purchase), 'bayraqlandı'
FROM clean.orders
UNION ALL
SELECT 'orders', 'kuryerə verilmə tarixi sifariş tarixindən əvvəldir', COUNT(*) FILTER (WHERE a_carrier_before_purchase), 'bayraqlandı'
FROM clean.orders
UNION ALL
SELECT 'orders', 'çatdırılma tarixi sifariş tarixindən əvvəldir (mənfi çatdırılma müddəti)', COUNT(*) FILTER (WHERE a_delivered_before_purchase), 'bayraqlandı'
FROM clean.orders
UNION ALL
SELECT 'orders', 'müştəriyə çatdırılma kuryerə verilmədən əvvəldir', COUNT(*) FILTER (WHERE a_delivered_before_carrier), 'bayraqlandı'
FROM clean.orders
UNION ALL
SELECT 'orders', 'status delivered, amma çatdırılma tarixi yoxdur', COUNT(*) FILTER (WHERE a_delivered_no_date), 'bayraqlandı'
FROM clean.orders
UNION ALL
SELECT 'orders', 'status delivered deyil, amma çatdırılma tarixi var', COUNT(*) FILTER (WHERE a_date_but_not_delivered), 'bayraqlandı'
FROM clean.orders
UNION ALL
SELECT 'order_items', 'qiymət <= 0 və ya daşıma haqqı < 0', COUNT(*) FILTER (WHERE a_bad_amount), 'bayraqlandı'
FROM clean.order_items
UNION ALL
SELECT 'order_payments', 'ödəniş məbləği <= 0', COUNT(*) FILTER (WHERE a_zero_value), 'bayraqlandı'
FROM clean.order_payments;

INSERT INTO clean.cleaning_log (table_name, issue, rows_affected, decision)
SELECT 'orders', 'customers-da qarşılığı olmayan sifariş', COUNT(*), 'yoxlama (dəyişiklik edilmədi)'
FROM clean.orders o WHERE NOT EXISTS (SELECT 1 FROM clean.customers c WHERE c.customer_id = o.customer_id)
UNION ALL
SELECT 'order_items', 'orders-da qarşılığı olmayan sətir', COUNT(*), 'yoxlama (dəyişiklik edilmədi)'
FROM clean.order_items i WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = i.order_id)
UNION ALL
SELECT 'order_items', 'products-da qarşılığı olmayan sətir', COUNT(*), 'yoxlama (dəyişiklik edilmədi)'
FROM clean.order_items i WHERE NOT EXISTS (SELECT 1 FROM clean.products p WHERE p.product_id = i.product_id)
UNION ALL
SELECT 'order_items', 'sellers-də qarşılığı olmayan sətir', COUNT(*), 'yoxlama (dəyişiklik edilmədi)'
FROM clean.order_items i WHERE NOT EXISTS (SELECT 1 FROM clean.sellers s WHERE s.seller_id = i.seller_id)
UNION ALL
SELECT 'order_payments', 'orders-da qarşılığı olmayan sətir', COUNT(*), 'yoxlama (dəyişiklik edilmədi)'
FROM clean.order_payments p WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = p.order_id)
UNION ALL
SELECT 'order_reviews', 'orders-da qarşılığı olmayan sətir', COUNT(*), 'yoxlama (dəyişiklik edilmədi)'
FROM clean.order_reviews r WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = r.order_id);

SELECT * FROM clean.cleaning_log ORDER BY step_no;

SELECT t.tbl,
       t.raw_rows,
       t.clean_rows,
       t.raw_rows - t.clean_rows AS removed
FROM (
    SELECT 'customers' AS tbl,      (SELECT COUNT(*) FROM raw.customers) AS raw_rows,      (SELECT COUNT(*) FROM clean.customers) AS clean_rows
    UNION ALL SELECT 'orders',      (SELECT COUNT(*) FROM raw.orders),      (SELECT COUNT(*) FROM clean.orders)
    UNION ALL SELECT 'order_items', (SELECT COUNT(*) FROM raw.order_items), (SELECT COUNT(*) FROM clean.order_items)
    UNION ALL SELECT 'order_payments', (SELECT COUNT(*) FROM raw.order_payments), (SELECT COUNT(*) FROM clean.order_payments)
    UNION ALL SELECT 'order_reviews', (SELECT COUNT(*) FROM raw.order_reviews), (SELECT COUNT(*) FROM clean.order_reviews)
    UNION ALL SELECT 'products',    (SELECT COUNT(*) FROM raw.products),    (SELECT COUNT(*) FROM clean.products)
    UNION ALL SELECT 'sellers',     (SELECT COUNT(*) FROM raw.sellers),     (SELECT COUNT(*) FROM clean.sellers)
    UNION ALL SELECT 'geolocation', (SELECT COUNT(*) FROM raw.geolocation), (SELECT COUNT(*) FROM clean.geolocation)
) t
ORDER BY t.tbl;
