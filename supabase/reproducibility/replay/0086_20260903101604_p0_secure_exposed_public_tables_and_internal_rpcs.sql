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
