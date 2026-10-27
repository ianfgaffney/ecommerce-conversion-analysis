--what do the repeated transactions look like in this dataset?
WITH purchases AS (
    SELECT
        NULLIF(TRIM(ecommerce.transaction_id), '') AS transaction_id,
        user_pseudo_id,
        ecommerce.purchase_revenue_in_usd AS revenue_usd
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE
        event_name = 'purchase'
)

SELECT
    transaction_id,

    COUNT(*) AS purchase_event_count,
    COUNT(DISTINCT user_pseudo_id) AS distinct_users,
    COUNT(DISTINCT revenue_usd) AS distinct_revenue_values,

    MIN(revenue_usd) AS min_revenue_usd,
    MAX(revenue_usd) AS max_revenue_usd

FROM purchases

WHERE
    transaction_id IS NOT NULL

GROUP BY
    transaction_id

HAVING
    COUNT(*) > 1

ORDER BY
    purchase_event_count DESC,
    transaction_id;
