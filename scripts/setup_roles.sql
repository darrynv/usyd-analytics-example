-- Read-only role for dbt Charts (local dct and dbtcharts.com). Run with:
--   psql "<session pooler URL>" -v reader_password="..." -f scripts/setup_roles.sql
-- It can read the analytics marts only; raw and staging stay private.
select format('create role dbtcharts_reader login password %L', :'reader_password')
where not exists (select 1 from pg_roles where rolname = 'dbtcharts_reader') \gexec
alter role dbtcharts_reader password :'reader_password';
alter role dbtcharts_reader set statement_timeout = '60s';
grant usage on schema analytics to dbtcharts_reader;
grant select on all tables in schema analytics to dbtcharts_reader;
alter default privileges for role postgres in schema analytics grant select on tables to dbtcharts_reader;
