--Question: What funnel events occurred in each user-session pair?
--Output: one row per user-session pair with 0 or 1 for each event indicating whether it happened

WITH extracted_events AS (
    SELECT
        user_pseudo_id,
        (
            SELECT ep.value.int_value
            FROM UNNEST(event_params) AS ep
            WHERE ep.key = 'ga_session_id'
        ) AS ga_session_id,
        event_name
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)

SELECT
    user_pseudo_id,
    ga_session_id,

    COUNT(*) AS event_count,

    COUNTIF(event_name = 'view_item') > 0 AS viewed_product,
    COUNTIF(event_name = 'add_to_cart') > 0 AS added_to_cart,
    COUNTIF(event_name = 'begin_checkout') > 0 AS began_checkout,
    COUNTIF(event_name = 'purchase') > 0 AS purchased

FROM extracted_events

GROUP BY
    user_pseudo_id,
    ga_session_id;
