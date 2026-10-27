--Question: How much purchase activity does our strict ordered funnel capture per device?
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
        device.category as device_category
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
session_devices AS (
    SELECT
        user_pseudo_id,
        ga_session_id,
        ARRAY_AGG(
            device_category IGNORE NULLS
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS device_category
    FROM extracted_events
    GROUP BY
        user_pseudo_id,
        ga_session_id
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
),
session_purchase_flags AS (
    SELECT
        user_pseudo_id,
        ga_session_id,
        COUNTIF(event_name = 'purchase') > 0 AS purchased
    FROM extracted_events
    GROUP BY
        user_pseudo_id,
        ga_session_id
)
SELECT
    d.device_category,

    COUNT(*) AS total_sessions,

    COUNTIF(p.purchased) AS all_purchase_sessions,

    COUNTIF(
        f.purchase_timestamp IS NOT NULL
    ) AS full_funnel_sessions,

    COUNTIF(
        p.purchased AND f.purchase_timestamp IS NULL
    ) AS purchase_sessions_outside_full_funnel,

    ROUND(
        100.0 * SAFE_DIVIDE(
            COUNTIF(p.purchased),
            COUNT(*)
        ),
        2
    ) AS session_purchase_conversion_pct,

    ROUND(
        100.0 * SAFE_DIVIDE(
            COUNTIF(f.purchase_timestamp IS NOT NULL),
            COUNTIF(p.purchased)
        ),
        2
    ) AS full_funnel_purchase_coverage_pct

FROM ordered_purchases AS f

LEFT JOIN session_devices AS d
    ON f.user_pseudo_id = d.user_pseudo_id
    AND f.ga_session_id = d.ga_session_id

LEFT JOIN session_purchase_flags AS p
    ON f.user_pseudo_id = p.user_pseudo_id
    AND f.ga_session_id = p.ga_session_id

GROUP BY
    d.device_category

ORDER BY
    total_sessions DESC;
