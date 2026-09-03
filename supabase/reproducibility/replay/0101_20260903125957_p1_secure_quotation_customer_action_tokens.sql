create table if not exists public.am_quotation_action_tokens (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.am_requests(id) on delete cascade,
  quotation_id uuid not null references public.am_quotations(id) on delete cascade,
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_action text check (used_action is null or used_action in ('accept_quotation','reject_quotation')),
  revoked_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  check (used_at is not null or used_action is null)
);

create index if not exists am_quotation_action_tokens_lookup_idx
  on public.am_quotation_action_tokens(token_hash, request_id, quotation_id);
create index if not exists am_quotation_action_tokens_active_idx
  on public.am_quotation_action_tokens(quotation_id, expires_at)
  where used_at is null and revoked_at is null;

alter table public.am_quotation_action_tokens enable row level security;
revoke all on table public.am_quotation_action_tokens from public, anon, authenticated;
grant select, insert, update, delete on table public.am_quotation_action_tokens to service_role;

create or replace function public.am_apply_customer_quotation_action(
  p_token_hash text,
  p_request_id uuid,
  p_quotation_id uuid,
  p_action text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  t public.am_quotation_action_tokens%rowtype;
  q public.am_quotations%rowtype;
  r public.am_requests%rowtype;
  v_now timestamptz := now();
  v_to_status text;
  v_event_type text;
  v_title text;
  v_detail text;
begin
  if p_action not in ('accept_quotation','reject_quotation') then
    return jsonb_build_object('ok', false, 'error', 'INVALID_ACTION');
  end if;

  select * into t
  from public.am_quotation_action_tokens
  where token_hash = lower(p_token_hash)
    and request_id = p_request_id
    and quotation_id = p_quotation_id
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'INVALID_ACTION_TOKEN');
  end if;
  if t.revoked_at is not null then
    return jsonb_build_object('ok', false, 'error', 'ACTION_TOKEN_REVOKED');
  end if;
  if t.used_at is not null then
    return jsonb_build_object('ok', false, 'error', 'ACTION_TOKEN_USED');
  end if;
  if t.expires_at <= v_now then
    return jsonb_build_object('ok', false, 'error', 'ACTION_TOKEN_EXPIRED');
  end if;

  select * into q
  from public.am_quotations
  where id = p_quotation_id and request_id = p_request_id
  for update;

  if not found or q.status <> 'sent' then
    return jsonb_build_object('ok', false, 'error', 'QUOTATION_NOT_AVAILABLE');
  end if;
  if q.valid_until is not null and q.valid_until < current_date then
    return jsonb_build_object('ok', false, 'error', 'QUOTATION_EXPIRED');
  end if;

  select * into r from public.am_requests where id = p_request_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'REQUEST_NOT_FOUND');
  end if;

  update public.am_quotation_action_tokens
     set used_at = v_now, used_action = p_action
   where id = t.id;

  if p_action = 'accept_quotation' then
    update public.am_quotations
       set status='accepted', accepted_at=v_now, rejected_at=null, updated_at=v_now
     where id=q.id;
    update public.am_requests set status='approved', updated_at=v_now where id=r.id;
    v_to_status := 'approved';
    v_event_type := 'quotation_accepted';
    v_title := 'Quotation accepted';
    v_detail := format('Quotation %s was accepted by the customer.', q.quotation_number);

    insert into public.am_customer_notifications(
      request_id, quotation_id, channel, recipient, template_code, subject, payload, status, sent_at
    ) values (
      r.id, q.id, 'portal', coalesce(r.email,r.mobile), 'quotation_accepted', 'Quotation accepted',
      jsonb_build_object('quotation_number',q.quotation_number), 'sent', v_now
    );
  else
    update public.am_quotations
       set status='rejected', rejected_at=v_now, accepted_at=null, updated_at=v_now
     where id=q.id;
    update public.am_requests set status='reviewing', updated_at=v_now where id=r.id;
    v_to_status := 'reviewing';
    v_event_type := 'quotation_rejected';
    v_title := 'Quotation needs revision';
    v_detail := format('Quotation %s was not accepted. Aviation Matrix will review the request.', q.quotation_number);
  end if;

  insert into public.am_request_events(
    request_id,event_type,from_status,to_status,title,detail,visibility,actor_type
  ) values (
    r.id,v_event_type,r.status,v_to_status,v_title,v_detail,'customer','customer'
  );

  return jsonb_build_object(
    'ok', true,
    'action', p_action,
    'request_id', r.id,
    'quotation_id', q.id,
    'request_status', v_to_status,
    'quotation_status', case when p_action='accept_quotation' then 'accepted' else 'rejected' end
  );
end;
$$;

revoke all on function public.am_apply_customer_quotation_action(text,uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.am_apply_customer_quotation_action(text,uuid,uuid,text) to service_role;
