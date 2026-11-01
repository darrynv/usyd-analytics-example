-- Diagnostic: "what changed" - every assumption that moved between two versions, with its EFTSL and revenue impact.
with v as (
    select * from {{ ref('fct_load_variance') }}
),
cells as (
    select * from {{ ref('int_load_cells') }}
),
j as (
    select
        v.*,
        b.retention_rate as retention_b,  c.retention_rate as retention_c,
        b.load_per_student as lps_b,      c.load_per_student as lps_c,
        b.revenue_per_eftsl as rate_b,    c.revenue_per_eftsl as rate_c
    from v
    join cells b on b.version_code = v.base_version and b.plan_year = v.plan_year
        and b.course_code = v.course_code and b.citizenship = v.citizenship
    join cells c on c.version_code = v.compare_version and c.plan_year = v.plan_year
        and c.course_code = v.course_code and c.citizenship = v.citizenship
),
long as (
    select comparison_code, course_code, course_name, faculty_name, citizenship, 'Commencing intake' as assumption,
           intake_b as base_value, intake_c as compare_value,
           eftsl_intake_volume + eftsl_intake_mix as eftsl_impact,
           revenue_intake_volume + revenue_intake_mix as revenue_impact
    from j
    union all
    select comparison_code, course_code, course_name, faculty_name, citizenship, 'Retention rate',
           retention_b, retention_c, eftsl_retention, revenue_retention
    from j
    union all
    select comparison_code, course_code, course_name, faculty_name, citizenship, 'Load per student',
           lps_b, lps_c, eftsl_load_intensity, revenue_load_intensity
    from j
    union all
    select comparison_code, course_code, course_name, faculty_name, citizenship, 'Revenue per EFTSL',
           rate_b, rate_c, 0, revenue_rate
    from j
)
select
    *,
    compare_value - base_value as change,
    case when base_value <> 0 then (compare_value - base_value) / base_value end as change_pct
from long
where abs(compare_value - base_value) > 0.00001
