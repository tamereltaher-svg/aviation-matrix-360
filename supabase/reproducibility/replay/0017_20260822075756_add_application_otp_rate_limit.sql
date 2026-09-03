create table if not exists public.application_otp_requests(
  application_number text primary key,
  last_sent_at timestamptz not null default now(),
  send_count integer not null default 1
);
alter table public.application_otp_requests enable row level security;
revoke all on public.application_otp_requests from anon, authenticated;
