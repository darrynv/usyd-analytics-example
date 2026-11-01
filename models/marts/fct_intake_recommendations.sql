-- Prescriptive: concrete intake actions that bring each 2026 plan version back within caps and targets.
-- Rules (no optimiser; transparent SQL heuristics):
--   1. CSP clusters over their funding envelope: reduce intake by the unfunded load, then redirect the
--      same load to clusters with headroom, best funding rate per EFTSL first.
--   2. International commencements: if over the cap, trim pro rata by faculty; if under, fill headroom
--      in faculties with the highest revenue per place, at most +10% on each faculty's plan.
--   3. Equity targets: for faculties below the target share of domestic UG commencements, the number of
--      commencing places that need to come from the equity group.
with cells as (
    select * from {{ ref('int_load_cells') }} where plan_year = 2026
),
pos as (
    select * from {{ ref('fct_cap_position') }}
),
rates as (
    select * from {{ ref('stg_funding_rates') }} where plan_year = 2026
),
faculties as (
    select * from {{ ref('dim_faculty') }}
),

-- 1. CSP envelope -------------------------------------------------------------------------------
csp_lps as (
    select version_code, cluster_code,
           sum(commencing_intake * load_per_student) / nullif(sum(commencing_intake), 0) as commencing_lps
    from cells where funding_type = 'CSP'
    group by 1, 2
),
csp_pos as (
    select p.version_code, p.scope_code as cluster_code, p.plan_value, p.target_value,
           greatest(p.plan_value - p.target_value, 0) as excess,
           greatest(p.target_value - p.plan_value, 0) as headroom,
           r.cgs_per_eftsl, r.student_contribution_per_eftsl,
           r.cgs_per_eftsl + r.student_contribution_per_eftsl as funding_per_eftsl,
           l.commencing_lps
    from pos p
    join rates r on r.cluster_code = p.scope_code
    join csp_lps l on l.version_code = p.version_code and l.cluster_code = p.scope_code
    where p.cap_type = 'CSP funding envelope'
),
csp_receivers as (
    select *,
           sum(excess) over (partition by version_code) as total_excess,
           coalesce(sum(headroom) over (partition by version_code order by funding_per_eftsl desc
               rows between unbounded preceding and 1 preceding), 0) as headroom_before
    from csp_pos
),
csp_actions as (
    select version_code, 'CSP funding envelope' as lever, cluster_code as scope_code,
           'Reduce CSP intake in cluster ' || cluster_code || ' (load above the envelope earns no CGS)' as action,
           -excess / commencing_lps as places,
           -excess as eftsl_impact,
           -excess * student_contribution_per_eftsl as revenue_impact
    from csp_pos where excess > 0
    union all
    select version_code, 'CSP funding envelope', cluster_code,
           'Redirect CSP places into cluster ' || cluster_code || ' (unused funded headroom)',
           least(headroom, greatest(total_excess - headroom_before, 0)) / commencing_lps,
           least(headroom, greatest(total_excess - headroom_before, 0)),
           least(headroom, greatest(total_excess - headroom_before, 0)) * funding_per_eftsl
    from csp_receivers
    where headroom > 0 and total_excess - headroom_before > 0
),

-- 2. International planning level ---------------------------------------------------------------
intl_cap as (
    select version_code, target_value, plan_value from pos where cap_code = 'INTL-COMM'
),
intl_fac as (
    select version_code, faculty_code, sum(commencing_intake) as intake,
           sum(commencing_intake * load_per_student * revenue_per_eftsl) / nullif(sum(commencing_intake), 0) as revenue_per_place,
           sum(commencing_intake * load_per_student) / nullif(sum(commencing_intake), 0) as lps
    from cells where citizenship = 'International'
    group by 1, 2
),
intl_ranked as (
    select f.*, c.target_value, c.plan_value,
           c.target_value - c.plan_value as headroom,
           coalesce(sum(f.intake * 0.10) over (partition by f.version_code order by f.revenue_per_place desc
               rows between unbounded preceding and 1 preceding), 0) as capacity_before
    from intl_fac f join intl_cap c using (version_code)
),
intl_actions as (
    select version_code, 'International planning level' as lever, faculty_code as scope_code,
           'Trim international commencements pro rata to get under the cap' as action,
           -(plan_value - target_value) * intake / plan_value as places,
           -(plan_value - target_value) * intake / plan_value * lps as eftsl_impact,
           -(plan_value - target_value) * intake / plan_value * revenue_per_place as revenue_impact
    from intl_ranked where headroom < 0
    union all
    select version_code, 'International planning level', faculty_code,
           'Use spare international places (highest revenue per place first)',
           least(intake * 0.10, greatest(headroom - capacity_before, 0)),
           least(intake * 0.10, greatest(headroom - capacity_before, 0)) * lps,
           least(intake * 0.10, greatest(headroom - capacity_before, 0)) * revenue_per_place
    from intl_ranked where headroom > 0 and headroom - capacity_before > 0
),

-- 3. Equity targets -----------------------------------------------------------------------------
eq_fac as (
    select version_code, faculty_code, sum(commencing_intake) as intake,
           sum(commencing_intake * low_ses_share) as low_ses,
           sum(commencing_intake * first_nations_share) as first_nations,
           sum(commencing_intake * regional_share) as regional
    from cells where citizenship = 'Domestic' and course_level = 'UG' and funding_type = 'CSP'
    group by 1, 2
),
eq_targets as (
    select cap_code, target_value from {{ ref('stg_caps_targets') }} where cap_type = 'Equity target' and plan_year = 2026
),
eq_gaps as (
    select e.version_code, e.faculty_code, t.cap_code,
           t.target_value * e.intake - case t.cap_code
               when 'EQ-LOWSES' then e.low_ses
               when 'EQ-FIRSTNATIONS' then e.first_nations
               else e.regional end as gap_places
    from eq_fac e cross join eq_targets t
),
eq_actions as (
    select version_code, 'Equity target' as lever, faculty_code as scope_code,
           'Fill ' || case cap_code when 'EQ-LOWSES' then 'low SES'
                                    when 'EQ-FIRSTNATIONS' then 'First Nations'
                                    else 'regional and remote' end
               || ' places within the planned domestic UG intake' as action,
           gap_places as places, 0::numeric as eftsl_impact, 0::numeric as revenue_impact
    from eq_gaps where gap_places >= 1
),

all_actions as (
    select * from csp_actions
    union all select * from intl_actions
    union all select * from eq_actions
)
select
    a.version_code,
    row_number() over (partition by a.version_code
                       order by case a.lever when 'CSP funding envelope' then 1
                                             when 'International planning level' then 2 else 3 end,
                                abs(a.revenue_impact) desc, a.places desc) as priority,
    a.lever,
    a.scope_code,
    coalesce(f.faculty_name, 'Cluster ' || a.scope_code) as scope_name,
    a.action,
    round(a.places) as places,
    round(a.eftsl_impact, 1) as eftsl_impact,
    round(a.revenue_impact, -3) as revenue_impact
from all_actions a
left join faculties f on f.faculty_code = a.scope_code
where round(a.places) <> 0
