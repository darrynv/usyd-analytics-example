select
    plan_year,
    cluster_code,
    cluster_name,
    cgs_per_eftsl::numeric as cgs_per_eftsl,
    student_contribution_per_eftsl::numeric as student_contribution_per_eftsl
from {{ ref('funding_rates') }}
