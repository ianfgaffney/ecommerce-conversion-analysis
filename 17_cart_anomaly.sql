SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_day,
    COUNTIF(event_name = 'view_item') AS product_view_events,
    COUNTIF(event_name = 'add_to_cart') AS cart_events,
    COUNTIF(event_name = 'begin_checkout') AS checkout_events,
    COUNTIF(event_name = 'purchase') AS purchase_events

FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20201130'
    AND device.category IN ('mobile', 'desktop')

GROUP BY
    event_day

ORDER BY
    event_day;