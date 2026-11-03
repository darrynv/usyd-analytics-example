# Data model for the agent

Which table answers which question, the grain of each, and the filters that must always be applied.
All data is **synthetic and aggregate**. There are no students and no personal information.

## Rules that always apply
- Query only `analytics.<table>`, schema-qualified. Never `raw` or `staging` (the reader role can't see them),
  and never `{{ ref() }}` (dbtcharts.com has no dbt manifest).
- Join faculties on `faculty_code`. Show `faculty_name` to readers.
- Never compare annual figures with semester figures. Annual EFTSL (`fct_load_profile`) is about double
  Semester 1 EFTSL (`fct_load_actuals_term`): 2025 is 53,106 annual vs 25,432 in S1.
- Headcount and EFTSL are different measures. Say which one a number is.

## Tables

| Table | Grain | Use it for |
|---|---|---|
| `dim_faculty` | faculty | The 8 faculties: ADP, ART, BUS, ENG, LAW, MED, MUS, SCI |
| `dim_course` | course | Faculty, level (`UG`, `PGCW`, `HDR`), CSP funding cluster (`C1`–`C4`), `domestic_funding_type` |
| `dim_version` | version | `ACT` Actuals, `BUD25`, `BUD26` budgets, `Q1F26`, `Q2F26` forecasts |
| `fct_load_profile` | version × plan_year × course × citizenship | **Annual** headcount, EFTSL and revenue, actuals and plans |
| `fct_load_actuals_term` | census_year × term × course × citizenship × funding_type × commencement_status | **Semester** census actuals 2019 S1 to 2026 S1, with equity headcounts |
| `fct_load_variance` | comparison × plan_year × course × citizenship | Exact driver split of the change between two versions |
| `fct_variance_bridge` | comparison × faculty × driver | The same split, long form, for waterfalls |
| `fct_assumption_changes` | comparison × course × citizenship × assumption | Every assumption that moved, with its impact |
| `fct_csp_nowcast` | intake_year × week_of_cycle × faculty | 2027 CSP commencement forecast from applications, plus backtest |
| `fct_cap_position` | version × cap | 2026 plan versions against CSP envelopes, the international cap and equity targets |
| `fct_intake_recommendations` | version × action | Ranked rule-based intake actions |

## Coverage and traps

**`fct_load_profile`**
- `ACT` covers 2019–2025 only. There is no 2026 actual here. For 2026 use `fct_load_actuals_term` (S1 only).
- `BUD25` is 2025. `BUD26`, `Q1F26` and `Q2F26` are 2026.
- Always filter to one `version_code`, or totals double-count.

**`fct_load_actuals_term`**
- Terms are `S1` and `S2`. 2026 has `S1` only, so year-on-year comparisons for 2026 must be S1 vs S1.
- Equity columns (`hc_low_ses`, `hc_first_nations`, `hc_regional`) are headcounts for domestic students. Divide by
  `headcount` over the same filter to get a share.

**`fct_csp_nowcast`**
- Scope is domestic, undergraduate, CSP, commencing, Semester 1 census headcount. Nothing else.
- `faculty_code = 'ALL'` (`faculty_name = 'University'`) is the university total. Exclude it when listing or summing
  faculties. Use it, not a sum of faculties, for the university figure. The two differ slightly because each is
  forecast separately.
- `is_current_cycle` is true for 2027 only. The latest week is `max(week_of_cycle) where is_current_cycle`. Never
  hard-code a week.
- `census_commencing` repeats on every week row of a past year. Take it from one week or use `max()`, never `sum()`.
- `backtest_*` columns are null for 2027.
- Offers and acceptances are near zero early in the cycle. The forecast uses applications only.

**`fct_cap_position`**
- Only 2026 caps exist. There are no 2027 caps or targets.
- CSP envelopes are measured in EFTSL. Equity targets are shares of domestic UG commencements.
- `status` is one of `On track`, `Over cap`, `Below target`. `unfunded_cgs_revenue` is the CGS not paid above an envelope.

**Variance comparisons** (`comparison_code`): `BUD25-ACT`, `BUD26-Q1F26`, `BUD26-Q2F26`, `Q1F26-Q2F26`.
Drivers in order: Intake volume, Intake mix, Retention, Load per student, Fee and funding rates (revenue only).
The drivers sum exactly to the total variance. There is no "unexplained" bucket.
