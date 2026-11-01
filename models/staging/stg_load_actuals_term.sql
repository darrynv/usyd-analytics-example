select
    census_year,
    term,
    course_code,
    citizenship,
    commencement_status,
    headcount,
    eftsl::numeric as eftsl,
    hc_low_ses,
    hc_first_nations,
    hc_regional
from {{ ref('load_actuals_term') }}
