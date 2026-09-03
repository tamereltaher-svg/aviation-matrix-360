alter table assessment.item_versions drop constraint if exists item_versions_scoring_mode_check;
alter table assessment.item_versions add constraint item_versions_scoring_mode_check
check (scoring_mode = any (array[
  'OPTION_KEY'::text,
  'EXACT_KEY'::text,
  'FINITE_KEYSET'::text,
  'BOOLEAN_KEY'::text,
  'MATCH_KEY'::text,
  'ORDER_KEY'::text,
  'ANALYTIC_RUBRIC'::text
]));
