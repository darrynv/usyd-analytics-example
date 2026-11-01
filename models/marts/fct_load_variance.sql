-- Diagnostic: exact driver bridge between two load-profile versions, per cell.
-- EFTSL = (intake + continuing_base x retention) x load_per_student, so the change splits exactly into:
--   intake volume  : total intake moved (uniform rate r across all cells)
--   intake mix     : intake moved between cells beyond r (e.g. domestic/international or UG/PG shift)
--   retention      : continuing headcount changed
--   load intensity : load per student changed (more/less part-time study)
-- Revenue adds a rate effect (fee or funding rate per EFTSL changed). Every cell's effects sum to its variance.
with cmp as (
    select * from {{ ref('int_version_comparisons') }}
),
cells as (
    select * from {{ ref('int_load_cells') }}
),
paired as (
    select
        cmp.comparison_code,
        cmp.comparison_name,
        cmp.base_version,
        cmp.compare_version,
        cmp.plan_year,
        b.course_code,
        b.faculty_code,
        b.course_level,
        b.cluster_code,
        b.citizenship,
        b.funding_type,
        b.commencing_intake as intake_b,   c.commencing_intake as intake_c,
        b.continuing_hc as cont_hc_b,      c.continuing_hc as cont_hc_c,
        b.headcount as hc_b,               c.headcount as hc_c,
        b.load_per_student as lps_b,       c.load_per_student as lps_c,
        b.revenue_per_eftsl as rate_b,     c.revenue_per_eftsl as rate_c,
        b.eftsl as eftsl_b,                c.eftsl as eftsl_c,
        b.revenue as revenue_b,            c.revenue as revenue_c
    from cmp
    join cells b on b.version_code = cmp.base_version and b.plan_year = cmp.plan_year
    join cells c on c.version_code = cmp.compare_version and c.plan_year = cmp.plan_year
        and c.course_code = b.course_code and c.citizenship = b.citizenship
),
with_rate as (
    select
        *,
        sum(intake_c) over (partition by comparison_code) / sum(intake_b) over (partition by comparison_code) as intake_ratio
    from paired
),
effects as (
    select
        *,
        (intake_ratio - 1) * intake_b * lps_b               as eftsl_intake_volume,
        (intake_c - intake_ratio * intake_b) * lps_b        as eftsl_intake_mix,
        (cont_hc_c - cont_hc_b) * lps_b                     as eftsl_retention,
        hc_c * (lps_c - lps_b)                              as eftsl_load_intensity
    from with_rate
)
select
    e.comparison_code,
    e.comparison_name,
    e.base_version,
    e.compare_version,
    e.plan_year,
    e.course_code,
    d.course_name,
    e.faculty_code,
    d.faculty_name,
    e.course_level,
    e.cluster_code,
    e.citizenship,
    e.funding_type,
    e.intake_b, e.intake_c,
    e.hc_b, e.hc_c,
    e.eftsl_b, e.eftsl_c,
    e.eftsl_c - e.eftsl_b as eftsl_variance,
    e.eftsl_intake_volume,
    e.eftsl_intake_mix,
    e.eftsl_retention,
    e.eftsl_load_intensity,
    e.revenue_b, e.revenue_c,
    e.revenue_c - e.revenue_b as revenue_variance,
    e.eftsl_intake_volume * e.rate_b   as revenue_intake_volume,
    e.eftsl_intake_mix * e.rate_b      as revenue_intake_mix,
    e.eftsl_retention * e.rate_b       as revenue_retention,
    e.eftsl_load_intensity * e.rate_b  as revenue_load_intensity,
    e.eftsl_c * (e.rate_c - e.rate_b)  as revenue_rate
from effects e
join {{ ref('dim_course') }} d using (course_code)
