-- Aviation Matrix 360 / Master Blueprint v1 — READ-ONLY verification suite
-- Run with a database administrator; never publish candidate or staff data.
-- Expected baseline snapshot: 1 / 118 nodes / 47 edges / 58 evidence.
SELECT s.version_code,s.review_state,s.architecture_version_code,
       s.source_branch,s.manifest_blob_sha,s.created_at
FROM am_blueprint.snapshots s
ORDER BY s.created_at DESC;

SELECT
 (SELECT count(*) FROM am_blueprint.snapshots) blueprint_versions,
 (SELECT count(*) FROM am_blueprint.nodes) blueprint_nodes,
 (SELECT count(*) FROM am_blueprint.edges) blueprint_edges,
 (SELECT count(*) FROM am_blueprint.evidence) blueprint_evidence,
 (SELECT count(*) FROM public.am_platform_domains) existing_original_domains,
 (SELECT count(*) FROM public.am_platform_modules) existing_original_modules,
 (SELECT count(*) FROM public.am_platform_flows) original_flows,
 (SELECT count(*) FROM public.am_platform_roles) original_roles,
 (SELECT count(*) FROM public.am_platform_screens) original_screens;

SELECT 'missing_parent' test,count(*) invalid FROM am_blueprint.nodes n
WHERE n.parent_key IS NOT NULL AND NOT EXISTS
 (SELECT 1 FROM am_blueprint.nodes p WHERE p.snapshot_code=n.snapshot_code AND p.node_key=n.parent_key)
UNION ALL
SELECT 'unresolved_module_fk',count(*) FROM am_blueprint.nodes
 WHERE kind='module' AND original_module_id IS NULL
UNION ALL
SELECT 'missing_edge_endpoint',count(*) FROM am_blueprint.edges e
 WHERE NOT EXISTS (SELECT 1 FROM am_blueprint.nodes n WHERE n.snapshot_code=e.snapshot_code AND n.node_key=e.from_node_key)
 OR NOT EXISTS (SELECT 1 FROM am_blueprint.nodes n WHERE n.snapshot_code=e.snapshot_code AND n.node_key=e.to_node_key)
UNION ALL
SELECT 'missing_evidence_target',count(*) FROM am_blueprint.evidence e
 WHERE NOT EXISTS (SELECT 1 FROM am_blueprint.nodes n WHERE n.snapshot_code=e.snapshot_code AND n.node_key=e.node_key);

SELECT
 c.relname, c.relrowsecurity AS rls_enabled,
 has_schema_privilege('anon','am_blueprint','USAGE') AS anon_schema_access,
 has_schema_privilege('authenticated','am_blueprint','USAGE') AS authenticated_schema_access,
 has_table_privilege('anon',c.oid,'SELECT') AS anon_can_select,
 has_table_privilege('authenticated',c.oid,'SELECT') AS authenticated_can_select,
 has_table_privilege('authenticated',c.oid,'INSERT') AS authenticated_can_insert
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='am_blueprint' AND c.relkind='r'
ORDER BY c.relname;

SELECT version_code,status FROM public.am_platform_architecture_versions WHERE version_code='AM-ARCH-1.0';
SELECT surface, default_locale,visible_locales,language_switcher_enabled,arabic_translations_retained
FROM public.am_platform_language_settings WHERE surface IN ('platform','student') ORDER BY surface;
SELECT 'enrollments' field,count(*) record_count FROM public.am_candidate_learning_enrollments
UNION ALL SELECT 'student_attempts',count(*) FROM public.am_student_lesson_attempts
UNION ALL SELECT 'published_lessons',count(*) FROM avi_knowledge.lesson_versions WHERE status='published';
