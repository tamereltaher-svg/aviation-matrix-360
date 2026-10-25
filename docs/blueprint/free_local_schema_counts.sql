-- Read-only Postgres catalog parity query.
-- Both production inventory and disposable CI target use the exact same query.
-- No row data, passwords or unpublished educational content are accessed.
WITH targets AS (
  SELECT oid, nspname FROM pg_namespace
  WHERE nspname IN ('public','assessment','assessment_staging','avi_knowledge','am_blueprint')
)
SELECT t.nspname AS schema_name,
 (SELECT count(*)::int FROM pg_class c WHERE c.relnamespace=t.oid AND c.relkind='r') AS tables,
 (SELECT count(*)::int FROM pg_class c WHERE c.relnamespace=t.oid AND c.relkind IN ('v','m')) AS views,
 (SELECT count(*)::int FROM pg_class c WHERE c.relnamespace=t.oid AND c.relkind='i') AS indexes,
 (SELECT count(*)::int FROM pg_class c WHERE c.relnamespace=t.oid AND c.relkind='r' AND c.relrowsecurity) AS rls_tables,
 (SELECT count(*)::int FROM pg_proc p WHERE p.pronamespace=t.oid AND p.prokind='f') AS functions,
 (SELECT count(*)::int FROM pg_constraint cn JOIN pg_class c ON cn.conrelid=c.oid WHERE c.relnamespace=t.oid) AS constraints,
 (SELECT count(*)::int FROM pg_policy pol JOIN pg_class c ON pol.polrelid=c.oid WHERE c.relnamespace=t.oid) AS policies,
 (SELECT count(*)::int FROM pg_trigger tr JOIN pg_class c ON tr.tgrelid=c.oid WHERE c.relnamespace=t.oid AND NOT tr.tgisinternal) AS triggers
FROM targets t ORDER BY t.nspname;
