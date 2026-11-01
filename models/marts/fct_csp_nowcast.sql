-- Predictive: forecast final domestic CSP undergraduate commencements from applications as they come in.
-- Method: for each week of the cycle, past years tell us census commencements per cumulative application.
-- Projection = this year's applications to date x the average past ratio at the same week; the band is
-- the lowest and highest past ratio. Backtest columns show how accurate the method was for past years
-- (leave-one-out: each year predicted using only the other years).
with apps as (
    select a.*, c.faculty_code
    from {{ ref('stg_applications_weekly') }} a
    join {{ ref('stg_courses') }} c using (course_code)
),
census as (
    select t.census_year as intake_year, c.faculty_code, sum(t.headcount) as census_commencing
    from {{ ref('stg_load_actuals_term') }} t
    join {{ ref('stg_courses') }} c using (course_code)
    where t.term = 'S1' and t.commencement_status = 'Commencing' and t.citizenship = 'Domestic'
      and c.course_level = 'UG' and c.domestic_funding_type = 'CSP'
    group by 1, 2
),
by_scope as (
    -- faculty rows plus a university-wide 'ALL' row
    select intake_year, week_of_cycle, faculty_code,
           sum(applications_cum) as applications_cum, sum(offers_cum) as offers_cum, sum(acceptances_cum) as acceptances_cum
    from apps group by 1, 2, 3
    union all
    select intake_year, week_of_cycle, 'ALL',
           sum(applications_cum), sum(offers_cum), sum(acceptances_cum)
    from apps group by 1, 2
),
census_scope as (
    select intake_year, faculty_code, census_commencing from census
    union all
    select intake_year, 'ALL', sum(census_commencing) from census group by 1
),
hist as (
    select s.*, cs.census_commencing,
           cs.census_commencing::numeric / nullif(s.applications_cum, 0) as conversion_ratio
    from by_scope s
    left join census_scope cs using (intake_year, faculty_code)
),
ratio_stats as (
    select week_of_cycle, faculty_code,
           avg(conversion_ratio) as ratio_avg, min(conversion_ratio) as ratio_min, max(conversion_ratio) as ratio_max,
           sum(conversion_ratio) as ratio_sum, count(conversion_ratio) as ratio_n
    from hist
    where census_commencing is not null
    group by 1, 2
)
select
    h.intake_year,
    h.week_of_cycle,
    h.faculty_code,
    coalesce(f.faculty_name, 'University') as faculty_name,
    h.census_commencing is null as is_current_cycle,
    h.applications_cum,
    h.offers_cum,
    h.acceptances_cum,
    h.census_commencing,
    h.conversion_ratio,
    h.applications_cum * r.ratio_avg as projected_commencing,
    h.applications_cum * r.ratio_min as projected_low,
    h.applications_cum * r.ratio_max as projected_high,
    -- leave-one-out backtest for completed cycles
    case when h.census_commencing is not null then
        h.applications_cum * (r.ratio_sum - h.conversion_ratio) / nullif(r.ratio_n - 1, 0)
    end as backtest_projection,
    case when h.census_commencing is not null then
        h.applications_cum * (r.ratio_sum - h.conversion_ratio) / nullif(r.ratio_n - 1, 0) / h.census_commencing - 1
    end as backtest_error_pct
from hist h
join ratio_stats r using (week_of_cycle, faculty_code)
left join {{ ref('dim_faculty') }} f on f.faculty_code = h.faculty_code
