-- Diagnostic: the variance bridge in long form (one row per comparison x faculty x driver), ready for waterfall charts.
with v as (
    select * from {{ ref('fct_load_variance') }}
),
drivers as (
    select comparison_code, comparison_name, faculty_code, faculty_name, 1 as driver_order, 'Intake volume' as driver,
           eftsl_intake_volume as eftsl_effect, revenue_intake_volume as revenue_effect from v
    union all
    select comparison_code, comparison_name, faculty_code, faculty_name, 2, 'Intake mix',
           eftsl_intake_mix, revenue_intake_mix from v
    union all
    select comparison_code, comparison_name, faculty_code, faculty_name, 3, 'Retention',
           eftsl_retention, revenue_retention from v
    union all
    select comparison_code, comparison_name, faculty_code, faculty_name, 4, 'Load per student',
           eftsl_load_intensity, revenue_load_intensity from v
    union all
    select comparison_code, comparison_name, faculty_code, faculty_name, 5, 'Fee and funding rates',
           0, revenue_rate from v
)
select
    comparison_code,
    comparison_name,
    faculty_code,
    faculty_name,
    driver_order,
    driver,
    sum(eftsl_effect) as eftsl_effect,
    sum(revenue_effect) as revenue_effect
from drivers
group by 1, 2, 3, 4, 5, 6
