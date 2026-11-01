select version_code, plan_year, course_code, citizenship
from {{ ref('int_load_cells') }}
where retention_rate not between 0 and 1
   or load_per_student not between 0 and 1.5
   or coalesce(low_ses_share, 0) not between 0 and 1
   or coalesce(first_nations_share, 0) not between 0 and 1
   or coalesce(regional_share, 0) not between 0 and 1
