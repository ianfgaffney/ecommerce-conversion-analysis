-- Dashboard-ready session data.
-- One row per user–session pair.
-- Stage-reach flags measure event presence.
-- Ordered-funnel flags require strictly increasing timestamps.

WITH extracted_events AS (
    SELECT
        user_pseudo_id,
        (
            SELECT ep.value.int_value
            FROM UNNEST(event_params) AS ep
            WHERE ep.key = 'ga_session_id'
        ) AS ga_session_id,

        event_name,
        event_timestamp,
        event_date,

        device.category AS device_category,
        traffic_source.source AS first_user_source,
        traffic_source.medium AS first_user_medium

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    WHERE
        _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
    SELECT
        user_pseudo_id,
        ga_session_id,

        PARSE_DATE('%Y%m%d', MIN(event_date)) AS session_date,

        ARRAY_AGG(
            STRUCT(
                device_category,
                first_user_source,
                first_user_medium
            )
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS session_attributes,

        COUNT(*) AS event_count,

        COUNTIF(event_name = 'view_item') > 0 AS viewed_product,
        COUNTIF(event_name = 'add_to_cart') > 0 AS added_to_cart,
        COUNTIF(event_name = 'begin_checkout') > 0 AS began_checkout,
        COUNTIF(event_name = 'purchase') > 0 AS purchased,

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
        s.user_pseudo_id,
        s.ga_session_id,

        MIN(e.event_timestamp) AS cart_timestamp

    FROM sessions AS s

    LEFT JOIN extracted_events AS e
        ON s.user_pseudo_id = e.user_pseudo_id
        AND s.ga_session_id = e.ga_session_id
        AND e.event_name = 'add_to_cart'
        AND e.event_timestamp > s.view_timestamp

    GROUP BY
        s.user_pseudo_id,
        s.ga_session_id
),

ordered_checkouts AS (
    SELECT
        c.user_pseudo_id,
        c.ga_session_id,

        MIN(e.event_timestamp) AS checkout_timestamp

    FROM ordered_carts AS c

    LEFT JOIN extracted_events AS e
        ON c.user_pseudo_id = e.user_pseudo_id
        AND c.ga_session_id = e.ga_session_id
        AND e.event_name = 'begin_checkout'
        AND e.event_timestamp > c.cart_timestamp

    GROUP BY
        c.user_pseudo_id,
        c.ga_session_id
),

ordered_purchases AS (
    SELECT
        ch.user_pseudo_id,
        ch.ga_session_id,

        MIN(e.event_timestamp) AS purchase_timestamp

    FROM ordered_checkouts AS ch

    LEFT JOIN extracted_events AS e
        ON ch.user_pseudo_id = e.user_pseudo_id
        AND ch.ga_session_id = e.ga_session_id
        AND e.event_name = 'purchase'
        AND e.event_timestamp > ch.checkout_timestamp

    GROUP BY
        ch.user_pseudo_id,
        ch.ga_session_id
)

SELECT
    s.user_pseudo_id,
    s.ga_session_id,
    s.session_date,
    DATE_TRUNC(s.session_date, WEEK(MONDAY)) AS week_start,

    s.session_attributes.device_category AS device_category,
    s.session_attributes.first_user_source AS first_user_source,
    s.session_attributes.first_user_medium AS first_user_medium,

    s.event_count,

    -- Stage reach: event occurred anywhere in the session.
    s.viewed_product,
    s.added_to_cart,
    s.began_checkout,
    s.purchased,
    CASE WHEN s.purchased THEN 1 ELSE 0 END AS purchase_session_flag,

    -- Earliest qualifying timestamps for the ordered sequence.
    -- Convert GA4 microsecond values to readable BigQuery timestamps.
    TIMESTAMP_MICROS(s.view_timestamp) AS view_timestamp,
    TIMESTAMP_MICROS(c.cart_timestamp) AS cart_timestamp,
    TIMESTAMP_MICROS(ch.checkout_timestamp) AS checkout_timestamp,
    TIMESTAMP_MICROS(p.purchase_timestamp) AS purchase_timestamp,

    -- Strict same-session ordered progression.
    c.cart_timestamp IS NOT NULL AS viewed_then_cart,
    ch.checkout_timestamp IS NOT NULL AS viewed_cart_then_checkout,
    p.purchase_timestamp IS NOT NULL AS completed_full_funnel,

    -- Recommended subset for the restricted funnel analysis.
    (
        s.session_date BETWEEN DATE '2020-12-01' AND DATE '2021-01-31'
        AND s.session_attributes.device_category IN ('mobile', 'desktop')
    ) AS in_dec_jan_mobile_desktop

FROM sessions AS s

LEFT JOIN ordered_carts AS c
    ON s.user_pseudo_id = c.user_pseudo_id
    AND s.ga_session_id = c.ga_session_id

LEFT JOIN ordered_checkouts AS ch
    ON s.user_pseudo_id = ch.user_pseudo_id
    AND s.ga_session_id = ch.ga_session_id

LEFT JOIN ordered_purchases AS p
    ON s.user_pseudo_id = p.user_pseudo_id
    AND s.ga_session_id = p.ga_session_id;
