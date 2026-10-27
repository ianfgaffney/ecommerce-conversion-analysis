--What events are missing a session id, user id, or both?

WITH extracted_events AS (
    SELECT
        event_name,
        user_pseudo_id,
        (
            SELECT ep.value.int_value
            FROM UNNEST(event_params) AS ep
            WHERE ep.key = 'ga_session_id'
        ) AS ga_session_id
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

missing_identifiers as (select * from extracted_events where user_pseudo_id is null or ga_session_id is null)

SELECT
    COUNT(*) AS events_missing_either_id,

    COUNTIF(
        user_pseudo_id IS NULL AND ga_session_id IS NOT NULL
    ) AS missing_user_id_only,

    COUNTIF(
        ga_session_id IS NULL AND user_pseudo_id IS NOT NULL
    ) AS missing_session_id_only,

    COUNTIF(
        user_pseudo_id IS NULL AND ga_session_id IS NULL
    ) AS missing_both_ids

FROM missing_identifiers;
--
