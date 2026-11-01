# Analytics framework: from stakeholder questions to boards

This example answers questions a student-load planning team raised. They fall into the four
classic types of analytics. Each type has a board in `charts/` and a dbt mart behind it.

| Type | Question it answers | Stakeholder's words | Board | Mart(s) |
|---|---|---|---|---|
| **Descriptive** | What happened? | "faster analysis of historical actuals to find trends" | `descriptive` | `fct_load_profile`, `fct_load_actuals_term` |
| **Diagnostic** | Why did it happen? | "variance between iterations of load profile, e.g. Q1F vs budget: what changed, what drove change" | `diagnostic` | `fct_load_variance`, `fct_variance_bridge`, `fct_assumption_changes` |
| **Predictive** | What will happen, or what if? | "what if we change the assumption of mix from 50% to 40%"; "predicting final CSP numbers from application data as it comes in" | `predictive_whatif`, `predictive_nowcast` | `fct_load_profile`, `fct_csp_nowcast` |
| **Prescriptive** | What should we do? | "what do we need to do to deliver on a specific student composition, or deliver on government caps" | `prescriptive` | `fct_cap_position`, `fct_intake_recommendations` |
| **Storytelling** | So what? | "visualising effectively for exec ... using AI to tell stories more effectively" | `exec_summary` | all of the above |

## How each one works

### Descriptive
These boards show census actuals 2019–2025 plus 2026 Semester 1, sliced by faculty, citizenship,
level and equity group. Filters run in the query, so every chart on a board responds together.

### Diagnostic: the variance bridge
The load profile is built from assumptions per cell (course × citizenship):

```
headcount = commencing intake + continuing base × retention
EFTSL     = headcount × load per student
revenue   = EFTSL × revenue per EFTSL
```

That makes the change between any two versions split **exactly** into drivers, with no
"unexplained" remainder:

| Driver | Formula (per cell, base `b` → compared `c`) |
|---|---|
| Intake volume | `(r − 1) × intake_b × lps_b`, where `r` = total intake_c / total intake_b |
| Intake mix | `(intake_c − r × intake_b) × lps_b` (domestic/international, UG/PG shifts) |
| Retention | `(continuing_c − continuing_b) × lps_b` |
| Load per student | `headcount_c × (lps_c − lps_b)` |
| Fee/funding rate (revenue only) | `EFTSL_c × (rate_c − rate_b)` |

The test `tests/assert_variance_bridge_reconciles.sql` proves the drivers add up to the total.
`fct_assumption_changes` lists every assumption that moved, with its impact. This is the
"what changed" list a planner otherwise builds by hand. To add a comparison, add a row to
`models/intermediate/int_version_comparisons.sql`.

### Predictive (what-if)
The sliders change the assumptions. The board's SQL recalculates EFTSL and revenue from
`fct_load_profile` in the warehouse, so a new scenario takes seconds, not a model re-run.
- **International mix:** shifts commencing intake between domestic and international while
  keeping the total.
- **Intake and retention:** scale intake and shift retention.

### Predictive (nowcast)
For every week of past admissions cycles, the model divides census commencements by cumulative
applications. Today's applications × the average past ratio at the same week gives the
projection. The lowest and highest past ratios give the range. A leave-one-out backtest shows
the method's accuracy at each week. It is deliberately simple and transparent. A statistical
model, such as one with offers and acceptances as extra features, could replace it later without
changing the board.

### Prescriptive
`fct_cap_position` scores each 2026 plan version against these caps and targets:
- CSP funding envelopes per cluster (load above the envelope earns no CGS).
- The international planning level.
- The low SES, First Nations and regional targets.

`fct_intake_recommendations` turns the gaps into ranked actions with transparent SQL rules:
- Move CSP places from over-envelope clusters into clusters with funded headroom, best funding
  rate first.
- Fill or trim international places by revenue per place.
- Count the equity places each faculty needs.

A true optimiser (for example a linear program maximising revenue subject to all caps) could
write its results to the same table.

### Storytelling
`exec_summary` follows the report pattern: headline numbers, three things to know, why, and
what we recommend. Every number is live (Jinja over query results). Claude drafted the
commentary from the mart results, and a person reviews it before it goes out. On dbtcharts.com
the same boards support conversational questions. Locally, Claude Code can draft new boards with
`dct skills`.

## Data
All data is **synthetic and aggregate**: generic faculties and courses, and illustrative
funding rates and caps. It contains no student-level records and no personal information.
`scripts/generate_data.py` is seeded, so rebuilds are identical. It plants a few stories for
the boards to find:
- An international shortfall in Business and Engineering at Q1F.
- A shift from undergraduate nursing to postgraduate public health.
- An Arts retention dip.
- Lighter study loads in Engineering.
- Cluster C3 over its envelope.
- A strong 2027 applications cycle.
