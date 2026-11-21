# ER diaqram: Olist (clean sxemi)

GitHub bu diaqramı avtomatik çəkir (Mermaid). Şəkil faylı lazım olsa, `olist.dbml` faylını dbdiagram.io-da açıb PNG kimi export edin.

```mermaid
erDiagram
    customers      ||--o{ orders         : "customer_id"
    orders         ||--|{ order_items    : "order_id"
    orders         ||--o{ order_payments : "order_id"
    orders         ||--o| order_reviews  : "order_id"
    products       ||--o{ order_items    : "product_id"
    sellers        ||--o{ order_items    : "seller_id"
    category_translation ||--o{ products : "category_pt"
    geolocation    ||--o{ customers      : "zip_prefix (FK yoxdur)"
    geolocation    ||--o{ sellers        : "zip_prefix (FK yoxdur)"

    customers {
        varchar customer_id PK
        varchar customer_unique_id
        varchar zip_prefix
        varchar city
        varchar state
    }
    orders {
        varchar order_id PK
        varchar customer_id FK
        varchar order_status
        timestamp purchase_ts
        timestamp delivered_ts
        timestamp estimated_ts
        boolean is_late
        boolean has_anomaly
    }
    order_items {
        varchar order_id PK
        int order_item_id PK
        varchar product_id FK
        varchar seller_id FK
        numeric price
        numeric freight_value
    }
    order_payments {
        varchar order_id PK
        int payment_sequential PK
        varchar payment_type
        numeric payment_value
    }
    order_reviews {
        varchar order_id PK
        varchar review_id
        int review_score
        timestamp review_created_ts
    }
    products {
        varchar product_id PK
        varchar category_pt FK
        varchar category_en
        numeric weight_g
    }
    category_translation {
        varchar category_pt PK
        varchar category_en
    }
    sellers {
        varchar seller_id PK
        varchar zip_prefix
        varchar state
    }
    geolocation {
        varchar zip_prefix PK
        double lat
        double lng
    }
```

## Əlaqələrin izahı

| Əlaqə | Növ | İzah |
|---|---|---|
| customers → orders | 1 : çox | bir `customer_id` bir sifarişə bağlıdır. Eyni real müştərinin (`customer_unique_id`) bir neçə `customer_id`-si ola bilər |
| orders → order_items | 1 : çox | bir sifarişdə bir neçə məhsul sətri ola bilər |
| orders → order_payments | 1 : çox | bir sifariş bir neçə ödənişlə (məsələn kart + voucher) ödənə bilər |
| orders → order_reviews | 1 : 0..1 | təmizləmədən sonra sifariş başına 1 rəy saxlanıb |
| products → order_items | 1 : çox | |
| sellers → order_items | 1 : çox | |
| category_translation → products | 1 : çox | portuqalca kateqoriya adı açardır |
| geolocation → customers / sellers | 1 : çox | `zip_prefix` ilə bağlıdır, FK qoyulmayıb |
