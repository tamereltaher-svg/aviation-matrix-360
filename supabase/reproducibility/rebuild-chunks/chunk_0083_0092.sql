-- BEGIN CANONICAL MIGRATION 0083 20260902215407 phase11_phase06_inventory_expansion_compatibility

create or replace function assessment.assert_phase06_configuration(p_bank_id uuid)
returns void
language plpgsql
set search_path to ''
as $function$
declare
  v_count integer;
  v_total integer;
  v_rdg integer;
  v_lng integer;
  v_launch_fe integer;
  v_band text;
  v_expected integer;
  v_actual integer;
  v_manifest_total integer;
  v_manifest_rdg integer;
  v_manifest_lng integer;
  v_max_release integer;
  v_original_release_count integer;
  v_original_release_total integer;
begin
  select launch_form_equivalents into v_launch_fe
  from assessment.assessment_banks
  where id=p_bank_id and bank_code='ENG-GENERAL-P06';

  if v_launch_fe is null then
    raise exception 'ENG-GENERAL-P06 bank not found' using errcode='23514';
  end if;
  if v_launch_fe <> 6 then
    raise exception 'Phase 06 launch_form_equivalents must equal 6, found %',v_launch_fe using errcode='23514';
  end if;

  select count(*),coalesce(sum(item_count_expected),0),coalesce(max(release_number),0)
    into v_count,v_total,v_max_release
  from assessment.releases
  where bank_id=p_bank_id;

  select count(*),
         count(*) filter(where skill_code='RDG'),
         count(*) filter(where skill_code='LNG')
    into v_manifest_total,v_manifest_rdg,v_manifest_lng
  from assessment.phase06_expected_item_identities
  where bank_id=p_bank_id;

  if v_count=0 or v_count<>v_max_release then
    raise exception 'Release ledger must be contiguous from 1 through %, found % releases',
      v_max_release,v_count using errcode='23514';
  end if;

  if exists (
    select 1
    from generate_series(1,v_max_release) g(n)
    left join assessment.releases r
      on r.bank_id=p_bank_id and r.release_number=g.n
    where r.id is null
  ) then
    raise exception 'Release ledger has a missing release number in 1..%',v_max_release using errcode='23514';
  end if;

  if v_total<>v_manifest_total then
    raise exception 'Release ledger expected-item total % does not match identity manifest %',
      v_total,v_manifest_total using errcode='23514';
  end if;

  select count(*),coalesce(sum(item_count_expected),0)
    into v_original_release_count,v_original_release_total
  from assessment.releases
  where bank_id=p_bank_id and release_number between 1 and 14;

  if v_original_release_count<>14 or v_original_release_total<>1536 then
    raise exception 'Frozen original release ledger mismatch: releases %, total %, expected 14 / 1536',
      v_original_release_count,v_original_release_total using errcode='23514';
  end if;

  select count(*), coalesce(sum(required_item_count*v_launch_fe),0),
         coalesce(sum(required_item_count*v_launch_fe) filter(where skill_code='RDG'),0),
         coalesce(sum(required_item_count*v_launch_fe) filter(where skill_code='LNG'),0)
    into v_count,v_total,v_rdg,v_lng
  from assessment.form_blueprint_requirements
  where bank_id=p_bank_id;

  if v_count<>12 then
    raise exception 'Form blueprint must contain 12 Level x Skill rows, found %',v_count using errcode='23514';
  end if;
  if v_total<>1536 or v_rdg<>798 or v_lng<>738 then
    raise exception 'Blueprint launch capacity mismatch: total %, RDG %, LNG %, expected 1536/798/738',
      v_total,v_rdg,v_lng using errcode='23514';
  end if;
  if v_manifest_rdg<v_rdg or v_manifest_lng<v_lng then
    raise exception 'Identity inventory is below six-form blueprint capacity: manifest RDG/LNG %/%; required %/%',
      v_manifest_rdg,v_manifest_lng,v_rdg,v_lng using errcode='23514';
  end if;
  if exists (
    select 1 from assessment.form_blueprint_requirements
    where bank_id=p_bank_id and skill_code not in ('RDG','LNG')
  ) then
    raise exception 'Phase 06 form blueprint may contain only RDG/LNG' using errcode='23514';
  end if;

  select count(*),coalesce(sum(target_count),0)
    into v_count,v_total
  from assessment.difficulty_distribution_targets
  where bank_id=p_bank_id;

  if v_count<>48 or v_total<>1536 then
    raise exception 'Difficulty matrix mismatch: rows %, total %, expected 48 / 1536',
      v_count,v_total using errcode='23514';
  end if;

  if exists (
    select 1
    from assessment.form_blueprint_requirements r
    left join lateral (
      select coalesce(sum(d.target_count),0)::integer as diff_total
      from assessment.difficulty_distribution_targets d
      where d.bank_id=r.bank_id
        and d.cefr_level=r.cefr_level
        and d.skill_code=r.skill_code
    ) x on true
    where r.bank_id=p_bank_id
      and x.diff_total <> r.required_item_count*v_launch_fe
  ) then
    raise exception 'At least one Level x Skill difficulty total does not equal its six-form capacity' using errcode='23514';
  end if;

  foreach v_band in array array['D1','D2','D3','D4'] loop
    v_expected := case v_band when 'D1' then 306 when 'D2' then 768 when 'D3' then 306 else 156 end;
    select coalesce(sum(target_count),0) into v_actual
    from assessment.difficulty_distribution_targets
    where bank_id=p_bank_id and difficulty_band=v_band;
    if v_actual<>v_expected then
      raise exception 'Difficulty % total % does not equal expected %',v_band,v_actual,v_expected using errcode='23514';
    end if;
  end loop;

  select count(*) into v_count
  from assessment.forms
  where bank_id=p_bank_id;
  if v_count<>36 then
    raise exception 'Expected 36 Phase 06 form identities, found %',v_count using errcode='23514';
  end if;

  if exists (
    select l.cefr_level,f.form_family
    from (values ('A1'),('A2'),('B1'),('B2'),('C1'),('C2')) l(cefr_level)
    cross join (values ('A'),('B'),('C'),('R1'),('R2'),('PILOT')) f(form_family)
    left join assessment.forms af
      on af.bank_id=p_bank_id and af.cefr_level=l.cefr_level and af.form_family=f.form_family
    where af.id is null
  ) then
    raise exception 'One or more required A/B/C/R1/R2/PILOT form identities are missing' using errcode='23514';
  end if;

  select count(*) into v_count
  from assessment.forms f
  join assessment.form_versions fv on fv.id=f.current_version_id
  where f.bank_id=p_bank_id
    and fv.form_id=f.id
    and fv.is_current;
  if v_count<>36 then
    raise exception 'Expected 36 valid current form-version pointers, found %',v_count using errcode='23514';
  end if;
end
$function$;

create or replace function assessment.assert_phase06_identity_manifest(p_bank_id uuid)
returns void
language plpgsql
set search_path to ''
as $function$
declare
  v_total integer;
  v_rdg integer;
  v_lng integer;
  v_gap integer;
  v_rec integer;
  v_bad integer;
  v_release_total integer;
  v_required_rdg integer;
  v_required_lng integer;
begin
  select count(*),
         count(*) filter(where skill_code='RDG'),
         count(*) filter(where skill_code='LNG'),
         count(*) filter(where source_expectation='LEGACY_SOURCE_GAP'),
         count(*) filter(where source_expectation='RECOVERABLE_SOURCE_EXPECTED')
    into v_total,v_rdg,v_lng,v_gap,v_rec
  from assessment.phase06_expected_item_identities
  where bank_id=p_bank_id;

  if v_total=0 or v_total<>v_rdg+v_lng or v_total<>v_gap+v_rec then
    raise exception 'Phase06 identity manifest internal reconciliation failed total/RDG/LNG/gap/recoverable = %/%/%/%/%',
      v_total,v_rdg,v_lng,v_gap,v_rec using errcode='23514';
  end if;

  select coalesce(sum(item_count_expected),0) into v_release_total
  from assessment.releases
  where bank_id=p_bank_id;

  if v_total<>v_release_total then
    raise exception 'Phase06 identity manifest total % does not match release ledger %',
      v_total,v_release_total using errcode='23514';
  end if;

  select
    coalesce(sum(r.required_item_count*b.launch_form_equivalents) filter(where r.skill_code='RDG'),0),
    coalesce(sum(r.required_item_count*b.launch_form_equivalents) filter(where r.skill_code='LNG'),0)
    into v_required_rdg,v_required_lng
  from assessment.form_blueprint_requirements r
  join assessment.assessment_banks b on b.id=r.bank_id
  where r.bank_id=p_bank_id;

  if v_rdg<v_required_rdg or v_lng<v_required_lng then
    raise exception 'Phase06 identity manifest is below blueprint capacity RDG/LNG = %/%; required %/%',
      v_rdg,v_lng,v_required_rdg,v_required_lng using errcode='23514';
  end if;

  select count(*) into v_bad
  from assessment.releases r
  left join lateral (
    select count(*) c
    from assessment.phase06_expected_item_identities e
    where e.release_id=r.id
  ) x on true
  where r.bank_id=p_bank_id and coalesce(x.c,0)<>r.item_count_expected;

  if v_bad>0 then
    raise exception 'Phase06 identity manifest has % release-count mismatches',v_bad using errcode='23514';
  end if;
end
$function$;

create or replace function assessment.phase06_master_import_readiness(p_bank_id uuid)
returns table(metric_code text, expected_value integer, actual_value integer, status text)
language sql
stable
set search_path to ''
as $function$
with m as (
  select
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id) exp_total,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.skill_code='RDG') exp_rdg,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.skill_code='LNG') exp_lng,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.source_expectation='RECOVERABLE_SOURCE_EXPECTED') exp_rec,
    (select count(*)::int from assessment.phase06_expected_item_identities e where e.bank_id=p_bank_id and e.source_expectation='LEGACY_SOURCE_GAP') exp_gap,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id) act_total,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id and i.skill_code='RDG') act_rdg,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id and i.skill_code='LNG') act_lng,
    (select count(*)::int from assessment.items i where i.bank_id=p_bank_id and i.current_version_id is not null) hydrated,
    (select count(*)::int
     from assessment.items i
     join assessment.phase06_expected_item_identities e
       on e.bank_id=i.bank_id and e.item_code=i.item_code
     where i.bank_id=p_bank_id
       and e.source_expectation='LEGACY_SOURCE_GAP'
       and i.current_version_id is null) remaining_gap
)
select 'IDENTITY_TOTAL',exp_total,act_total,case when act_total=exp_total then 'PASS' else 'FAIL' end from m
union all
select 'READING_IDENTITIES',exp_rdg,act_rdg,case when act_rdg=exp_rdg then 'PASS' else 'FAIL' end from m
union all
select 'LNG_IDENTITIES',exp_lng,act_lng,case when act_lng=exp_lng then 'PASS' else 'FAIL' end from m
union all
select 'EXPECTED_RECOVERABLE_SOURCE_CLASS',exp_rec,exp_rec,'PASS' from m
union all
select 'EXPECTED_LEGACY_SOURCE_GAP_CLASS',exp_gap,exp_gap,'PASS' from m
union all
select 'CURRENTLY_HYDRATED_ITEMS',exp_rec,hydrated,case when hydrated>=exp_rec then 'TARGET_MET' else 'IN_PROGRESS' end from m
union all
select 'LEGACY_ROWS_STILL_WITHOUT_CONTENT',0,remaining_gap,case when remaining_gap=0 then 'RECOVERED' else 'SOURCE_GAP_REMAINS' end from m;
$function$;

revoke execute on function assessment.assert_phase06_configuration(uuid) from public, anon, authenticated;
revoke execute on function assessment.assert_phase06_identity_manifest(uuid) from public, anon, authenticated;
revoke execute on function assessment.phase06_master_import_readiness(uuid) from public, anon, authenticated;
-- END CANONICAL MIGRATION 0083

-- BEGIN CANONICAL MIGRATION 0084 20260902215808 phase11_fix_phase06_stimulus_staging_status

do $migration$
declare
  v_def text;
  v_anchor text := 'return query select case when v_block=0 then ''PASS'' else ''FAIL'' end,v_block,v_warn;';
  v_replacement text := $inject$
update assessment_staging.phase06_stimuli_import s
  set row_status=case when exists(
    select 1
    from assessment.phase06_item_import_findings f
    where f.batch_id=p_batch_id
      and f.rule_code like 'P06STM%'
      and f.severity='BLOCKER'
      and f.status='OPEN'
      and f.item_code is null
      and f.row_number=s.row_number
  ) then 'FAIL' else 'PASS' end
  where s.batch_id=p_batch_id;
  return query select case when v_block=0 then 'PASS' else 'FAIL' end,v_block,v_warn;
$inject$;
begin
  select pg_get_functiondef('assessment.validate_phase06_item_import_batch(uuid)'::regprocedure)
    into v_def;

  if strpos(v_def, v_anchor)=0 then
    raise exception 'Expected validation return anchor not found; migration aborted';
  end if;

  v_def := replace(v_def, v_anchor, v_replacement);
  execute v_def;
end
$migration$;

revoke execute on function assessment.validate_phase06_item_import_batch(uuid)
  from public, anon, authenticated;
-- END CANONICAL MIGRATION 0084

-- BEGIN CANONICAL MIGRATION 0085 20260902221430 phase11_fix_phase06_assembly_validator_alias_collision

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('assessment.validate_phase06_form_assembly_attempt(uuid)'::regprocedure)
    into v_def;

  if strpos(v_def,'select r.* into v_run')=0
     or strpos(v_def,'join assessment.form_assembly_runs r on r.id=a.run_id')=0 then
    raise exception 'Expected validator alias anchors not found; migration aborted';
  end if;

  v_def := replace(v_def,
    'select r.* into v_run',
    'select run_row.* into v_run');
  v_def := replace(v_def,
    'join assessment.form_assembly_runs r on r.id=a.run_id',
    'join assessment.form_assembly_runs run_row on run_row.id=a.run_id');

  execute v_def;
end
$migration$;

revoke execute on function assessment.validate_phase06_form_assembly_attempt(uuid)
  from public, anon, authenticated;
-- END CANONICAL MIGRATION 0085

-- BEGIN CANONICAL MIGRATION 0086 20260903101604 p0_secure_exposed_public_tables_and_internal_rpcs
-- P0 security regression remediation: exposed public tables + privileged internal RPC surface.

-- 1) Candidate lifetime data: private to trusted server-side paths only.
alter table public.am_candidate_lifetime_events enable row level security;
alter table public.am_candidate_lifetime_snapshots enable row level security;
alter table public.am_candidate_current_state enable row level security;

revoke all privileges on table public.am_candidate_lifetime_events from anon, authenticated;
revoke all privileges on table public.am_candidate_lifetime_snapshots from anon, authenticated;
revoke all privileges on table public.am_candidate_current_state from anon, authenticated;

-- 2) Kids brand governance: preserve public read of approved/active material,
-- while removing all client-side mutation privileges.
alter table public.kids_brand_profiles enable row level security;
alter table public.kids_brand_versions enable row level security;
alter table public.kids_brand_logo_assets enable row level security;
alter table public.kids_brand_logo_rules enable row level security;
alter table public.kids_brand_placement_rules enable row level security;

revoke insert, update, delete, truncate, references, trigger
  on table public.kids_brand_profiles,
           public.kids_brand_versions,
           public.kids_brand_logo_assets,
           public.kids_brand_logo_rules,
           public.kids_brand_placement_rules
  from anon, authenticated;

grant select
  on table public.kids_brand_profiles,
           public.kids_brand_versions,
           public.kids_brand_logo_assets,
           public.kids_brand_logo_rules,
           public.kids_brand_placement_rules
  to anon, authenticated;

-- Recreate narrowly scoped read policies idempotently.
drop policy if exists kids_brand_profiles_public_read on public.kids_brand_profiles;
create policy kids_brand_profiles_public_read
  on public.kids_brand_profiles
  for select
  to anon, authenticated
  using (status = 'active');

drop policy if exists kids_brand_versions_public_read on public.kids_brand_versions;
create policy kids_brand_versions_public_read
  on public.kids_brand_versions
  for select
  to anon, authenticated
  using (
    lifecycle_status = 'locked'
    and exists (
      select 1
      from public.kids_brand_profiles bp
      where bp.id = kids_brand_versions.brand_profile_id
        and bp.status = 'active'
    )
  );

drop policy if exists kids_brand_logo_assets_public_read on public.kids_brand_logo_assets;
create policy kids_brand_logo_assets_public_read
  on public.kids_brand_logo_assets
  for select
  to anon, authenticated
  using (
    approval_status in ('approved','locked')
    and exists (
      select 1
      from public.kids_brand_profiles bp
      where bp.id = kids_brand_logo_assets.brand_profile_id
        and bp.status = 'active'
    )
  );

drop policy if exists kids_brand_logo_rules_public_read on public.kids_brand_logo_rules;
create policy kids_brand_logo_rules_public_read
  on public.kids_brand_logo_rules
  for select
  to anon, authenticated
  using (
    is_active
    and exists (
      select 1
      from public.kids_brand_profiles bp
      where bp.id = kids_brand_logo_rules.brand_profile_id
        and bp.status = 'active'
    )
  );

drop policy if exists kids_brand_placement_rules_public_read on public.kids_brand_placement_rules;
create policy kids_brand_placement_rules_public_read
  on public.kids_brand_placement_rules
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.kids_brand_profiles bp
      where bp.id = kids_brand_placement_rules.brand_profile_id
        and bp.status = 'active'
    )
  );

-- 3) Remove direct Data API execution of privileged/internal SECURITY DEFINER helpers.
-- Trusted Edge Functions use service_role and remain unaffected.
revoke execute on function public.am_activate_registration_application(uuid,uuid) from public, anon, authenticated;
revoke execute on function public.am_append_candidate_lifetime_event(uuid,text,text,text,text,jsonb,text,text,uuid,uuid,timestamp with time zone,uuid) from public, anon, authenticated;
revoke execute on function public.am_capture_candidate_lifetime_snapshot(uuid,text,uuid) from public, anon, authenticated;
revoke execute on function public.am_recalculate_registration_gate(uuid) from public, anon, authenticated;
revoke execute on function public.am_refresh_candidate_assessment_state(uuid) from public, anon, authenticated;
revoke execute on function public.am_registration_required_documents(uuid) from public, anon, authenticated;
revoke execute on function public.calculate_assessment_career_fit(uuid,text) from public, anon, authenticated;
revoke execute on function public.make_application_number() from public, anon, authenticated;
revoke execute on function public.guard_public_lead_duplicates() from public, anon, authenticated;
revoke execute on function public.kids_get_character_lock_bundle(uuid) from public, anon, authenticated;

-- 4) Harden future defaults: public exposure becomes explicit opt-in.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from anon, authenticated;
-- END CANONICAL MIGRATION 0086

-- BEGIN CANONICAL MIGRATION 0087 20260903101713 p0_harden_security_definer_views
-- P0: eliminate SECURITY DEFINER view exposure while preserving trusted service-role access.
alter view public.am_candidate_lifetime_summary set (security_invoker = true);
alter view public.am_candidate_assessment_journey_summary set (security_invoker = true);
alter view public.kids_brand_logo_readiness set (security_invoker = true);

revoke all privileges on table public.am_candidate_lifetime_summary from anon, authenticated;
revoke all privileges on table public.am_candidate_assessment_journey_summary from anon, authenticated;
revoke all privileges on table public.kids_brand_logo_readiness from anon, authenticated;

grant select on table public.am_candidate_lifetime_summary to service_role;
grant select on table public.am_candidate_assessment_journey_summary to service_role;
grant select on table public.kids_brand_logo_readiness to service_role;
-- END CANONICAL MIGRATION 0087

-- BEGIN CANONICAL MIGRATION 0088 20260903103408 temporary_enable_http_for_authorization_runtime_verification
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0088

-- BEGIN CANONICAL MIGRATION 0089 20260903103713 disable_temporary_http_after_authorization_runtime_verification
drop extension if exists http;
-- END CANONICAL MIGRATION 0089

-- BEGIN CANONICAL MIGRATION 0090 20260903115345 p0_security_least_privilege_and_phase06_scope
-- P0 security repair: least privilege grants + RPC hardening + Phase06 reviewer scope enforcement

-- 1) Exact exposed public tables: keep RLS, reduce Data API grants to intended use.
REVOKE ALL PRIVILEGES ON TABLE public.staff_accounts FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.staff_accounts FROM authenticated;
GRANT SELECT ON TABLE public.staff_accounts TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.staff_permissions FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.staff_permissions FROM authenticated;
GRANT SELECT ON TABLE public.staff_permissions TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.store_admins FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_admins FROM authenticated;
GRANT SELECT ON TABLE public.store_admins TO authenticated;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_products FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_product_variants FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_product_images FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_personalization_options FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_product_audiences FROM anon, authenticated;
GRANT SELECT ON TABLE public.store_products, public.store_product_variants, public.store_product_images, public.store_personalization_options, public.store_product_audiences TO anon, authenticated;

-- 2) Staff helper functions do not need to bypass RLS. Make them invoker-rights and Auth-only.
ALTER FUNCTION public.has_staff_permission(text) SECURITY INVOKER;
ALTER FUNCTION public.is_active_staff() SECURITY INVOKER;
ALTER FUNCTION public.is_store_admin() SECURITY INVOKER;

REVOKE ALL PRIVILEGES ON FUNCTION public.has_staff_permission(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.is_active_staff() FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.is_store_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_staff_permission(text), public.is_active_staff(), public.is_store_admin() TO authenticated, service_role;

-- 3) Retain legacy no-token assessment RPCs for server compatibility, but remove direct public execution.
REVOKE ALL PRIVILEGES ON FUNCTION public.start_public_career_assessment(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.submit_public_assessment_answer(uuid,uuid,uuid,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.finish_public_career_assessment(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.start_public_career_assessment(uuid,text), public.submit_public_assessment_answer(uuid,uuid,uuid,integer), public.finish_public_career_assessment(uuid,text) TO service_role;

-- Auth-bound resume RPCs should not be callable as anon.
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_application_auth(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_assessment_auth(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.public_resume_application_auth(text), public.public_resume_assessment_auth(text) TO authenticated, service_role;

-- Make intentional public application/assessment RPC exposure explicit instead of inheriting PUBLIC execute.
REVOKE ALL PRIVILEGES ON FUNCTION public.public_register_application(text,text,text,date,text,text,text,text,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_application(text,text,date) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_assessment(text,text,date) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_start_assessment(text,text,date,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_finish_assessment(uuid,uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.public_register_application(text,text,text,date,text,text,text,text,boolean), public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean), public.public_resume_application(text,text,date), public.public_resume_assessment(text,text,date), public.public_start_assessment(text,text,date,text), public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer), public.public_finish_assessment(uuid,uuid,text) TO anon, authenticated, service_role;

-- 4) Phase06 reviewer scope must be enforced for every read/navigation/write path.
CREATE OR REPLACE FUNCTION assessment.is_phase06_reviewer_for_item(
  p_auth_user_id uuid,
  p_item_version_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM assessment.phase06_reviewer_queue_console q
    WHERE q.item_version_id = p_item_version_id
      AND assessment.is_phase06_reviewer(p_auth_user_id, q.cefr_level, q.skill_code)
  );
$$;

CREATE OR REPLACE FUNCTION assessment.get_phase06_review_queue_scoped(
  p_reviewer_id uuid,
  p_cefr_level text DEFAULT NULL,
  p_skill_code text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_release_code text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit,50),1),200);
  v_offset integer := greatest(coalesce(p_offset,0),0);
  v_result jsonb;
BEGIN
  IF p_reviewer_id IS NULL OR NOT assessment.is_phase06_reviewer(p_reviewer_id,NULL,NULL) THEN
    RAISE EXCEPTION 'REVIEWER_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;
  IF p_cefr_level IS NOT NULL AND p_cefr_level NOT IN ('A1','A2','B1','B2','C1','C2') THEN
    RAISE EXCEPTION 'Unsupported CEFR level %', p_cefr_level USING ERRCODE='23514';
  END IF;
  IF p_skill_code IS NOT NULL AND p_skill_code NOT IN ('LNG','RDG') THEN
    RAISE EXCEPTION 'Unsupported skill_code %', p_skill_code USING ERRCODE='23514';
  END IF;

  WITH scoped AS MATERIALIZED (
    SELECT q.*
    FROM assessment.phase06_reviewer_queue_console q
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code)
      AND (p_cefr_level IS NULL OR q.cefr_level=p_cefr_level)
      AND (p_skill_code IS NULL OR q.skill_code=p_skill_code)
      AND (p_status IS NULL OR q.pre_pilot_review_status=p_status)
      AND (p_release_code IS NULL OR q.release_code=p_release_code)
  ), page_rows AS (
    SELECT * FROM scoped q
    ORDER BY q.queue_priority,q.cefr_sort_order,q.skill_sort_order,q.sequence_number,q.item_code
    LIMIT v_limit OFFSET v_offset
  )
  SELECT jsonb_build_object(
    'total',(SELECT count(*) FROM scoped),
    'limit',v_limit,
    'offset',v_offset,
    'rows',coalesce((SELECT jsonb_agg(to_jsonb(p) - 'gate_matrix' ORDER BY p.queue_priority,p.cefr_sort_order,p.skill_sort_order,p.sequence_number,p.item_code) FROM page_rows p),'[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION assessment.get_phase06_review_progress_scoped(
  p_reviewer_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE v_result jsonb;
BEGIN
  IF p_reviewer_id IS NULL OR NOT assessment.is_phase06_reviewer(p_reviewer_id,NULL,NULL) THEN
    RAISE EXCEPTION 'REVIEWER_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  WITH scoped AS MATERIALIZED (
    SELECT q.*
    FROM assessment.phase06_reviewer_queue_console q
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code)
  ), overall AS (
    SELECT
      count(*)::integer AS total_items,
      count(*) FILTER (WHERE pre_pilot_review_status='NOT_STARTED')::integer AS not_started,
      count(*) FILTER (WHERE pre_pilot_review_status='IN_REVIEW')::integer AS in_review,
      count(*) FILTER (WHERE pre_pilot_review_status='ACTION_REQUIRED')::integer AS action_required,
      count(*) FILTER (WHERE pre_pilot_review_status='REJECTED')::integer AS rejected,
      count(*) FILTER (WHERE pre_pilot_review_status IN ('COMPLETE','COMPLETE_WITH_EDIT'))::integer AS review_complete,
      count(*) FILTER (WHERE primary_lo_mapping_status='HUMAN_CONFIRMED')::integer AS lo_human_confirmed,
      count(*) FILTER (WHERE approval_status='APPROVED')::integer AS approved_versions
    FROM scoped
  ), dims AS (
    SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY
      CASE p.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
      p.skill_code),'[]'::jsonb) AS rows
    FROM assessment.phase06_review_progress_console p
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,p.cefr_level,p.skill_code)
  )
  SELECT jsonb_build_object('overall',to_jsonb(o),'by_level_skill',d.rows)
  INTO v_result
  FROM overall o CROSS JOIN dims d;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION assessment.get_phase06_review_neighbor_scoped(
  p_reviewer_id uuid,
  p_item_version_id uuid,
  p_direction text DEFAULT 'NEXT',
  p_status text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_dir text := upper(trim(coalesce(p_direction,'NEXT')));
  v_current record;
  v_target record;
BEGIN
  IF v_dir NOT IN ('NEXT','PREVIOUS') THEN
    RAISE EXCEPTION 'Direction must be NEXT or PREVIOUS' USING ERRCODE='23514';
  END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('NOT_STARTED','IN_REVIEW','ACTION_REQUIRED','REJECTED','COMPLETE_WITH_EDIT','COMPLETE') THEN
    RAISE EXCEPTION 'Unsupported review status %', p_status USING ERRCODE='23514';
  END IF;

  SELECT q.* INTO v_current
  FROM assessment.phase06_reviewer_queue_console q
  WHERE q.item_version_id=p_item_version_id
    AND assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'REVIEW_SCOPE_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  SELECT q.* INTO v_target
  FROM assessment.phase06_reviewer_queue_console q
  WHERE assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code)
    AND (p_status IS NULL OR q.pre_pilot_review_status=p_status)
    AND (
      (v_dir='NEXT' AND (q.cefr_sort_order,q.skill_sort_order,q.sequence_number,q.item_code) > (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
      OR
      (v_dir='PREVIOUS' AND (q.cefr_sort_order,q.skill_sort_order,q.sequence_number,q.item_code) < (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
    )
  ORDER BY
    CASE WHEN v_dir='NEXT' THEN q.cefr_sort_order END ASC,
    CASE WHEN v_dir='NEXT' THEN q.skill_sort_order END ASC,
    CASE WHEN v_dir='NEXT' THEN q.sequence_number END ASC,
    CASE WHEN v_dir='NEXT' THEN q.item_code END ASC,
    CASE WHEN v_dir='PREVIOUS' THEN q.cefr_sort_order END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN q.skill_sort_order END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN q.sequence_number END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN q.item_code END DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('direction',v_dir,'item_version_id',NULL,'item_code',NULL,'boundary_reached',true);
  END IF;
  RETURN jsonb_build_object(
    'direction',v_dir,'item_version_id',v_target.item_version_id,'item_code',v_target.item_code,
    'cefr_level',v_target.cefr_level,'skill_code',v_target.skill_code,'sequence_number',v_target.sequence_number,
    'pre_pilot_review_status',v_target.pre_pilot_review_status,'boundary_reached',false
  );
END;
$$;

-- Defense in depth: the write RPC itself rejects out-of-scope reviewer/item pairs.
CREATE OR REPLACE FUNCTION assessment.submit_phase06_review_action(
  p_item_version_id uuid,
  p_action_code text,
  p_reviewer_id uuid,
  p_qa_gate text,
  p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $$
DECLARE
  v_action_id uuid;
  v_item jsonb;
  v_cefr_level text;
  v_skill_code text;
BEGIN
  IF p_reviewer_id IS NULL THEN
    RAISE EXCEPTION 'Reviewer identity is required' USING ERRCODE='23514';
  END IF;

  SELECT q.cefr_level,q.skill_code
  INTO v_cefr_level,v_skill_code
  FROM assessment.phase06_reviewer_queue_console q
  WHERE q.item_version_id=p_item_version_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item version % is not in ENG-GENERAL-P06 reviewer workspace',p_item_version_id USING ERRCODE='23503';
  END IF;
  IF NOT assessment.is_phase06_reviewer(p_reviewer_id,v_cefr_level,v_skill_code) THEN
    RAISE EXCEPTION 'REVIEW_SCOPE_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  v_action_id := assessment.record_item_review_action(p_item_version_id,p_action_code,p_reviewer_id,p_notes,p_qa_gate);
  SELECT assessment.get_phase06_review_item(p_item_version_id) INTO v_item;
  RETURN jsonb_build_object('action_id',v_action_id,'item',v_item);
END;
$$;

-- Service-role-only public wrappers for Edge Functions.
CREATE OR REPLACE FUNCTION public.phase06_is_reviewer_for_item(p_auth_user_id uuid,p_item_version_id uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.is_phase06_reviewer_for_item(p_auth_user_id,p_item_version_id); $$;

CREATE OR REPLACE FUNCTION public.phase06_get_review_queue_scoped(
  p_reviewer_id uuid,p_cefr_level text DEFAULT NULL,p_skill_code text DEFAULT NULL,p_status text DEFAULT NULL,p_release_code text DEFAULT NULL,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0
) RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.get_phase06_review_queue_scoped(p_reviewer_id,p_cefr_level,p_skill_code,p_status,p_release_code,p_limit,p_offset); $$;

CREATE OR REPLACE FUNCTION public.phase06_get_review_progress_scoped(p_reviewer_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.get_phase06_review_progress_scoped(p_reviewer_id); $$;

CREATE OR REPLACE FUNCTION public.phase06_get_review_neighbor_scoped(p_reviewer_id uuid,p_item_version_id uuid,p_direction text DEFAULT 'NEXT',p_status text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.get_phase06_review_neighbor_scoped(p_reviewer_id,p_item_version_id,p_direction,p_status); $$;

REVOKE ALL PRIVILEGES ON FUNCTION assessment.is_phase06_reviewer_for_item(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_queue_scoped(uuid,text,text,text,text,integer,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_progress_scoped(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION assessment.is_phase06_reviewer_for_item(uuid,uuid), assessment.get_phase06_review_queue_scoped(uuid,text,text,text,text,integer,integer), assessment.get_phase06_review_progress_scoped(uuid), assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_is_reviewer_for_item(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_get_review_queue_scoped(uuid,text,text,text,text,integer,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_get_review_progress_scoped(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_get_review_neighbor_scoped(uuid,uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.phase06_is_reviewer_for_item(uuid,uuid), public.phase06_get_review_queue_scoped(uuid,text,text,text,text,integer,integer), public.phase06_get_review_progress_scoped(uuid), public.phase06_get_review_neighbor_scoped(uuid,uuid,text,text) TO service_role;
-- END CANONICAL MIGRATION 0090

-- BEGIN CANONICAL MIGRATION 0091 20260903120043 p0_phase06_scoped_progress_performance_fix
CREATE OR REPLACE FUNCTION assessment.get_phase06_review_progress_scoped(
  p_reviewer_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE v_result jsonb;
BEGIN
  IF p_reviewer_id IS NULL OR NOT assessment.is_phase06_reviewer(p_reviewer_id,NULL,NULL) THEN
    RAISE EXCEPTION 'REVIEWER_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  WITH authorized_dims AS MATERIALIZED (
    SELECT p.*
    FROM assessment.phase06_review_progress_console p
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,p.cefr_level,p.skill_code)
  ), overall AS (
    SELECT
      coalesce(sum(total_items),0)::integer AS total_items,
      coalesce(sum(not_started),0)::integer AS not_started,
      coalesce(sum(in_review),0)::integer AS in_review,
      coalesce(sum(action_required),0)::integer AS action_required,
      coalesce(sum(rejected),0)::integer AS rejected,
      coalesce(sum(review_complete),0)::integer AS review_complete,
      coalesce(sum(primary_lo_human_confirmed),0)::integer AS lo_human_confirmed,
      coalesce(sum(approved_versions),0)::integer AS approved_versions
    FROM authorized_dims
  ), dims AS (
    SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY
      CASE p.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
      p.skill_code),'[]'::jsonb) AS rows
    FROM authorized_dims p
  )
  SELECT jsonb_build_object('overall',to_jsonb(o),'by_level_skill',d.rows)
  INTO v_result
  FROM overall o CROSS JOIN dims d;
  RETURN v_result;
END;
$$;

REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_progress_scoped(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION assessment.get_phase06_review_progress_scoped(uuid) TO service_role;
-- END CANONICAL MIGRATION 0091

-- BEGIN CANONICAL MIGRATION 0092 20260903120634 p0_phase06_scoped_neighbor_performance_fix
CREATE OR REPLACE FUNCTION assessment.get_phase06_review_neighbor_scoped(
  p_reviewer_id uuid,
  p_item_version_id uuid,
  p_direction text DEFAULT 'NEXT',
  p_status text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_dir text := upper(trim(coalesce(p_direction,'NEXT')));
  v_current record;
  v_target record;
BEGIN
  IF v_dir NOT IN ('NEXT','PREVIOUS') THEN
    RAISE EXCEPTION 'Direction must be NEXT or PREVIOUS' USING ERRCODE='23514';
  END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('NOT_STARTED','IN_REVIEW','ACTION_REQUIRED','REJECTED','COMPLETE_WITH_EDIT','COMPLETE') THEN
    RAISE EXCEPTION 'Unsupported review status %', p_status USING ERRCODE='23514';
  END IF;

  SELECT
    iv.id AS item_version_id,
    i.item_code,
    i.cefr_level,
    i.skill_code,
    i.sequence_number,
    CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END AS cefr_sort_order,
    CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END AS skill_sort_order
  INTO v_current
  FROM assessment.items i
  JOIN assessment.assessment_banks b ON b.id=i.bank_id AND b.bank_code='ENG-GENERAL-P06'
  JOIN assessment.item_versions iv ON iv.id=i.current_version_id AND iv.is_current
  WHERE iv.id=p_item_version_id
    AND assessment.is_phase06_reviewer(p_reviewer_id,i.cefr_level,i.skill_code);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REVIEW_SCOPE_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  SELECT
    iv.id AS item_version_id,
    i.item_code,
    i.cefr_level,
    i.skill_code,
    i.sequence_number,
    s.pre_pilot_review_status,
    CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END AS cefr_sort_order,
    CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END AS skill_sort_order
  INTO v_target
  FROM assessment.items i
  JOIN assessment.assessment_banks b ON b.id=i.bank_id AND b.bank_code='ENG-GENERAL-P06'
  JOIN assessment.item_versions iv ON iv.id=i.current_version_id AND iv.is_current
  JOIN assessment.item_pre_pilot_review_status s ON s.item_version_id=iv.id
  WHERE assessment.is_phase06_reviewer(p_reviewer_id,i.cefr_level,i.skill_code)
    AND (p_status IS NULL OR s.pre_pilot_review_status=p_status)
    AND (
      (v_dir='NEXT' AND (
        CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
        CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END,
        i.sequence_number,i.item_code
      ) > (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
      OR
      (v_dir='PREVIOUS' AND (
        CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
        CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END,
        i.sequence_number,i.item_code
      ) < (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
    )
  ORDER BY
    CASE WHEN v_dir='NEXT' THEN CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END END ASC,
    CASE WHEN v_dir='NEXT' THEN CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END END ASC,
    CASE WHEN v_dir='NEXT' THEN i.sequence_number END ASC,
    CASE WHEN v_dir='NEXT' THEN i.item_code END ASC,
    CASE WHEN v_dir='PREVIOUS' THEN CASE i.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN CASE i.skill_code WHEN 'LNG' THEN 1 WHEN 'RDG' THEN 2 ELSE 99 END END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN i.sequence_number END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN i.item_code END DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('direction',v_dir,'item_version_id',NULL,'item_code',NULL,'boundary_reached',true);
  END IF;

  RETURN jsonb_build_object(
    'direction',v_dir,
    'item_version_id',v_target.item_version_id,
    'item_code',v_target.item_code,
    'cefr_level',v_target.cefr_level,
    'skill_code',v_target.skill_code,
    'sequence_number',v_target.sequence_number,
    'pre_pilot_review_status',v_target.pre_pilot_review_status,
    'boundary_reached',false
  );
END;
$$;

REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) TO service_role;
-- END CANONICAL MIGRATION 0092

