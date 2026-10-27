--Question: What percentage of sessions reached each purchase stage?
--Output: each of the four stages with what percentage of sessions reached it

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
),

sessions AS (
    SELECT
        user_pseudo_id,
        ga_session_id,

        COUNTIF(event_name = 'view_item') > 0 AS viewed_product,
        COUNTIF(event_name = 'add_to_cart') > 0 AS added_to_cart,
        COUNTIF(event_name = 'begin_checkout') > 0 AS began_checkout,
        COUNTIF(event_name = 'purchase') > 0 AS purchased

    FROM extracted_events

    GROUP BY
        user_pseudo_id,
        ga_session_id
)

Select 
  count(*) as total_sessions,
  countif(viewed_product) as product_viewed_sessions,
  countif(added_to_cart) as cart_sessions,
  countif(began_checkout) as checkout_sessions,
  countif(purchased) as purchase_sessions,
  round(100*safe_divide(countif(viewed_product),count(*)),2) as product_view_reach_pct,
  round(100*safe_divide(countif(added_to_cart),count(*)),2) as cart_reach_pct,
  round(100*safe_divide(countif(began_checkout),count(*)),2) as checkout_reach_pct,
  round(100*safe_divide(countif(purchased),count(*)),2) as purchase_reach_pct,

from sessions;


