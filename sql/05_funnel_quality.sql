--Question: Do any sessions contain a later purchase stage without a preceding purchase stage?
--Output: Count of events that have a stage without the preceding stage
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

select
  count(*) as total_sessions,
  countif(added_to_cart and not viewed_product) as cart_without_product_view,
  countif(began_checkout and not added_to_cart) as checkout_without_cart,
  countif(purchased and not began_checkout) as purchase_without_checkout,
  round(100*safe_divide(countif(began_checkout and not added_to_cart),countif(began_checkout)),2) as checkout_without_cart_pct
from sessions;
