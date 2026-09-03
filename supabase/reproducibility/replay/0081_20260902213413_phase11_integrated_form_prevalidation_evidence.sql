create table if not exists assessment.integrated_form_prevalidation_runs (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references assessment.exam_models(id),
  run_version text not null default 'P11-FORM-PREVALIDATION-v1.0',
  status text not null default 'RUNNING' check (status in ('RUNNING','PREVALIDATION_BLOCKED','REVIEW_REQUIRED','PREVALIDATION_PASS')),
  blocker_count integer not null default 0,
  major_count integer not null default 0,
  review_count integer not null default 0,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  notes text
);

create table if not exists assessment.integrated_form_prevalidation_findings (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references assessment.integrated_form_prevalidation_runs(id) on delete cascade,
  check_code text not null,
  severity text not null check (severity in ('BLOCKER','MAJOR','REVIEW','INFO')),
  cefr_level text,
  form_id uuid references assessment.forms(id),
  form_family text,
  skill_code text,
  dimension_code text not null,
  actual_value numeric,
  expected_value numeric,
  message text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ix_integrated_form_prevalidation_findings_run on assessment.integrated_form_prevalidation_findings(run_id,severity,check_code);
create index if not exists ix_integrated_form_prevalidation_findings_form on assessment.integrated_form_prevalidation_findings(form_id,skill_code);

alter table assessment.integrated_form_prevalidation_runs enable row level security;
alter table assessment.integrated_form_prevalidation_findings enable row level security;
revoke all on assessment.integrated_form_prevalidation_runs from public, anon, authenticated;
revoke all on assessment.integrated_form_prevalidation_findings from public, anon, authenticated;

create or replace function assessment.run_phase11_form_prevalidation()
returns uuid
language plpgsql
set search_path to ''
as $function$
declare
  v_model_id uuid;
  v_run_id uuid;
  v_blockers integer;
  v_majors integer;
  v_reviews integer;
begin
  select id into v_model_id from assessment.exam_models where model_code='ENG-GENERAL-INTEGRATED-v1.0' limit 1;
  if v_model_id is null then raise exception 'Integrated exam model not found' using errcode='23503'; end if;

  insert into assessment.integrated_form_prevalidation_runs(model_id,status,notes)
  values(v_model_id,'RUNNING','Automated structural and balance pre-validation only. Does not establish psychometric or operational equivalence.')
  returning id into v_run_id;

  -- Scoring profile integrity: hard prerequisite.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,dimension_code,actual_value,expected_value,message,details)
  select v_run_id,'P11FP001',case when bad=0 and total=36 then 'INFO' else 'BLOCKER' end,'FORM_PROFILE',
         total-bad,36,'Integrated form scoring profiles valid.',jsonb_build_object('forms_total',total,'invalid_profiles',bad)
  from (
    select count(*)::integer total,
           count(*) filter(where coalesce((assessment.phase10_validate_form_scoring_profile(p.form_version_id)->>'passes')::boolean,false)=false)::integer bad
    from assessment.exam_form_scoring_profiles p where p.model_id=v_model_id
  ) x;

  -- Exact section counts/raw maxima across six families per level.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with s as (
    select emf.cefr_level,fi.section_code skill_code,emf.form_family,
           count(*)::numeric item_count,sum(fi.max_raw_score_snapshot)::numeric raw_max
    from assessment.exam_model_forms emf
    join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id
    where emf.model_id=v_model_id
    group by 1,2,3
  ), g as (
    select cefr_level,skill_code,min(item_count) min_items,max(item_count) max_items,min(raw_max) min_raw,max(raw_max) max_raw
    from s group by 1,2
  )
  select v_run_id,'P11FP002',case when min_items=max_items and min_raw=max_raw then 'INFO' else 'BLOCKER' end,
         cefr_level,skill_code,'SECTION_PARITY',max_items-min_items,0,'Six-family section count/raw parity.',
         jsonb_build_object('min_items',min_items,'max_items',max_items,'min_raw',min_raw,'max_raw',max_raw)
  from g;

  -- P06 exact authoritative Primary-LO vector per form.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with req as (
    select lo.cefr_level,lo.skill_code,lcr.lo_id,lo.lo_code,lcr.required_per_form
    from assessment.lo_capacity_requirements lcr
    join assessment.learning_outcomes lo on lo.id=lcr.lo_id
    join assessment.assessment_banks b on b.id=lcr.bank_id and b.bank_code='ENG-GENERAL-P06'
    where lcr.source_status='AUTHORITATIVE_CONFIRMED' and lo.skill_code in ('RDG','LNG')
  ), forms as (
    select emf.cefr_level,emf.form_family,emf.form_id,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id
    where emf.model_id=v_model_id
  ), actual as (
    select fm.cefr_level,fm.form_id,fm.form_family,r.skill_code,r.lo_id,r.lo_code,r.required_per_form,
           count(fi.id)::integer actual_count
    from forms fm join req r on r.cefr_level=fm.cefr_level
    left join assessment.item_lo_mappings lm on lm.lo_id=r.lo_id and lm.mapping_role='PRIMARY'
    left join assessment.form_items fi on fi.form_version_id=fm.current_version_id and fi.item_version_id=lm.item_version_id and fi.section_code=r.skill_code
    group by 1,2,3,4,5,6,7
  )
  select v_run_id,'P11FP003','BLOCKER',cefr_level,form_id,form_family,skill_code,'PRIMARY_LO',actual_count,required_per_form,
         'P06 authoritative Primary-LO count does not match per-form requirement.',jsonb_build_object('lo_code',lo_code)
  from actual where actual_count<>required_per_form;

  -- Reading independent stimulus-family capacity across six forms.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with b as (select id from assessment.assessment_banks where bank_code='ENG-GENERAL-P06'),
  req as (
    select fbr.cefr_level,fbr.required_stimulus_families_per_form,ab.launch_form_equivalents
    from assessment.form_blueprint_requirements fbr join assessment.assessment_banks ab on ab.id=fbr.bank_id
    where fbr.bank_id=(select id from b) and fbr.skill_code='RDG'
  ), avail as (
    select i.cefr_level,count(distinct sv.stimulus_id)::integer available
    from assessment.items i join assessment.item_versions iv on iv.id=i.current_version_id
    join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
    where i.bank_id=(select id from b) and i.skill_code='RDG'
    group by i.cefr_level
  )
  select v_run_id,'P11FP004',case when a.available>=r.required_stimulus_families_per_form*r.launch_form_equivalents then 'INFO' else 'BLOCKER' end,
         r.cefr_level,'RDG','STIMULUS_FAMILY_CAPACITY',a.available,
         r.required_stimulus_families_per_form*r.launch_form_equivalents,
         'Independent Reading stimulus-family capacity for zero-overlap six-form partition.',
         jsonb_build_object('required_per_form',r.required_stimulus_families_per_form,'form_equivalents',r.launch_form_equivalents)
  from req r join avail a using(cefr_level);

  -- Current cross-form Reading stimulus overlap.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,skill_code,dimension_code,actual_value,expected_value,message,details)
  with x as (
    select emf.cefr_level,sv.stimulus_id,count(distinct emf.form_id)::integer form_count
    from assessment.exam_model_forms emf
    join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id and fi.section_code='RDG'
    join assessment.item_versions iv on iv.id=fi.item_version_id
    join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
    where emf.model_id=v_model_id
    group by 1,2 having count(distinct emf.form_id)>1
  )
  select v_run_id,'P11FP005','BLOCKER',cefr_level,'RDG','CROSS_FORM_STIMULUS_OVERLAP',count(*)::numeric,0,
         'Reading stimulus identities currently appear in more than one parallel form.',
         jsonb_build_object('max_forms_for_one_stimulus',max(form_count))
  from x group by cefr_level;

  -- P06 difficulty: existing frozen aggregate targets converted to per-form floor/ceiling; soft review only.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with b as (select id,launch_form_equivalents fe from assessment.assessment_banks where bank_code='ENG-GENERAL-P06'),
  forms as (
    select emf.cefr_level,emf.form_family,emf.form_id,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id where emf.model_id=v_model_id
  ), t as (
    select d.cefr_level,d.skill_code,d.difficulty_band,d.target_count,(select fe from b) fe
    from assessment.difficulty_distribution_targets d where d.bank_id=(select id from b) and d.skill_code in ('RDG','LNG')
  ), a as (
    select fm.cefr_level,fm.form_id,fm.form_family,t.skill_code,t.difficulty_band,t.target_count,t.fe,count(fi.id)::integer actual_count
    from forms fm join t on t.cefr_level=fm.cefr_level
    left join assessment.form_items fi on fi.form_version_id=fm.current_version_id and fi.section_code=t.skill_code
    left join assessment.item_versions iv on iv.id=fi.item_version_id and iv.author_difficulty=t.difficulty_band
    where fi.id is null or iv.id is not null
    group by 1,2,3,4,5,6,7
  )
  select v_run_id,'P11FP006','REVIEW',cefr_level,form_id,form_family,skill_code,'DIFFICULTY',actual_count,target_count::numeric/fe,
         'P06 difficulty count is outside derived per-form floor/ceiling; soft balance review.',
         jsonb_build_object('difficulty_band',difficulty_band,'derived_floor',floor(target_count::numeric/fe),'derived_ceiling',ceil(target_count::numeric/fe),'aggregate_target_count',target_count)
  from a where actual_count not between floor(target_count::numeric/fe) and ceil(target_count::numeric/fe);

  -- P06 frozen domain concentration thresholds, RDG/LNG only.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with x as (
    select emf.cefr_level,emf.form_id,emf.form_family,fi.section_code skill_code,iv.domain_code,count(*)::numeric n,
           count(*)::numeric/sum(count(*)) over(partition by emf.form_id,fi.section_code) share
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id
    join assessment.form_items fi on fi.form_version_id=f.current_version_id and fi.section_code in ('RDG','LNG')
    join assessment.item_versions iv on iv.id=fi.item_version_id
    where emf.model_id=v_model_id
    group by 1,2,3,4,5
  )
  select v_run_id,'P11FP007',case when share>0.35 then 'MAJOR' else 'REVIEW' end,cefr_level,form_id,form_family,skill_code,'DOMAIN_CONCENTRATION',share,0.25,
         'P06 RDG/LNG domain concentration exceeds frozen review threshold.',
         jsonb_build_object('domain_code',domain_code,'review_share',0.25,'major_share',0.35,'count',n)
  from x where share>0.25;

  -- Reading unique-stimulus word-load tolerance +/-10%; soft review only.
  insert into assessment.integrated_form_prevalidation_findings(run_id,check_code,severity,cefr_level,form_id,form_family,skill_code,dimension_code,actual_value,expected_value,message,details)
  with forms as (
    select emf.cefr_level,emf.form_id,emf.form_family,f.current_version_id
    from assessment.exam_model_forms emf join assessment.forms f on f.id=emf.form_id where emf.model_id=v_model_id
  ), load as (
    select fm.cefr_level,fm.form_id,fm.form_family,coalesce(sum(x.word_count),0)::numeric word_load
    from forms fm left join lateral (
      select distinct sv.id,sv.word_count
      from assessment.form_items fi join assessment.item_versions iv on iv.id=fi.item_version_id
      join assessment.stimulus_versions sv on sv.id=iv.stimulus_version_id
      where fi.form_version_id=fm.current_version_id and fi.section_code='RDG'
    ) x on true group by 1,2,3
  ), stats as (select cefr_level,avg(word_load)::numeric mean_load from load group by cefr_level)
  select v_run_id,'P11FP008','REVIEW',l.cefr_level,l.form_id,l.form_family,'RDG','READING_WORD_LOAD',l.word_load,s.mean_load,
         'Reading unique-stimulus word load is outside +/-10% of level mean.',
         jsonb_build_object('relative_deviation',(l.word_load-s.mean_load)/nullif(s.mean_load,0),'tolerance_pct',0.10)
  from load l join stats s using(cefr_level)
  where s.mean_load<>0 and abs((l.word_load-s.mean_load)/s.mean_load)>0.10;

  select count(*) filter(where severity='BLOCKER'),count(*) filter(where severity='MAJOR'),count(*) filter(where severity='REVIEW')
    into v_blockers,v_majors,v_reviews
  from assessment.integrated_form_prevalidation_findings where run_id=v_run_id;

  update assessment.integrated_form_prevalidation_runs
  set blocker_count=v_blockers,major_count=v_majors,review_count=v_reviews,
      status=case when v_blockers>0 then 'PREVALIDATION_BLOCKED' when v_majors>0 or v_reviews>0 then 'REVIEW_REQUIRED' else 'PREVALIDATION_PASS' end,
      finished_at=now()
  where id=v_run_id;

  return v_run_id;
end
$function$;

revoke execute on function assessment.run_phase11_form_prevalidation() from public, anon, authenticated;
