select
    intake_year,
    week_of_cycle,
    course_code,
    applications_cum,
    offers_cum,
    acceptances_cum
from {{ ref('applications_weekly') }}
