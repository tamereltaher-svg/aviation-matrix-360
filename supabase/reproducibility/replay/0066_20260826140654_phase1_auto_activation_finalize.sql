create or replace function public.am_activate_registration_application(p_application_id uuid,p_actor uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare a am_registration_applications%rowtype; p_id uuid; c_id uuid;
begin
 select * into a from am_registration_applications where id=p_application_id for update;
 if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;
 if a.candidate_id is not null then return a.candidate_id; end if;
 if not a.activation_eligible then raise exception 'APPLICATION_NOT_ELIGIBLE'; end if;
 select id into p_id from am_persons p where (a.email is not null and lower(p.email)=lower(a.email)) or (a.mobile is not null and p.mobile=a.mobile) order by created_at asc limit 1;
 if p_id is null then
   insert into am_persons(full_name,date_of_birth,email,mobile,current_city,preferred_language,person_status)
   values(a.full_name,a.date_of_birth,a.email,a.mobile,a.current_city,a.preferred_language,'active') returning id into p_id;
 end if;
 select id into c_id from am_candidate_records where person_id=p_id order by created_at asc limit 1;
 if c_id is null then
   insert into am_candidate_records(person_id,lifecycle_stage,activation_status,activated_at,metadata)
   values(p_id,'candidate','active',now(),jsonb_build_object('application_id',a.id,'source',a.source_code,'institution_id',a.institution_id,'batch_id',a.batch_id)) returning id into c_id;
 end if;
 insert into am_candidate_current_state(candidate_id,person_id,lifecycle_stage,qualification_status,readiness_status)
 values(c_id,p_id,'candidate','unassessed','not_calculated')
 on conflict (candidate_id) do nothing;
 update am_registration_applications set person_id=p_id,candidate_id=c_id,lifecycle_status='candidate_active',activated_at=coalesce(activated_at,now()),updated_at=now() where id=a.id;
 insert into am_registration_events(application_id,event_code,title,detail,actor_type,actor_ref)
 values(a.id,'CANDIDATE_ACTIVATED','Candidate activated','Registration gate passed and lifetime candidate record created.','system',p_actor);
 perform am_append_candidate_lifetime_event(
   p_candidate_id=>c_id,
   p_event_code=>'CANDIDATE_ACTIVATED',
   p_event_domain=>'registration',
   p_title=>'Candidate activated',
   p_detail=>'Registration completed and candidate lifetime journey started.',
   p_payload=>jsonb_build_object('application_id',a.id,'application_number',a.application_number,'institution_id',a.institution_id,'batch_id',a.batch_id),
   p_source_system=>'registration-gateway',
   p_source_table=>'am_registration_applications',
   p_source_id=>a.id,
   p_recorded_by=>p_actor
 );
 return c_id;
end $$;

create or replace function public.am_recalculate_registration_gate(p_application_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a am_registration_applications%rowtype; missing_count int:=0; blocking_missing int:=0; consent_ok boolean:=false; payment_ok boolean:=false; code_ok boolean:=false; eligible boolean:=false; dq numeric:=0; activated_candidate uuid:=null;
begin
 select * into a from am_registration_applications where id=p_application_id for update;
 if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;
 select count(*) filter(where r.mandatory), count(*) filter(where r.mandatory and r.blocking)
 into missing_count,blocking_missing
 from am_registration_required_documents(p_application_id) r
 where not exists (
   select 1 from am_application_documents d
   where d.application_id=p_application_id and d.document_type_id=r.document_type_id and d.verification_status='verified'
 );
 select exists(select 1 from am_application_consents c where c.application_id=p_application_id and c.status='accepted') into consent_ok;
 payment_ok := (not a.payment_required) or a.payment_status in ('confirmed','not_required');
 select exists(select 1 from am_registration_activation_codes c where c.application_id=p_application_id and c.verified_at is not null and c.revoked_at is null) into code_ok;
 dq := ((case when nullif(trim(a.full_name),'') is not null then 20 else 0 end)
      +(case when nullif(trim(coalesce(a.email,'')),'') is not null then 15 else 0 end)
      +(case when nullif(trim(coalesce(a.mobile,'')),'') is not null then 15 else 0 end)
      +(case when a.date_of_birth is not null then 15 else 0 end)
      +(case when a.current_city is not null then 10 else 0 end)
      +(case when code_ok then 10 else 0 end)
      +(case when consent_ok then 15 else 0 end));
 eligible := code_ok and consent_ok and payment_ok and blocking_missing=0 and a.identity_verification_status in ('verified','unverified','pending');
 update am_registration_applications set activation_eligible=eligible,data_quality_score=dq,
 lifecycle_status=case when candidate_id is not null then 'candidate_active' when eligible then 'ready_for_activation' when code_ok then case when blocking_missing>0 then 'documents_pending' when not payment_ok then 'payment_pending' else 'registration_in_progress' end else lifecycle_status end,
 updated_at=now() where id=p_application_id;
 if eligible and a.candidate_id is null then
   activated_candidate:=am_activate_registration_application(p_application_id,null);
 end if;
 return jsonb_build_object('eligible',eligible,'missing_required',missing_count,'blocking_missing',blocking_missing,'consent_ok',consent_ok,'payment_ok',payment_ok,'code_ok',code_ok,'data_quality_score',dq,'candidate_id',activated_candidate);
end $$;
