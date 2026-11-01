-- The long-form bridge must total the same variance as the cell-level model.
with bridge as (
    select comparison_code, sum(eftsl_effect) as eftsl, sum(revenue_effect) as revenue
    from {{ ref('fct_variance_bridge') }} group by 1
),
cells as (
    select comparison_code, sum(eftsl_variance) as eftsl, sum(revenue_variance) as revenue
    from {{ ref('fct_load_variance') }} group by 1
)
select * from bridge b join cells c using (comparison_code)
where abs(b.eftsl - c.eftsl) > 0.01 or abs(b.revenue - c.revenue) > 1
