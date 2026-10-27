select event_name, count(*) as event_count, count(distinct user_pseudo_id) as unique_users,
from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
    _TABLE_SUFFIX BETWEEN '20210101' AND '20210107'
group by event_name
order by event_count desc
