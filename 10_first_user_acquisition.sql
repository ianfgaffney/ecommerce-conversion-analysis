-- Question: How do session volume and purchase conversion differ by the source/medium that originally acquired the user?

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
        traffic_source.source AS first_user_source,
        traffic_source.medium AS first_user_medium
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

sessions AS (
    SELECT
        user_pseudo_id,
        ga_session_id,

        ARRAY_AGG(
            STRUCT(first_user_source, first_user_medium)
            ORDER BY event_timestamp
            LIMIT 1
        )[SAFE_OFFSET(0)] AS acquisition,

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
    acquisition.first_user_source AS first_user_source,
    acquisition.first_user_medium AS first_user_medium,

    COUNT(*) AS total_sessions,
    COUNTIF(purchased) AS purchase_sessions,

    ROUND(
        100.0 * SAFE_DIVIDE(
            COUNTIF(purchased),
            COUNT(*)
        ),
        2
    ) AS session_purchase_conversion_pct

FROM sessions

GROUP BY
    acquisition.first_user_source,
    acquisition.first_user_medium

ORDER BY
    total_sessions DESC;