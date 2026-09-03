create table if not exists public.staff_login_guard (
  email text primary key,
  failed_count integer not null default 0,
  window_started_at timestamptz not null default now(),
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.staff_login_guard enable row level security;
revoke all on public.staff_login_guard from public, anon, authenticated;
