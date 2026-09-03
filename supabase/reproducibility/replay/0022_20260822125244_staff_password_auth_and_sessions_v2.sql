create extension if not exists pgcrypto with schema extensions;

alter table public.staff_accounts
  add column if not exists password_hash text,
  add column if not exists password_updated_at timestamptz;

create table if not exists public.staff_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.staff_accounts(user_id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  user_agent text,
  ip_hint text
);

alter table public.staff_sessions enable row level security;
revoke all on public.staff_sessions from public, anon, authenticated;

create or replace function public.staff_verify_password(p_email text, p_password text)
returns table(user_id uuid, email text, full_name text, role_code text, is_active boolean)
language sql
security definer
set search_path = public, extensions, pg_temp
as $$
  select s.user_id, s.email, s.full_name, s.role_code, s.is_active
  from public.staff_accounts s
  where lower(s.email)=lower(trim(p_email))
    and s.is_active=true
    and s.password_hash is not null
    and s.password_hash = extensions.crypt(p_password, s.password_hash)
  limit 1;
$$;

revoke all on function public.staff_verify_password(text,text) from public, anon, authenticated;
grant execute on function public.staff_verify_password(text,text) to service_role;

create or replace function public.staff_has_permission(p_user_id uuid, p_permission text)
returns boolean
language sql
security definer
set search_path = public, pg_temp
as $$
  select exists(
    select 1 from public.staff_permissions sp
    join public.staff_accounts sa on sa.user_id=sp.user_id
    where sp.user_id=p_user_id
      and sp.permission_code=p_permission
      and sp.is_allowed=true
      and sa.is_active=true
  );
$$;

revoke all on function public.staff_has_permission(uuid,text) from public, anon, authenticated;
grant execute on function public.staff_has_permission(uuid,text) to service_role;
