# Metric definitions

The one approved way to calculate each metric. Use this SQL as written, and add only filters
(faculty, citizenship, level) to the `where` clause. If a question needs a metric that isn't here, say so and
state the definition you used.

## Load

**EFTSL, annual (actuals or plan)**
```sql
select plan_year, sum(eftsl) as eftsl
from analytics.fct_load_profile
where version_code = 'ACT'          -- or BUD25, BUD26, Q1F26, Q2F26
group by 1
```

**EFTSL or headcount, semester census**
```sql
select census_year, term, sum(eftsl) as eftsl, sum(headcount) as headcount
from analytics.fct_load_actuals_term
group by 1, 2
```
For 2026, compare `S1` with `S1` of 2025.

**International share of commencing intake (annual)**
```sql
select plan_year,
       sum(commencing_intake) filter (where citizenship = 'International') / sum(commencing_intake) as intl_share
from analytics.fct_load_profile
where version_code = 'ACT'
group by 1
```

**Revenue (annual)**: `sum(revenue)` from `fct_load_profile` for one `version_code`. All dollar amounts are illustrative.

## Equity

**Equity share of domestic UG CSP commencements (S1)**
```sql
select census_year,
       sum(hc_low_ses)::numeric / sum(headcount)       as low_ses,
       sum(hc_regional)::numeric / sum(headcount)      as regional_remote,
       sum(hc_first_nations)::numeric / sum(headcount) as first_nations
from analytics.fct_load_actuals_term
where term = 'S1' and commencement_status = 'Commencing' and citizenship = 'Domestic'
  and course_level = 'UG' and funding_type = 'CSP'
group by 1
```
Targets: low SES 15%, regional and remote 18%, First Nations 3%.

## Variance between versions

**Driver bridge**
```sql
select faculty_name, driver_order, driver, eftsl_effect, revenue_effect
from analytics.fct_variance_bridge
where comparison_code = 'BUD26-Q1F26'
order by faculty_name, driver_order
```
For "what changed", list `fct_assumption_changes` for the same `comparison_code`, ordered by `abs(eftsl_impact)` descending.

## CSP commencements and the 2027 nowcast

**CSP commencements (census)**: domestic UG CSP commencing headcount at the S1 census. 2026 is 7,981.
```sql
select intake_year, faculty_name, max(census_commencing) as census_commencing
from analytics.fct_csp_nowcast
where census_commencing is not null
group by 1, 2
```

**2027 forecast at the latest week, with growth on 2026**
```sql
with latest as (
  select max(week_of_cycle) as w from analytics.fct_csp_nowcast where is_current_cycle
),
c26 as (
  select faculty_code, max(census_commencing) as census_2026
  from analytics.fct_csp_nowcast where intake_year = 2026 group by 1
)
select n.faculty_name, n.week_of_cycle, c26.census_2026,
       n.projected_commencing, n.projected_low, n.projected_high,
       n.projected_commencing / c26.census_2026 - 1 as growth
from analytics.fct_csp_nowcast n
join c26 using (faculty_code)
cross join latest
where n.is_current_cycle and n.week_of_cycle = latest.w
order by growth desc
```
Replace `latest.w` with a chosen week when asked about a specific week.

**Forecast accuracy at a week**: mean absolute leave-one-out error for past cycles.
```sql
select faculty_name, avg(abs(backtest_error_pct)) as backtest_mae
from analytics.fct_csp_nowcast
where not is_current_cycle and week_of_cycle = 14
group by 1
```

**Reporting a forecast:** give the central figure, the low–high range, the week, and the backtest error at that
week together. If the range includes a fall (`projected_low` below the 2026 census), say so.

## Caps

**Position against caps (2026 versions only)**
```sql
select version_code, cap_code, target_value, plan_value, pct_of_target, status, unfunded_cgs_revenue
from analytics.fct_cap_position
order by cap_code, version_code
```
Faculty-to-cluster mapping comes from `dim_course.cluster_code`. A faculty can teach in several clusters.

## Formats
| Measure | Format |
|---|---|
| EFTSL, headcount, places | `integer` |
| Shares (international, equity) | `percent` |
| Growth, variance %, backtest error | `percent_delta` (error as `percent`) |
| Change in a share | `percentage_points_delta` |
| Revenue, CGS | dollars, rounded to $0.1m in prose |
