create or replace function public.guard_public_lead_duplicates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists(
    select 1
    from public.aviation_interest_leads l
    where lower(trim(l.email)) = lower(trim(new.email))
  ) then
    raise exception 'EMAIL_ALREADY_REGISTERED';
  end if;

  if exists(
    select 1
    from public.aviation_interest_leads l
    where public.normalize_public_mobile(l.mobile) = public.normalize_public_mobile(new.mobile)
  ) then
    raise exception 'MOBILE_ALREADY_REGISTERED';
  end if;

  return new;
end;
$$;
