-- Census actuals by semester: 2019 S1 to 2026 S1.
select
    t.census_year,
    t.term,
    make_date(t.census_year, case t.term when 'S1' then 3 else 8 end, 31) as census_date,
    t.course_code,
    d.course_name,
    d.faculty_code,
    d.faculty_name,
    d.course_level,
    d.cluster_code,
    t.citizenship,
    case when t.citizenship = 'International' then 'INTL' else d.domestic_funding_type end as funding_type,
    t.commencement_status,
    t.headcount,
    t.eftsl,
    t.hc_low_ses,
    t.hc_first_nations,
    t.hc_regional
from {{ ref('stg_load_actuals_term') }} t
join {{ ref('dim_course') }} d using (course_code)
