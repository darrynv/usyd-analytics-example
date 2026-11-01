select
    version_code,
    plan_year,
    course_code,
    citizenship,
    commencing_intake::numeric as commencing_intake,
    continuing_base_hc::numeric as continuing_base_hc,
    retention_rate::numeric as retention_rate,
    load_per_student::numeric as load_per_student,
    revenue_per_eftsl::numeric as revenue_per_eftsl,
    low_ses_share,
    first_nations_share,
    regional_share
from {{ ref('load_assumptions') }}
