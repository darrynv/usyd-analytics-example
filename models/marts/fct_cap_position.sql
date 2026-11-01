-- Prescriptive input: where each 2026 plan version lands against government caps and equity targets.
with cells as (
    select * from {{ ref('int_load_cells') }} where plan_year = 2026
),
caps as (
    select * from {{ ref('stg_caps_targets') }} where plan_year = 2026
),
rates as (
    select * from {{ ref('stg_funding_rates') }} where plan_year = 2026
),
csp as (
    select version_code, cluster_code as scope_code, sum(eftsl) as plan_value
    from cells where funding_type = 'CSP'
    group by 1, 2
),
intl as (
    select version_code, 'ALL' as scope_code, sum(commencing_intake) as plan_value
    from cells where citizenship = 'International'
    group by 1
),
equity as (
    select version_code, 'ALL' as scope_code,
           sum(commencing_intake * low_ses_share) / sum(commencing_intake) as low_ses,
           sum(commencing_intake * first_nations_share) / sum(commencing_intake) as first_nations,
           sum(commencing_intake * regional_share) / sum(commencing_intake) as regional
    from cells where citizenship = 'Domestic' and course_level = 'UG' and funding_type = 'CSP'
    group by 1
),
positions as (
    select c.version_code, k.cap_code, c.plan_value
    from csp c join caps k on k.scope_type = 'funding_cluster' and k.scope_code = c.scope_code
    union all
    select version_code, 'INTL-COMM', plan_value from intl
    union all
    select version_code, 'EQ-LOWSES', low_ses from equity
    union all
    select version_code, 'EQ-FIRSTNATIONS', first_nations from equity
    union all
    select version_code, 'EQ-REGIONAL', regional from equity
)
select
    p.version_code,
    v.version_name,
    v.sort_order as version_order,
    k.cap_code,
    k.cap_type,
    k.scope_code,
    k.measure,
    k.direction,
    k.description,
    k.target_value,
    p.plan_value,
    p.plan_value - k.target_value as gap,
    p.plan_value / nullif(k.target_value, 0) as pct_of_target,
    case
        when k.direction = 'max' and p.plan_value > k.target_value then 'Over cap'
        when k.direction = 'min' and p.plan_value < k.target_value then 'Below target'
        else 'On track'
    end as status,
    -- CGS is not paid for CSP load above the cluster envelope
    case when k.scope_type = 'funding_cluster' then greatest(p.plan_value - k.target_value, 0) * r.cgs_per_eftsl end
        as unfunded_cgs_revenue
from positions p
join caps k using (cap_code)
join {{ ref('dim_version') }} v using (version_code)
left join rates r on k.scope_type = 'funding_cluster' and r.cluster_code = k.scope_code
