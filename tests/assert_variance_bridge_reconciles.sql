-- Every cell's driver effects must add up exactly to its EFTSL and revenue variance.
select comparison_code, course_code, citizenship
from {{ ref('fct_load_variance') }}
where abs(eftsl_variance - (eftsl_intake_volume + eftsl_intake_mix + eftsl_retention + eftsl_load_intensity)) > 0.001
   or abs(revenue_variance - (revenue_intake_volume + revenue_intake_mix + revenue_retention
                              + revenue_load_intensity + revenue_rate)) > 0.5
