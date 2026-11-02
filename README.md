# usyd-analytics-example

A working example of **descriptive, diagnostic, predictive and prescriptive analytics** for
university student-load planning. It is built with [dbt](https://www.getdbt.com/) on a
[Supabase](https://supabase.com) Postgres warehouse and visualised with
[dbt Charts](https://dbtcharts.com).

> **All data is synthetic.** Generic faculties and courses, illustrative funding rates and caps,
> aggregate counts only. There are no real students and no personal information.

See [docs/analytics-framework.md](docs/analytics-framework.md) for how each stakeholder question
maps to a board, and how the variance bridge, what-if, nowcast and recommendations work.

## Boards

| Board | Analytics type | What it shows |
|---|---|---|
| `descriptive` | Descriptive | Load trends 2019–2026 by faculty, citizenship and level, plus equity groups |
| `diagnostic` | Diagnostic | Budget vs Q1F/Q2F (or any two versions): exact driver bridge and the assumptions that changed |
| `predictive_whatif` | Predictive | Sliders for international mix, intake and retention; EFTSL, revenue and the cap recalculated live |
| `predictive_nowcast` | Predictive | Final 2027 CSP commencements forecast from applications to date, with range and backtest |
| `prescriptive` | Prescriptive | Position against CSP envelopes, the international cap and equity targets, with ranked intake actions |
| `exec_summary` | Storytelling | One-page exec read-out with live numbers and AI-drafted commentary |
| `dvt_example` | Predictive | Each faculty's 2027 CSP commencement forecast against its 2026 census, at a chosen forecast week, with gaps and risks |
| `smoke_test` | Health check | One bar chart of total EFTSL by year, to confirm the connection end to end |

## Architecture

```
scripts/generate_data.py ─► seeds/*.csv ─► dbt seed ─► raw
                                   dbt models ─► staging ─► analytics (marts)
                    dbt Charts boards (charts/*.yml) ─► ref() to marts, read-only role
```

| Path | Contents |
|---|---|
| `models/staging` | Light typing and renaming of the raw seeds (views) |
| `models/intermediate` | `int_load_cells` (the load-profile cell math), `int_version_comparisons` |
| `models/marts` | Facts and dimensions in the `analytics` schema (tables) |
| `tests/` | Bridge reconciliation and range checks, plus schema tests in `models/marts/_marts.yml` |
| `charts/` | dbt Charts boards; `charts/meta.yml` sets the shared source and theme |
| `scripts/setup_roles.sql` | Creates `dbtcharts_reader`, which can read only `analytics` |

## Setup

Prerequisites: [uv](https://docs.astral.sh/uv/) and `psql`.

1. **Credentials.** Copy `.env.example` to `.env` and fill in the Supabase **Session pooler**
   details (dashboard → Connect). `.env` is gitignored.
2. **Python and dbt.**
   ```bash
   uv sync
   ```
3. **(Optional) Regenerate the synthetic data.** The seeds are committed.
   ```bash
   uv run python scripts/generate_data.py
   ```
4. **Build the warehouse:** loads the seeds, builds the models and runs the tests.
   ```bash
   uv run --env-file .env dbt build --profiles-dir .
   ```
5. **Create the read-only role for dbt Charts.** Add `DBTCHARTS_READER_USER=dbtcharts_reader.<project-ref>`
   and a strong `DBTCHARTS_READER_PASSWORD` to `.env`, then run:
   ```bash
   set -a; . ./.env; set +a
   PGPASSWORD="$SUPABASE_DB_PASSWORD" psql "host=$SUPABASE_DB_HOST port=$SUPABASE_DB_PORT user=$SUPABASE_DB_USER dbname=postgres sslmode=require" \
     -v reader_password="$DBTCHARTS_READER_PASSWORD" -f scripts/setup_roles.sql
   ```
6. **Install dbt Charts and preview.**
   ```bash
   uv tool install "dbt-charts[postgresql]"
   set -a; . ./.env; set +a
   dct serve --port 8080                              # http://localhost:8080/diagnostic/ etc.
   ```

### Known issue: dbt-charts 0.10.0 on Windows
The 0.10.0 wheel ships its YAML schema files with CRLF line endings, but `manifest.json` hashes
the LF versions. Every board then fails with
`ERR-INTERNAL ... schema 0.3.0.json sha256 does not match its manifest`. The workaround is to
rewrite each bundled schema file in `dbt_charts/data/schemas/yaml/` with LF endings, but only
where the result matches its published sha256. Reinstalling the package undoes this.

## Hosting on dbtcharts.com
The boards are published at `https://dbtcharts.com/university-of-sydney/usyd-analytics-example/`.
Setup:
1. Connect this GitHub repository as a project.
2. Add a Postgres connection that uses the **`dbtcharts_reader`** role through the Session
   pooler (schema `analytics`).
3. Map the boards' source to it: `dct cloud source map warehouse <connection-slug>`.

Readers need no warehouse login. `dct skills cloud-setup` walks through it from the terminal.

Boards query the marts as `analytics.<model>` rather than `{{ ref('<model>') }}`. dbt Charts
resolves `ref()` from a dbt `manifest.json`, which dbtcharts.com does not build. Fully
qualified names render the same locally and in the cloud, with no generated artifacts to
commit.

## Supabase notes
- The `raw`, `staging` and `analytics` schemas are not exposed through the Supabase Data API;
  only `public` is.
- The Supabase security advisor reports no issues. The performance advisor only notes that the
  small analytics tables have no primary keys, which is expected.
