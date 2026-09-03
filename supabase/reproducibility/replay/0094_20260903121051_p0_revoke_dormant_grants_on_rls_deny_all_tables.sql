DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relkind='r'
      AND c.relrowsecurity
      AND NOT EXISTS (
        SELECT 1 FROM pg_policies p
        WHERE p.schemaname='public' AND p.tablename=c.relname
      )
      AND (
        has_table_privilege('anon',c.oid,'select') OR has_table_privilege('anon',c.oid,'insert') OR has_table_privilege('anon',c.oid,'update') OR has_table_privilege('anon',c.oid,'delete') OR
        has_table_privilege('authenticated',c.oid,'select') OR has_table_privilege('authenticated',c.oid,'insert') OR has_table_privilege('authenticated',c.oid,'update') OR has_table_privilege('authenticated',c.oid,'delete')
      )
  LOOP
    EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM anon, authenticated', r.relname);
  END LOOP;
END $$;
