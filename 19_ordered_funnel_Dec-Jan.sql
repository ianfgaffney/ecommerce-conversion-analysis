--ordered funnel but only Dec 1st - Jan 31st
WITH extracted_events AS (
    SELECT
        user_pseudo_id,
        (
            SELECT ep.value.int_value
            FROM UNNEST(event_params) AS ep
            WHERE ep.key = 'ga_session_id'
        ) AS ga_session_id,
        event_name,
        event_timestamp

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    WHERE
        _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
        AND device.category IN ('mobile', 'desktop')
),

first_views AS (
    SELECT
        user_pseudo_id,
        ga_session_id,
        MIN(
            CASE
                WHEN event_name = 'view_item' THEN event_timestamp
            END
        ) AS view_timestamp
    FROM extracted_events
    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL
    GROUP BY
        user_pseudo_id,
        ga_session_id
),

ordered_carts AS (
    SELECT
        v.user_pseudo_id,
        v.ga_session_id,
        v.view_timestamp,
        MIN(e.event_timestamp) AS cart_timestamp
    FROM first_views AS v
    LEFT JOIN extracted_events AS e
        ON v.user_pseudo_id = e.user_pseudo_id
        AND v.ga_session_id = e.ga_session_id
        AND e.event_name = 'add_to_cart'
        AND e.event_timestamp > v.view_timestamp
    GROUP BY
        v.user_pseudo_id,
        v.ga_session_id,
        v.view_timestamp
),

ordered_checkouts AS (
    SELECT
        c.user_pseudo_id,
        c.ga_session_id,
        c.view_timestamp,
        c.cart_timestamp,
        MIN(e.event_timestamp) AS checkout_timestamp
    FROM ordered_carts AS c
    LEFT JOIN extracted_events AS e
        ON c.user_pseudo_id = e.user_pseudo_id
        AND c.ga_session_id = e.ga_session_id
        AND e.event_name = 'begin_checkout'
        AND e.event_timestamp > c.cart_timestamp
    GROUP BY
        c.user_pseudo_id,
        c.ga_session_id,
        c.view_timestamp,
        c.cart_timestamp
),

ordered_purchases AS (
    SELECT
        ch.user_pseudo_id,
        ch.ga_session_id,
        ch.view_timestamp,
        ch.cart_timestamp,
        ch.checkout_timestamp,
        MIN(e.event_timestamp) AS purchase_timestamp
    FROM ordered_checkouts AS ch
    LEFT JOIN extracted_events AS e
        ON ch.user_pseudo_id = e.user_pseudo_id
        AND ch.ga_session_id = e.ga_session_id
        AND e.event_name = 'purchase'
        AND e.event_timestamp > ch.checkout_timestamp
    GROUP BY
        ch.user_pseudo_id,
        ch.ga_session_id,
        ch.view_timestamp,
        ch.cart_timestamp,
        ch.checkout_timestamp
)

SELECT
    COUNT(*) AS total_sessions,
    COUNTIF(view_timestamp IS NOT NULL) AS viewed_product,
    COUNTIF(cart_timestamp IS NOT NULL) AS viewed_then_cart,
    COUNTIF(checkout_timestamp IS NOT NULL) AS viewed_cart_then_checkout,
    COUNTIF(purchase_timestamp IS NOT NULL) AS completed_full_funnel
FROM ordered_purchases;
