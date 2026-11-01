select
    version_code,
    version_name,
    version_type,
    plan_year,
    published_on,
    sort_order
from {{ ref('plan_versions') }}
