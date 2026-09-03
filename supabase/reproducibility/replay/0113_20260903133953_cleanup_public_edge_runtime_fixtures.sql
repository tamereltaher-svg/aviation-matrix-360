alter table public.am_registration_events disable trigger trg_registration_events_append_only;

do $$
declare aid uuid;
begin
  select id into aid from public.am_registration_applications where email='security-registration-20260903@example.invalid' order by created_at desc limit 1;
  if aid is not null then
    delete from public.am_registration_sessions where application_id=aid;
    delete from public.am_registration_activation_codes where application_id=aid;
    delete from public.am_registration_payment_refs where application_id=aid;
    delete from public.am_application_consents where application_id=aid;
    delete from public.am_application_documents where application_id=aid;
    delete from public.am_registration_events where application_id=aid;
    delete from public.am_registration_applications where id=aid;
  end if;
end $$;

alter table public.am_registration_events enable trigger trg_registration_events_append_only;

drop extension if exists http;
