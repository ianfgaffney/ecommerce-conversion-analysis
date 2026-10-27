WITH purchases AS (
    SELECT
        ecommerce.transaction_id AS transaction_id,
        ecommerce.purchase_revenue_in_usd AS revenue_usd
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE
        event_name = 'purchase'
)

SELECT
    COUNT(*) AS purchase_events,

    COUNTIF(
        transaction_id IS NULL
        OR TRIM(transaction_id) = ''
    ) AS missing_transaction_id,

    COUNT(DISTINCT NULLIF(TRIM(transaction_id), ''))
        AS distinct_transaction_ids,

    COUNTIF(revenue_usd IS NULL) AS missing_revenue,
    COUNTIF(revenue_usd = 0) AS zero_revenue,
    COUNTIF(revenue_usd < 0) AS negative_revenue,
    COUNTIF(revenue_usd > 0) AS positive_revenue,

    MIN(revenue_usd) AS min_revenue_usd,
    MAX(revenue_usd) AS max_revenue_usd

FROM purchases;