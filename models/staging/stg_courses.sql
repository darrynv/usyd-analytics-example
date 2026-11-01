select
    course_code,
    course_name,
    faculty_code,
    course_level,
    funding_cluster as cluster_code,
    duration_years,
    domestic_funding_type
from {{ ref('courses') }}
