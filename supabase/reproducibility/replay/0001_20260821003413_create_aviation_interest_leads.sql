create table if not exists public.aviation_interest_leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  mobile text not null,
  email text not null,
  date_of_birth date not null,
  education_stage text not null check (education_stage in ('school','secondary','university','graduate','other')),
  current_city text not null,
  aviation_interest text not null check (aviation_interest in ('cabin_crew','passenger_services','cargo','ground_operations','flight_ops','not_sure')),
  preferred_language text not null check (preferred_language in ('ar','en','ar_en')),
  consent boolean not null default false check (consent = true),
  source text not null default 'landing_pilot',
  status text not null default 'new' check (status in ('new','contacted','screening','qualified','closed')),
  created_at timestamptz not null default now()
);

alter table public.aviation_interest_leads enable row level security;

revoke all on table public.aviation_interest_leads from anon, authenticated;
grant insert on table public.aviation_interest_leads to anon, authenticated;

create policy "public_can_submit_aviation_interest"
on public.aviation_interest_leads
for insert
to anon, authenticated
with check (consent = true and source = 'landing_pilot');

create index if not exists aviation_interest_leads_created_at_idx
on public.aviation_interest_leads (created_at desc);

create index if not exists aviation_interest_leads_status_idx
on public.aviation_interest_leads (status);
