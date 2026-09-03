create or replace function public.am_consume_application_resume_token(
  p_token_hash text,
  p_application_number text,
  p_new_token_hash text,
  p_new_expires_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $function$
declare
  v_old_id uuid;
  v_lead_id uuid;
  v_new_id uuid;
begin
  if p_token_hash is null or length(p_token_hash) < 32 or p_new_token_hash is null or length(p_new_token_hash) < 32 then
    raise exception 'INVALID_RESUME_TOKEN';
  end if;
  if p_new_expires_at <= clock_timestamp() or p_new_expires_at > clock_timestamp() + interval '31 days' then
    raise exception 'INVALID_RESUME_TOKEN_EXPIRY';
  end if;

  update public.am_application_resume_tokens t
     set consumed_at=clock_timestamp()
    from public.aviation_interest_leads l
   where t.token_hash=p_token_hash
     and t.lead_id=l.id
     and l.application_number=upper(trim(p_application_number))
     and t.consumed_at is null
     and t.expires_at > clock_timestamp()
  returning t.id,t.lead_id into v_old_id,v_lead_id;

  if v_old_id is null then
    return jsonb_build_object('ok',false);
  end if;

  insert into public.am_application_resume_tokens(lead_id,token_hash,expires_at,rotated_from_id)
  values(v_lead_id,p_new_token_hash,p_new_expires_at,v_old_id)
  returning id into v_new_id;

  return jsonb_build_object('ok',true,'lead_id',v_lead_id,'token_id',v_new_id);
end;
$function$;
revoke execute on function public.am_consume_application_resume_token(text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.am_consume_application_resume_token(text,text,text,timestamptz) to service_role;
