select
    c.course_code,
    c.course_name,
    c.faculty_code,
    f.faculty_name,
    c.course_level,
    c.cluster_code,
    r.cluster_name,
    c.duration_years,
    c.domestic_funding_type
from {{ ref('stg_courses') }} c
join {{ ref('stg_faculties') }} f using (faculty_code)
left join {{ ref('stg_funding_rates') }} r on r.cluster_code = c.cluster_code and r.plan_year = 2026
