--what does revenue look like within the set of eleigible orders
WITH purchases AS (
    SELECT
        NULLIF(
            NULLIF(TRIM(ecommerce.transaction_id), ''),
            '(not set)'
        ) AS transaction_id,

        user_pseudo_id,
        ecommerce.purchase_revenue_in_usd AS revenue_usd

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    WHERE
        event_name = 'purchase'
),

transaction_summary AS (
    SELECT
        transaction_id,
        COUNT(*) AS purchase_event_count,
        COUNT(DISTINCT user_pseudo_id) AS distinct_users,
        COUNT(DISTINCT revenue_usd) AS distinct_revenue_values,

        COUNTIF(user_pseudo_id IS NULL) AS missing_user_records,
        COUNTIF(revenue_usd IS NULL) AS missing_revenue_records,

        MAX(revenue_usd) AS order_revenue_usd

    FROM purchases

    WHERE
        transaction_id IS NOT NULL

    GROUP BY
        transaction_id
),

eligible_orders AS (
    SELECT *
    FROM transaction_summary
    WHERE
        distinct_users = 1
        AND distinct_revenue_values = 1
        AND missing_user_records = 0
        AND missing_revenue_records = 0
)

SELECT
    COUNT(*) AS eligible_orders,

    SUM(purchase_event_count) AS represented_purchase_events,

    SUM(purchase_event_count - 1) AS repeated_records_collapsed,

    COUNTIF(order_revenue_usd = 0) AS zero_revenue_orders,

    ROUND(
        SUM(order_revenue_usd), 2
    ) AS eligible_order_revenue_usd,

    ROUND(
        AVG(order_revenue_usd), 2
    ) AS average_order_value_usd

FROM eligible_orders;
