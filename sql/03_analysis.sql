SELECT o.purchase_month,
       COUNT(DISTINCT o.order_id)                                   AS orders,
       SUM(i.price)                                                 AS revenue,
       ROUND(SUM(i.price) / COUNT(DISTINCT o.order_id), 2)          AS avg_order_value
FROM clean.orders o
JOIN clean.order_items i ON i.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY o.purchase_month
ORDER BY o.purchase_month;

SELECT o.order_status,
       COUNT(*)                                                     AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)           AS pct_of_orders
FROM clean.orders o
GROUP BY o.order_status
ORDER BY orders DESC;

WITH category_revenue AS (
    SELECT p.category_en,
           COUNT(*)      AS items_sold,
           SUM(i.price)  AS revenue
    FROM clean.order_items i
    JOIN clean.orders   o ON o.order_id   = i.order_id
    JOIN clean.products p ON p.product_id = i.product_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY p.category_en
)
SELECT category_en,
       items_sold,
       revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)                              AS share_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 2) AS cumulative_share_pct
FROM category_revenue
ORDER BY revenue DESC
LIMIT 10;

SELECT c.state,
       COUNT(DISTINCT c.customer_unique_id)                         AS customers,
       SUM(i.price)                                                 AS revenue,
       ROUND(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER (), 2)   AS share_pct,
       RANK() OVER (ORDER BY SUM(i.price) DESC)                     AS revenue_rank
FROM clean.orders o
JOIN clean.customers   c ON c.customer_id = o.customer_id
JOIN clean.order_items i ON i.order_id    = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.state
ORDER BY revenue_rank;

WITH monthly AS (
    SELECT o.purchase_month,
           SUM(i.price) AS revenue
    FROM clean.orders o
    JOIN clean.order_items i ON i.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')

      AND o.purchase_month BETWEEN DATE '2017-01-01' AND DATE '2018-08-01'
    GROUP BY o.purchase_month
)
SELECT purchase_month,
       revenue,
       LAG(revenue) OVER (ORDER BY purchase_month)                  AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY purchase_month))
             / NULLIF(LAG(revenue) OVER (ORDER BY purchase_month), 0), 1) AS mom_growth_pct,
       SUM(revenue) OVER (ORDER BY purchase_month)                  AS running_revenue
FROM monthly
ORDER BY purchase_month;

WITH per_customer AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders,
           SUM(i.price)               AS revenue
    FROM clean.orders o
    JOIN clean.customers   c ON c.customer_id = o.customer_id
    JOIN clean.order_items i ON i.order_id    = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT CASE WHEN orders = 1 THEN '1 sifariş (təkrar almayıb)'
            ELSE '2+ sifariş (təkrar alıb)' END                     AS segment,
       COUNT(*)                                                     AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)           AS pct_customers,
       SUM(revenue)                                                 AS revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2)   AS pct_revenue
FROM per_customer
GROUP BY 1
ORDER BY customers DESC;

WITH per_customer AS (
    SELECT c.customer_unique_id,
           SUM(i.price) AS revenue
    FROM clean.orders o
    JOIN clean.customers   c ON c.customer_id = o.customer_id
    JOIN clean.order_items i ON i.order_id    = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),
ranked AS (
    SELECT customer_unique_id,
           revenue,
           NTILE(10) OVER (ORDER BY revenue DESC) AS decile
    FROM per_customer
)
SELECT decile,
       COUNT(*)                                                      AS customers,
       SUM(revenue)                                                  AS revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2)    AS pct_revenue,
       ROUND(100.0 * SUM(SUM(revenue)) OVER (ORDER BY decile)
             / SUM(SUM(revenue)) OVER (), 2)                         AS cumulative_pct
FROM ranked
GROUP BY decile
ORDER BY decile;

SELECT c.state,
       COUNT(*)                                                      AS delivered_orders,
       ROUND(AVG(o.delivery_days), 1)                                AS avg_delivery_days,
       ROUND(100.0 * AVG(CASE WHEN o.is_late THEN 1 ELSE 0 END), 2)  AS late_pct
FROM clean.orders o
JOIN clean.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.delivered_ts IS NOT NULL
  AND NOT o.has_anomaly
GROUP BY c.state
HAVING COUNT(*) >= 30
ORDER BY late_pct DESC;

SELECT CASE WHEN o.days_vs_estimate <= 0 THEN '1) vədindən tez/vaxtında'
            WHEN o.days_vs_estimate <= 7 THEN '2) 1-7 gün gec'
            ELSE                              '3) 7 gündən çox gec' END AS delivery_bucket,
       COUNT(*)                                                      AS orders,
       ROUND(AVG(r.review_score), 2)                                 AS avg_review_score,
       ROUND(100.0 * AVG(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END), 2) AS pct_bad_reviews
FROM clean.orders o
JOIN clean.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_ts IS NOT NULL
  AND NOT o.has_anomaly
  AND r.review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;

WITH customer_orders AS (
    SELECT c.customer_unique_id,
           o.purchase_ts,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.purchase_ts) AS order_no,
           LEAD(o.purchase_ts) OVER (PARTITION BY c.customer_unique_id ORDER BY o.purchase_ts) AS next_purchase_ts
    FROM clean.orders o
    JOIN clean.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
first_orders AS (
    SELECT customer_unique_id,
           DATE_TRUNC('month', purchase_ts)::date AS cohort_month,
           (next_purchase_ts IS NOT NULL
            AND next_purchase_ts <= purchase_ts + INTERVAL '90 days') AS returned_90d
    FROM customer_orders
    WHERE order_no = 1
      AND purchase_ts <= (SELECT MAX(purchase_ts) FROM clean.orders) - INTERVAL '90 days'
)
SELECT cohort_month,
       COUNT(*)                                                      AS new_customers,
       COUNT(*) FILTER (WHERE returned_90d)                          AS returned_within_90d,
       ROUND(100.0 * COUNT(*) FILTER (WHERE returned_90d) / COUNT(*), 2) AS retention_90d_pct
FROM first_orders
GROUP BY cohort_month
HAVING COUNT(*) >= 50
ORDER BY cohort_month;
