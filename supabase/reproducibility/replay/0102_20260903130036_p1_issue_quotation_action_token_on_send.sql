create or replace function public.am_issue_quotation_action_token_on_send()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  r public.am_requests%rowtype;
  v_token text;
  v_hash text;
  v_expires_at timestamptz;
begin
  if new.status = 'sent' and old.status is distinct from 'sent' then
    select * into r from public.am_requests where id = new.request_id;
    if not found then
      raise exception 'REQUEST_NOT_FOUND';
    end if;

    update public.am_quotation_action_tokens
       set revoked_at = now()
     where quotation_id = new.id
       and used_at is null
       and revoked_at is null;

    v_token := encode(extensions.gen_random_bytes(32), 'hex');
    v_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');
    v_expires_at := least(
      now() + interval '7 days',
      coalesce((new.valid_until + 1)::timestamptz, now() + interval '7 days')
    );

    if v_expires_at <= now() then
      v_expires_at := now() + interval '1 hour';
    end if;

    insert into public.am_quotation_action_tokens(
      request_id, quotation_id, token_hash, expires_at, created_by
    ) values (
      new.request_id, new.id, v_hash, v_expires_at, new.created_by
    );

    insert into public.am_customer_notifications(
      request_id, quotation_id, channel, recipient, template_code, subject, payload, status
    ) values (
      new.request_id,
      new.id,
      case when r.email is not null then 'email' else 'portal' end,
      coalesce(r.email,r.mobile),
      'quotation_action_authorization',
      'Secure quotation response link',
      jsonb_build_object(
        'quotation_number', new.quotation_number,
        'action_token', v_token,
        'action_token_expires_at', v_expires_at
      ),
      case when r.email is not null then 'pending' else 'sent' end
    );
  end if;
  return new;
end;
$$;

revoke all on function public.am_issue_quotation_action_token_on_send() from public, anon, authenticated;
grant execute on function public.am_issue_quotation_action_token_on_send() to service_role;

drop trigger if exists trg_am_issue_quotation_action_token_on_send on public.am_quotations;
create trigger trg_am_issue_quotation_action_token_on_send
after update of status on public.am_quotations
for each row execute function public.am_issue_quotation_action_token_on_send();
