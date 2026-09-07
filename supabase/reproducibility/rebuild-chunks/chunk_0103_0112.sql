-- BEGIN CANONICAL MIGRATION 0103 20260903130158 runtime_enable_http_for_quotation_auth_test
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0103

-- BEGIN CANONICAL MIGRATION 0104 20260903130406 temporary_enable_http_for_final_phase06_runtime_gate
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0104

-- BEGIN CANONICAL MIGRATION 0105 20260903130506 disable_temporary_http_after_final_phase06_runtime_gate
drop extension if exists http;
-- END CANONICAL MIGRATION 0105

-- BEGIN CANONICAL MIGRATION 0106 20260903130538 runtime_reenable_http_for_quotation_auth_test
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0106

-- BEGIN CANONICAL MIGRATION 0107 20260903130630 runtime_disable_http_after_quotation_auth_test
drop extension if exists http;
-- END CANONICAL MIGRATION 0107

-- BEGIN CANONICAL MIGRATION 0108 20260903131010 p1_seed_commercial_domain_permissions
insert into public.staff_permissions (user_id, permission_code, is_allowed)
select sp.user_id, p.permission_code, true
from public.staff_permissions sp
cross join (values
  ('programs.manage'::text),
  ('quotations.manage'::text),
  ('institutions.manage'::text),
  ('meetings.manage'::text)
) as p(permission_code)
where sp.permission_code = 'store.manage'
  and sp.is_allowed = true
on conflict (user_id, permission_code)
do update set is_allowed = excluded.is_allowed;
-- END CANONICAL MIGRATION 0108

-- BEGIN CANONICAL MIGRATION 0109 20260903131351 temp_enable_http_for_commercial_auth_runtime
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0109

-- BEGIN CANONICAL MIGRATION 0110 20260903131605 temp_disable_http_after_commercial_auth_runtime
drop extension if exists http;
-- END CANONICAL MIGRATION 0110

-- BEGIN CANONICAL MIGRATION 0111 20260903133031 harden_public_service_role_rate_limits
create table if not exists public.am_public_api_rate_limits (
  scope_hash text not null,
  action_code text not null,
  window_started_at timestamptz not null,
  hit_count integer not null default 1 check (hit_count > 0),
  last_seen_at timestamptz not null default now(),
  primary key (scope_hash, action_code, window_started_at),
  check (length(scope_hash) between 16 and 128),
  check (length(action_code) between 1 and 100)
);

alter table public.am_public_api_rate_limits enable row level security;
revoke all on table public.am_public_api_rate_limits from public, anon, authenticated;
grant select, insert, update, delete on table public.am_public_api_rate_limits to service_role;

create index if not exists am_public_api_rate_limits_last_seen_idx
  on public.am_public_api_rate_limits(last_seen_at);

create or replace function public.am_check_public_api_rate_limit(
  p_scope_hash text,
  p_action text,
  p_window_seconds integer,
  p_max_requests integer
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_window timestamptz;
  v_count integer;
  v_retry integer;
begin
  if p_scope_hash is null or length(p_scope_hash) < 16 or length(p_scope_hash) > 128 then
    raise exception 'INVALID_RATE_SCOPE';
  end if;
  if p_action is null or length(p_action) < 1 or length(p_action) > 100 then
    raise exception 'INVALID_RATE_ACTION';
  end if;
  if p_window_seconds < 60 or p_window_seconds > 86400 then
    raise exception 'INVALID_RATE_WINDOW';
  end if;
  if p_max_requests < 1 or p_max_requests > 1000 then
    raise exception 'INVALID_RATE_MAX';
  end if;

  v_window := to_timestamp(floor(extract(epoch from v_now) / p_window_seconds) * p_window_seconds);

  insert into public.am_public_api_rate_limits(scope_hash, action_code, window_started_at, hit_count, last_seen_at)
  values (p_scope_hash, p_action, v_window, 1, v_now)
  on conflict (scope_hash, action_code, window_started_at)
  do update set hit_count = public.am_public_api_rate_limits.hit_count + 1,
                last_seen_at = excluded.last_seen_at
  returning hit_count into v_count;

  delete from public.am_public_api_rate_limits
   where scope_hash = p_scope_hash
     and window_started_at < v_now - interval '2 days';

  v_retry := greatest(1, ceil(extract(epoch from (v_window + make_interval(secs => p_window_seconds) - v_now)))::integer);

  return jsonb_build_object(
    'ok', v_count <= p_max_requests,
    'count', v_count,
    'limit', p_max_requests,
    'retry_after_seconds', v_retry,
    'window_started_at', v_window
  );
end;
$$;

revoke all on function public.am_check_public_api_rate_limit(text,text,integer,integer) from public, anon, authenticated;
grant execute on function public.am_check_public_api_rate_limit(text,text,integer,integer) to service_role;
-- END CANONICAL MIGRATION 0111

-- BEGIN CANONICAL MIGRATION 0112 20260903133410 temp_public_edge_runtime_http
create extension if not exists http with schema extensions;
-- END CANONICAL MIGRATION 0112

