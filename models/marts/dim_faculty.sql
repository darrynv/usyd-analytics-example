select faculty_code, faculty_name
from {{ ref('stg_faculties') }}
