create table if not exists public.staff_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  employee_code text unique,
  full_name text,
  email text not null unique,
  department text,
  job_title text,
  role_code text not null default 'staff',
  is_active boolean not null default true,
  must_change_password boolean not null default false,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff_permissions (
  user_id uuid not null references public.staff_accounts(user_id) on delete cascade,
  permission_code text not null,
  is_allowed boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, permission_code)
);

alter table public.staff_accounts enable row level security;
alter table public.staff_permissions enable row level security;

create or replace function public.is_active_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.staff_accounts s
    where s.user_id = auth.uid()
      and s.is_active = true
  );
$$;

create or replace function public.has_staff_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.staff_permissions p
    join public.staff_accounts s on s.user_id = p.user_id
    where p.user_id = auth.uid()
      and s.is_active = true
      and p.permission_code = p_permission
      and p.is_allowed = true
  );
$$;

revoke all on function public.is_active_staff() from public;
revoke all on function public.has_staff_permission(text) from public;
grant execute on function public.is_active_staff() to authenticated;
grant execute on function public.has_staff_permission(text) to authenticated;

create policy staff_can_read_self
on public.staff_accounts
for select
to authenticated
using (user_id = auth.uid());

create policy staff_permissions_read_self
on public.staff_permissions
for select
to authenticated
using (user_id = auth.uid());

-- Sanitized: production staff-account identity seed omitted.

-- Sanitized: production staff-permission identity seed omitted.
