--validation check

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
        COUNTIF(event_name = 'purchase') > 0 AS purchased

    FROM extracted_events

    WHERE
        user_pseudo_id IS NOT NULL
        AND ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id,
        ga_session_id
)