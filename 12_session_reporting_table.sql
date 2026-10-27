-- combine all the categories we have look at into a dashboard
-- Output: One row per user–session pair.
-- Acquisition fields describe the user's original acquisition.
-- Stage flags indicate event presence, not ordered progression.

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

SELECT
    user_pseudo_id,
    ga_session_id,
    session_date,
    DATE_TRUNC(session_date, WEEK(MONDAY)) AS week_start,

    session_attributes.device_category AS device_category,
    session_attributes.first_user_source AS first_user_source,
    session_attributes.first_user_medium AS first_user_medium,

    event_count,
    viewed_product,
    added_to_cart,
    began_checkout,
    purchased,

    CASE WHEN purchased THEN 1 ELSE 0 END AS purchase_session_flag

FROM sessions;