# Board conventions

How boards in this project are written, so new ones match the existing ones in `charts/`.

## Structure
- One board per file in `charts/`, named in snake_case. `charts/meta.yml` sets the source (`warehouse`) and the
  theme (`paper`). Don't repeat them on a board.
- Board `text:` opens with **Synthetic data.** and one or two sentences on scope (which students, which measure).
- Put the key finding in a sentence built from query results
  (`{{ queries.read_out.one.sentence }}`), not in hand-typed numbers that go stale.
- Layout, top to bottom: KPI row, then the main comparison, then trend or detail, then a table.

## Queries
- Schema-qualified `analytics.<table>` only (see `data-model.md`). Use the definitions in `metrics.md`.
- Filter with `{{ filter('column', variable) }}`, never by joining a quoted list.
- For "latest" (latest week, latest year), compute it in SQL. Never hard-code it.
- Give every numeric column a `formats:` entry.
- To reuse a query inside another, write `select * from {{ queries.name }}`. It expands to an aliased subquery,
  so don't wrap it in another pair of brackets.

## Charts
- Titles state the subject. Subtitles state the finding or the scope.
- Label every field with `field_labels`. Tables label columns with `style.columns.<col>.label`.
- Year on an axis: `make_date(year, 1, 1)` for a time axis, or `year::text` for categories.
- Ranges (forecast low–high): a bar with `y_start`, plus a `scatter` layer for the central value.
- Order categorical bars by value, not alphabetically, unless the order is meaningful.

## Before publishing
Run `dct validate` and `dct render <board> --format png`. Fix every `ERR-` and any `WARN-` that affects readability.
