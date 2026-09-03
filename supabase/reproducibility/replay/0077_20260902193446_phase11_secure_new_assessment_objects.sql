do $do$
declare r record;
begin
  for r in
    select n.nspname,c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('assessment','assessment_staging')
      and c.relkind in ('r','p')
      and not c.relrowsecurity
  loop
    execute format('alter table %I.%I enable row level security',r.nspname,r.relname);
  end loop;
end $do$;

revoke all privileges on all functions in schema assessment from public, anon, authenticated;
revoke all privileges on all functions in schema assessment_staging from public, anon, authenticated;

alter default privileges in schema assessment revoke execute on functions from public;
alter default privileges in schema assessment revoke execute on functions from anon;
alter default privileges in schema assessment revoke execute on functions from authenticated;
alter default privileges in schema assessment_staging revoke execute on functions from public;
alter default privileges in schema assessment_staging revoke execute on functions from anon;
alter default privileges in schema assessment_staging revoke execute on functions from authenticated;
