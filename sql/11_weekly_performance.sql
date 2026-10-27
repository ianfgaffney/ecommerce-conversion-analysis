--How do total sessions, purchase sessions, and purchase conversion pct vary across weeks in our dataset.
WITH extracted_events AS (
    SELECT
        user_pseudo_id,
        (
            SELECT ep.value.int_value
            FROM UNNEST(event_params) AS ep
            WHERE ep.key = 'ga_session_id'
        ) AS ga_session_id,
        event_name,
        event_date
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

sessions AS (
    SELECT
        user_pseudo_id,
        ga_session_id,

        PARSE_DATE(
            '%Y%m%d',
            MIN(event_date)
        ) AS session_date,

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
    DATE_TRUNC(session_date, WEEK(MONDAY)) AS week_start,

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
    week_start

ORDER BY
    week_start;
