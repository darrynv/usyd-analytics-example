-- One row per version x plan year x course x citizenship: the planning "cell".
-- Load is built from assumptions: headcount = intake + continuing base x retention; EFTSL = headcount x load per student.
with a as (
    select * from {{ ref('stg_load_assumptions') }}
),
c as (
    select * from {{ ref('stg_courses') }}
)
select
    a.version_code,
    a.plan_year,
    a.course_code,
    c.faculty_code,
    c.course_level,
    c.cluster_code,
    a.citizenship,
    case when a.citizenship = 'International' then 'INTL' else c.domestic_funding_type end as funding_type,
    a.commencing_intake,
    a.continuing_base_hc,
    a.retention_rate,
    a.load_per_student,
    a.revenue_per_eftsl,
    a.low_ses_share,
    a.first_nations_share,
    a.regional_share,
    a.continuing_base_hc * a.retention_rate as continuing_hc,
    a.commencing_intake + a.continuing_base_hc * a.retention_rate as headcount,
    a.commencing_intake * a.load_per_student as commencing_eftsl,
    a.continuing_base_hc * a.retention_rate * a.load_per_student as continuing_eftsl,
    (a.commencing_intake + a.continuing_base_hc * a.retention_rate) * a.load_per_student as eftsl,
    (a.commencing_intake + a.continuing_base_hc * a.retention_rate) * a.load_per_student * a.revenue_per_eftsl as revenue
from a
join c using (course_code)
