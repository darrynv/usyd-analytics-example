select
    plan_year,
    cap_code,
    cap_type,
    scope_type,
    scope_code,
    measure,
    direction,
    target_value::numeric as target_value,
    description
from {{ ref('caps_targets') }}
