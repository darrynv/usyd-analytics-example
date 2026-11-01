-- The load-profile iterations we compare. Add a row to compare another pair.
select * from (values
    ('BUD26-Q1F26', 'Budget 2026 vs Q1 Forecast', 'BUD26', 'Q1F26', 2026, 1),
    ('Q1F26-Q2F26', 'Q1 Forecast vs Q2 Forecast', 'Q1F26', 'Q2F26', 2026, 2),
    ('BUD26-Q2F26', 'Budget 2026 vs Q2 Forecast', 'BUD26', 'Q2F26', 2026, 3),
    ('BUD25-ACT', 'Budget 2025 vs 2025 Actuals', 'BUD25', 'ACT', 2025, 4)
) as t(comparison_code, comparison_name, base_version, compare_version, plan_year, sort_order)
