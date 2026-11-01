-- Annual load profile for every version (actuals 2019-2025, Budget 2025, Budget/Q1F/Q2F 2026).
select
    l.version_code,
    v.version_name,
    v.version_type,
    l.plan_year,
    l.course_code,
    d.course_name,
    l.faculty_code,
    d.faculty_name,
    l.course_level,
    l.cluster_code,
    l.citizenship,
    l.funding_type,
    l.commencing_intake,
    l.continuing_base_hc,
    l.retention_rate,
    l.load_per_student,
    l.revenue_per_eftsl,
    l.low_ses_share,
    l.first_nations_share,
    l.regional_share,
    l.continuing_hc,
    l.headcount,
    l.commencing_eftsl,
    l.continuing_eftsl,
    l.eftsl,
    l.revenue
from {{ ref('int_load_cells') }} l
join {{ ref('dim_version') }} v using (version_code)
join {{ ref('dim_course') }} d using (course_code)
