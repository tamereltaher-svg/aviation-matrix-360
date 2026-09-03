create sequence if not exists public.am_quotation_number_seq start 1;

-- Extend request lifecycle
alter table public.am_requests drop constraint if exists am_requests_status_check;
alter table public.am_requests add constraint am_requests_status_check check (status in ('new','reviewing','contacted','quotation_pending','quotation_sent','approved','execution','completed','rejected','closed','cancelled'));

create table if not exists public.am_quotations (
  id uuid primary key default gen_random_uuid(),
  quotation_number text unique not null default ('AM-Q-' || to_char(current_date,'YYYY') || '-' || lpad(nextval('public.am_quotation_number_seq')::text,6,'0')),
  request_id uuid not null references public.am_requests(id) on delete cascade,
  version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','sent','accepted','rejected','expired','superseded','cancelled')),
  currency text not null default 'EGP',
  subtotal numeric(14,2) not null default 0,
  discount_amount numeric(14,2) not null default 0,
  tax_amount numeric(14,2) not null default 0,
  total_amount numeric(14,2) not null default 0,
  valid_until date,
  terms text,
  notes text,
  sent_at timestamptz,
  accepted_at timestamptz,
  rejected_at timestamptz,
  created_by uuid references public.staff_accounts(user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(request_id, version_no)
);

create table if not exists public.am_quotation_items (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.am_quotations(id) on delete cascade,
  item_type text not null check (item_type in ('program','addon','product','service','custom')),
  ref_id uuid,
  name text not null,
  description text,
  quantity numeric(14,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  discount_amount numeric(14,2) not null default 0,
  amount numeric(14,2) not null default 0,
  config jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.am_request_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.am_requests(id) on delete cascade,
  event_type text not null,
  from_status text,
  to_status text,
  title text not null,
  detail text,
  visibility text not null default 'internal' check (visibility in ('internal','customer')),
  actor_type text not null default 'system' check (actor_type in ('system','staff','customer')),
  actor_staff_id uuid references public.staff_accounts(user_id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.am_customer_notifications (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.am_requests(id) on delete cascade,
  quotation_id uuid references public.am_quotations(id) on delete cascade,
  channel text not null check (channel in ('email','whatsapp','sms','portal')),
  recipient text,
  template_code text not null,
  subject text,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','sent','failed','skipped')),
  sent_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists idx_am_quotations_request on public.am_quotations(request_id, created_at desc);
create index if not exists idx_am_quotations_status on public.am_quotations(status, created_at desc);
create index if not exists idx_am_request_events_request on public.am_request_events(request_id, created_at desc);
create index if not exists idx_am_notifications_request on public.am_customer_notifications(request_id, created_at desc);

alter table public.am_quotations enable row level security;
alter table public.am_quotation_items enable row level security;
alter table public.am_request_events enable row level security;
alter table public.am_customer_notifications enable row level security;

revoke all on public.am_quotations, public.am_quotation_items, public.am_request_events, public.am_customer_notifications from anon, authenticated;

-- Seed a customer-visible event for existing requests that do not yet have a timeline
insert into public.am_request_events(request_id,event_type,to_status,title,detail,visibility,actor_type)
select r.id,'request_received',r.status,'Request received','Your request has been received by Aviation Matrix.','customer','system'
from public.am_requests r
where not exists (select 1 from public.am_request_events e where e.request_id=r.id);

-- Keep quotation totals consistent.
create or replace function public.am_recalculate_quotation(p_quotation_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_sub numeric(14,2); v_discount numeric(14,2); v_tax numeric(14,2); begin
  select coalesce(sum(amount),0) into v_sub from public.am_quotation_items where quotation_id=p_quotation_id;
  select discount_amount, tax_amount into v_discount, v_tax from public.am_quotations where id=p_quotation_id;
  update public.am_quotations set subtotal=v_sub,total_amount=greatest(0,v_sub-coalesce(v_discount,0)+coalesce(v_tax,0)),updated_at=now() where id=p_quotation_id;
end $$;
revoke all on function public.am_recalculate_quotation(uuid) from public, anon, authenticated;
grant execute on function public.am_recalculate_quotation(uuid) to service_role;
