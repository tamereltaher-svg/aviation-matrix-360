create or replace function assessment.run_phase11_integrated_gate()
returns uuid
language plpgsql
set search_path=''
as $function$
declare
  v_run uuid;
  v_bank uuid;
  v_model uuid;
  v_count integer;
  v_bad integer;
  v_total integer;
  v_obj integer;
  v_analytic integer;
  v_foundation_status text;
  v_rec record;
begin
  select id into v_bank from assessment.assessment_banks where bank_code='ENG-GENERAL-P06';
  select id into v_model from assessment.exam_models where model_code='ENG-GENERAL-INTEGRATED-v1.0';
  if v_bank is null or v_model is null then raise exception 'Integrated model/control bank missing' using errcode='23503'; end if;

  insert into assessment.deployment_gate_runs(gate_scope,bank_id,status,report_version,notes)
  values('PHASE11_INTEGRATED',v_bank,'RUNNING','P11-INTEGRATED-v1.0','Integrated QA / Validation / Security readiness gate; NO_GO is expected until human review, media, equivalence, standard setting and pilot evidence are complete.')
  returning id into v_run;

  select status into v_foundation_status from assessment.deployment_gate_runs
  where gate_scope='FOUNDATION_DEPLOYMENT' and finished_at is not null order by finished_at desc limit 1;
  perform assessment.add_deployment_gate_result(v_run,'P11I001',coalesce(v_foundation_status,'')='GO',coalesce(v_foundation_status,'NONE'),'GO','Foundation security gate status.');

  v_bad:=0; v_count:=0;
  for v_rec in select p.form_version_id from assessment.exam_form_scoring_profiles p where p.model_id=v_model loop
    v_count:=v_count+1;
    begin perform assessment.phase10_validate_form_scoring_profile(v_rec.form_version_id); exception when others then v_bad:=v_bad+1; end;
  end loop;
  perform assessment.add_deployment_gate_result(v_run,'P11I002',v_count=36 and v_bad=0,format('profiles=%s; invalid=%s',v_count,v_bad),'profiles=36; invalid=0','Integrated form scoring-profile validation.');

  select count(*),count(distinct fi.item_version_id),
         count(*) filter(where fi.scoring_mode_snapshot='OPTION_KEY'),
         count(*) filter(where fi.scoring_mode_snapshot='ANALYTIC_RUBRIC')
    into v_total,v_count,v_obj,v_analytic
  from assessment.form_items fi
  join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id
  join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model;
  perform assessment.add_deployment_gate_result(v_run,'P11I003',v_total=2382 and v_count=2382 and v_obj=2202 and v_analytic=180,
    format('rows=%s; distinct=%s; objective=%s; analytic=%s',v_total,v_count,v_obj,v_analytic),'rows=2382; distinct=2382; objective=2202; analytic=180','Integrated item snapshot reconciliation.');

  select count(*) into v_bad
  from assessment.form_items fi
  join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id
  join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id
  join assessment.items i on i.id=iv.item_id
  where i.security_level<>'SEC-1' or i.exposure_status<>'UNUSED' or i.compromise_status or i.lifecycle_status<>'DRAFT_QA';
  perform assessment.add_deployment_gate_result(v_run,'P11I004',v_bad=0,v_bad::text,'0','Integrated items outside controlled draft security state.');

  select count(*) into v_bad
  from assessment.lo_capacity_requirements lcr
  join assessment.assessment_banks b on b.id=lcr.bank_id
  where lcr.bank_id=v_bank and (
    select count(distinct i.id)
    from assessment.items i
    join assessment.item_versions iv on iv.id=i.current_version_id
    join assessment.item_lo_mappings m on m.item_version_id=iv.id and m.lo_id=lcr.lo_id and m.mapping_role='PRIMARY' and m.mapping_status<>'REJECTED'
    where i.bank_id=lcr.bank_id and i.lifecycle_status not in ('RETIRED','COMPROMISED') and not i.compromise_status
  ) < lcr.required_per_form*b.launch_form_equivalents;
  perform assessment.add_deployment_gate_result(v_run,'P11I005',v_bad=0,v_bad::text,'0','P06 authoritative Primary-LO capacity deficits.');

  select count(*) into v_total from assessment.listening_stimulus_audio;
  select count(*) into v_count from assessment.listening_stimulus_audio
    where audio_status='READY' and storage_bucket is not null and storage_object_path is not null and duration_seconds is not null and duration_seconds>0;
  perform assessment.add_deployment_gate_result(v_run,'P11I006',v_total=374 and v_count=374,format('ready=%s; total=%s',v_count,v_total),'ready=374; total=374','P07 listening audio production readiness.');

  select count(distinct fi.item_version_id) into v_total
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model;
  select count(distinct iv.id) into v_count
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id
  where iv.review_status in ('PASS','PASS_WITH_EDIT') and iv.approval_status='APPROVED';
  perform assessment.add_deployment_gate_result(v_run,'P11I007',v_total=2382 and v_count=2382,format('approved_reviewed=%s; total=%s',v_count,v_total),'approved_reviewed=2382; total=2382','Integrated human-review and approval completion.');

  select count(distinct iv.id) into v_bad
  from assessment.form_items fi join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
  join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
  join assessment.item_versions iv on iv.id=fi.item_version_id where iv.domain_code is null or iv.construct_code is null;
  perform assessment.add_deployment_gate_result(v_run,'P11I008',v_bad=0,v_bad::text,'0','Integrated items missing domain and/or construct metadata.');

  select count(*) into v_count from assessment.exam_model_forms where model_id=v_model
    and equivalence_status not in ('NOT_YET_VALIDATED','PENDING','PENDING_HUMAN_REVIEW');
  perform assessment.add_deployment_gate_result(v_run,'P11I009',v_count=36,v_count::text,'36','Forms with validated equivalence status.');

  select count(*) into v_count from assessment.exam_cut_score_policies where model_id=v_model
    and overall_cut_score is not null and policy_status<>'PENDING_STANDARD_SETTING';
  perform assessment.add_deployment_gate_result(v_run,'P11I010',v_count=6,v_count::text,'6','CEFR levels with completed standard setting and cut score.');

  select count(distinct cefr_level) into v_count from assessment.pilot_cohorts where cohort_status='CLOSED' and usable_response_count>0;
  perform assessment.add_deployment_gate_result(v_run,'P11I011',v_count=6,v_count::text,'6','CEFR levels with closed usable pilot cohorts.');

  with objective_items as (
    select distinct fi.item_version_id from assessment.form_items fi
    join assessment.form_versions fv on fv.id=fi.form_version_id and fv.is_current
    join assessment.forms f on f.id=fv.form_id join assessment.exam_model_forms emf on emf.form_id=f.id and emf.model_id=v_model
    where fi.scoring_mode_snapshot='OPTION_KEY'
  ), acceptable as (
    select distinct ps.item_version_id from assessment.psychometric_stats ps join objective_items oi on oi.item_version_id=ps.item_version_id
    where ps.psychometric_decision in ('KEEP','KEEP_MONITOR')
  ) select (select count(*) from objective_items),(select count(*) from acceptable) into v_total,v_count;
  perform assessment.add_deployment_gate_result(v_run,'P11I012',v_total=2202 and v_count=2202,format('acceptable=%s; objective=%s',v_count,v_total),'acceptable=2202; objective=2202','Objective item psychometric coverage.');

  select count(*) into v_count from assessment.writing_scoring_policy wsp join assessment.assessment_banks b on b.id=wsp.bank_id
    where b.bank_code='ENG-GENERAL-P08' and wsp.external_certification_status='NOT_CLAIMED';
  select count(*) into v_total from assessment.speaking_scoring_policy ssp join assessment.assessment_banks b on b.id=ssp.bank_id
    where b.bank_code='ENG-GENERAL-P09' and ssp.external_certification_status='NOT_CLAIMED';
  select count(*) into v_bad from assessment.writing_rater_policy wrp join assessment.assessment_banks b on b.id=wrp.bank_id where b.bank_code='ENG-GENERAL-P08' and wrp.is_active;
  select count(*) into v_obj from assessment.speaking_rater_policy srp join assessment.assessment_banks b on b.id=srp.bank_id where b.bank_code='ENG-GENERAL-P09' and srp.is_active;
  perform assessment.add_deployment_gate_result(v_run,'P11I013',v_count>=1 and v_total>=1 and v_bad>=1 and v_obj>=1,
    format('writing_policy=%s; speaking_policy=%s; writing_rater_rules=%s; speaking_rater_rules=%s',v_count,v_total,v_bad,v_obj),'all present','Writing/Speaking human-scoring governance presence.');

  select count(*) into v_count from assessment.exam_models where id=v_model and external_certification_status='NOT_CLAIMED' and source_status='AVIATION_MATRIX_INTERNAL_OPERATIONAL_BASELINE';
  perform assessment.add_deployment_gate_result(v_run,'P11I014',v_count=1,v_count::text,'1','Integrated model internal-governance / no external-certification claim.');

  perform assessment.finish_deployment_gate_run(v_run);
  return v_run;
exception when others then
  if v_run is not null then update assessment.deployment_gate_runs set status='ERROR',finished_at=now(),notes=coalesce(notes,'')||' ERROR: '||sqlerrm where id=v_run; end if;
  raise;
end $function$;

revoke all privileges on function assessment.run_phase11_integrated_gate() from public, anon, authenticated;
