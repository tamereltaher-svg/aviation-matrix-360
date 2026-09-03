create table if not exists public.assessment_scoring_models (
  id uuid primary key default gen_random_uuid(),
  assessment_version_id uuid not null references public.assessment_versions(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  model_code text not null,
  model_name text not null,
  methodology_notes text not null,
  current_fit_formula text not null,
  future_fit_formula text not null,
  status text not null default 'draft' check (status in ('draft','review','published','retired')),
  created_at timestamptz not null default now(),
  unique (assessment_version_id, career_track_id, model_code)
);

create table if not exists public.assessment_dimension_results (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.assessment_attempts(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  dimension_id uuid not null references public.assessment_dimensions(id) on delete cascade,
  raw_score numeric not null check (raw_score between 0 and 100),
  weighted_contribution numeric not null default 0,
  weight_used numeric not null check (weight_used between 0 and 1),
  minimum_score numeric null,
  meets_minimum boolean null,
  evidence_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (attempt_id, career_track_id, dimension_id)
);

create table if not exists public.assessment_explanation_rules (
  id uuid primary key default gen_random_uuid(),
  assessment_version_id uuid not null references public.assessment_versions(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  rule_type text not null check (rule_type in ('strength','gap','status','future_fit','minimum_gate')),
  dimension_id uuid null references public.assessment_dimensions(id) on delete cascade,
  min_score numeric null,
  max_score numeric null,
  explanation_template text not null,
  development_action text null,
  priority integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.assessment_scoring_models enable row level security;
alter table public.assessment_dimension_results enable row level security;
alter table public.assessment_explanation_rules enable row level security;

insert into public.assessment_scoring_models (
  assessment_version_id, career_track_id, model_code, model_name,
  methodology_notes, current_fit_formula, future_fit_formula, status
)
select v.id,c.id,'weighted_dimension_fit_v1','Weighted Dimension Fit v1',
'AVIATION MATRIX DRAFT METHODOLOGY. Current Fit is a weighted combination of observed dimension scores. Weights are internal methodology informed by role relevance and reference-backed competencies; the percentages are not prescribed by ICAO. Future Fit is a transparent development-potential estimate and must not be presented as guaranteed future performance.',
'Current Fit = sum(observed dimension score × career dimension weight), normalized over answered dimensions.',
'Future Fit = Current Fit + remaining gap × (0.15 + 0.25 × Learning Agility/100), capped at 95. This is a draft development-potential estimate, not a regulatory or airline standard.',
'draft'
from public.assessment_versions v
join public.assessment_frameworks f on f.id=v.framework_id and f.code='career_fit'
join public.career_tracks c on c.code='cabin_crew'
where v.version_no=1
on conflict (assessment_version_id, career_track_id, model_code) do nothing;

insert into public.preparatory_paths(code,name,description)
values
('prep_aviation_english','Aviation English Foundation','Development path for aviation English comprehension, terminology and communication readiness.'),
('prep_safety_judgment','Safety & Professional Judgment Foundation','Development path for safety-first thinking, procedural judgment, escalation and prioritization.'),
('prep_crm_communication','CRM & Communication Foundation','Development path for teamwork, clear communication, coordination and passenger interaction.'),
('prep_attention_procedures','Attention & Procedures Foundation','Development path for detail orientation, checking discipline and procedural accuracy.'),
('prep_professional_readiness','Professional Readiness Foundation','Development path for professional presence, service conduct, resilience and learning habits.')
on conflict (code) do nothing;

insert into public.career_preparatory_rules(career_track_id,dimension_id,threshold_below,preparatory_path_id,rationale,is_active)
select c.id,d.id,x.threshold,p.id,x.rationale,true
from public.career_tracks c
join (values
 ('english_readiness',65::numeric,'prep_aviation_english','Below this draft threshold, targeted aviation-English preparation is recommended before full career readiness.'),
 ('safety_mindset',70::numeric,'prep_safety_judgment','Safety mindset is a high-priority cabin-crew dimension; a low score triggers targeted preparation rather than silent rejection.'),
 ('professional_judgment',60::numeric,'prep_safety_judgment','Judgment below the draft threshold indicates a need for scenario-based decision development.'),
 ('teamwork_crm',60::numeric,'prep_crm_communication','CRM/teamwork below the draft threshold indicates targeted coordination and communication development.'),
 ('communication',60::numeric,'prep_crm_communication','Communication below the draft threshold indicates targeted communication development.'),
 ('attention_to_detail',60::numeric,'prep_attention_procedures','Attention below the draft threshold indicates targeted procedural and checking practice.'),
 ('professional_presence',55::numeric,'prep_professional_readiness','Professional presence is developable and should lead to coaching, not rejection.'),
 ('learning_agility',55::numeric,'prep_professional_readiness','Low learning-agility evidence indicates the need for structured learning support.')
) as x(dim_code,threshold,path_code,rationale) on true
join public.assessment_dimensions d on d.code=x.dim_code
join public.preparatory_paths p on p.code=x.path_code
where c.code='cabin_crew'
and not exists (
 select 1 from public.career_preparatory_rules r
 where r.career_track_id=c.id and r.dimension_id=d.id and r.preparatory_path_id=p.id
);

create or replace function public.calculate_assessment_career_fit(p_attempt_id uuid, p_career_code text default 'cabin_crew')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt public.assessment_attempts%rowtype;
  v_career_id uuid;
  v_learning numeric := 50;
  v_current numeric := 0;
  v_future numeric := 0;
  v_weight_sum numeric := 0;
  v_status text;
  v_summary text;
  v_strengths jsonb := '[]'::jsonb;
  v_gaps jsonb := '[]'::jsonb;
  v_dimensions jsonb := '{}'::jsonb;
  v_failed_minimums integer := 0;
begin
  select * into v_attempt from public.assessment_attempts where id=p_attempt_id;
  if not found then raise exception 'Assessment attempt not found'; end if;

  select id into v_career_id from public.career_tracks where code=p_career_code and is_active=true;
  if v_career_id is null then raise exception 'Career track not found'; end if;

  delete from public.assessment_dimension_results where attempt_id=p_attempt_id and career_track_id=v_career_id;

  insert into public.assessment_dimension_results(
    attempt_id,career_track_id,dimension_id,raw_score,weighted_contribution,weight_used,minimum_score,meets_minimum,evidence_payload
  )
  select
    p_attempt_id,
    v_career_id,
    w.dimension_id,
    round(avg(qds.score),2) as raw_score,
    round(avg(qds.score) * w.weight,4) as weighted_contribution,
    w.weight,
    w.minimum_score,
    case when w.minimum_score is null then null else avg(qds.score) >= w.minimum_score end,
    jsonb_build_object(
      'answered_items',count(distinct a.question_id),
      'scoring_basis','Mean option evidence score for this dimension',
      'weight_rationale',w.rationale
    )
  from public.assessment_answers a
  join public.question_dimension_scores qds on qds.option_id=a.option_id
  join public.career_dimension_weights w on w.dimension_id=qds.dimension_id
    and w.assessment_version_id=v_attempt.assessment_version_id
    and w.career_track_id=v_career_id
  where a.attempt_id=p_attempt_id
  group by w.dimension_id,w.weight,w.minimum_score,w.rationale;

  select coalesce(sum(weight_used),0),
         coalesce(sum(weighted_contribution),0)
    into v_weight_sum,v_current
  from public.assessment_dimension_results
  where attempt_id=p_attempt_id and career_track_id=v_career_id;

  if v_weight_sum > 0 then
    v_current := round(v_current / v_weight_sum,2);
  else
    raise exception 'No scorable answers found for this attempt';
  end if;

  select coalesce(raw_score,50) into v_learning
  from public.assessment_dimension_results dr
  join public.assessment_dimensions d on d.id=dr.dimension_id
  where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id and d.code='learning_agility';

  v_future := round(least(95, v_current + (100-v_current) * (0.15 + 0.25*(v_learning/100))),2);

  select count(*) into v_failed_minimums
  from public.assessment_dimension_results
  where attempt_id=p_attempt_id and career_track_id=v_career_id and meets_minimum=false;

  if v_current >= 80 and v_failed_minimums=0 then v_status:='ready_now';
  elsif v_current >= 65 and v_failed_minimums<=1 then v_status:='ready_with_development';
  elsif v_current >= 45 then v_status:='development_required';
  else v_status:='future_eligible';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('code',code,'name',name,'score',raw_score,'weight',weight_used,'meets_minimum',meets_minimum) order by raw_score desc),'[]'::jsonb)
    into v_strengths
  from (
    select d.code,d.name,dr.raw_score,dr.weight_used,dr.meets_minimum
    from public.assessment_dimension_results dr join public.assessment_dimensions d on d.id=dr.dimension_id
    where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id
    order by dr.raw_score desc limit 3
  ) s;

  select coalesce(jsonb_agg(jsonb_build_object('code',code,'name',name,'score',raw_score,'target',target_score,'reason',reason,'recommended_path',path_name) order by raw_score asc),'[]'::jsonb)
    into v_gaps
  from (
    select d.code,d.name,dr.raw_score,
           coalesce(w.minimum_score,r.threshold_below,65) as target_score,
           case when dr.meets_minimum=false then 'Below the career draft minimum' else 'One of the lower observed dimensions' end as reason,
           p.name as path_name
    from public.assessment_dimension_results dr
    join public.assessment_dimensions d on d.id=dr.dimension_id
    join public.career_dimension_weights w on w.dimension_id=dr.dimension_id and w.assessment_version_id=v_attempt.assessment_version_id and w.career_track_id=v_career_id
    left join public.career_preparatory_rules r on r.career_track_id=v_career_id and r.dimension_id=dr.dimension_id and dr.raw_score < r.threshold_below and r.is_active=true
    left join public.preparatory_paths p on p.id=r.preparatory_path_id
    where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id
      and (dr.meets_minimum=false or dr.raw_score < 65)
    order by dr.raw_score asc limit 4
  ) g;

  select coalesce(jsonb_object_agg(d.code,jsonb_build_object('name',d.name,'score',dr.raw_score,'weight',dr.weight_used,'weighted_contribution',dr.weighted_contribution,'minimum',dr.minimum_score,'meets_minimum',dr.meets_minimum)),'{}'::jsonb)
    into v_dimensions
  from public.assessment_dimension_results dr join public.assessment_dimensions d on d.id=dr.dimension_id
  where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id;

  v_summary := case v_status
    when 'ready_now' then 'Your current evidence shows a strong Cabin Crew fit across the weighted dimensions, with no draft minimum-score gaps.'
    when 'ready_with_development' then 'Your current evidence shows a good Cabin Crew fit, with targeted development recommended before full readiness.'
    when 'development_required' then 'Cabin Crew remains a possible path, but the current evidence shows development priorities that should be addressed first.'
    else 'The current evidence does not yet support immediate Cabin Crew readiness. This is not a permanent rejection; the result identifies areas to develop and reassess.'
  end;

  insert into public.career_fit_results(attempt_id,career_track_id,current_fit,future_fit,rank_no,readiness_status,explanation_summary,evidence_payload)
  values(p_attempt_id,v_career_id,v_current,v_future,1,v_status,v_summary,
    jsonb_build_object(
      'methodology','Weighted Dimension Fit v1',
      'methodology_status','draft',
      'transparency_note','Weights and thresholds are Aviation Matrix methodology informed by role competencies; they are not ICAO-prescribed percentages.',
      'dimension_results',v_dimensions,
      'strengths',v_strengths,
      'development_gaps',v_gaps,
      'failed_minimum_count',v_failed_minimums,
      'future_fit_explanation','Future Fit is a development-potential estimate using Current Fit and Learning Agility; it is not guaranteed future performance.'
    )
  )
  on conflict (attempt_id,career_track_id) do update set
    current_fit=excluded.current_fit,
    future_fit=excluded.future_fit,
    rank_no=excluded.rank_no,
    readiness_status=excluded.readiness_status,
    explanation_summary=excluded.explanation_summary,
    evidence_payload=excluded.evidence_payload;

  delete from public.development_gaps where attempt_id=p_attempt_id and career_track_id=v_career_id;
  insert into public.development_gaps(attempt_id,career_track_id,dimension_id,observed_score,target_score,gap_severity,development_recommendation)
  select p_attempt_id,v_career_id,dr.dimension_id,dr.raw_score,
         coalesce(w.minimum_score,r.threshold_below,65),
         case
           when dr.raw_score < 40 then 'critical'
           when dr.raw_score < 55 then 'high'
           when dr.raw_score < 65 then 'medium'
           else 'low'
         end,
         coalesce('Recommended preparation: '||p.name,'Targeted practice and reassessment are recommended for this dimension.')
  from public.assessment_dimension_results dr
  join public.career_dimension_weights w on w.dimension_id=dr.dimension_id and w.assessment_version_id=v_attempt.assessment_version_id and w.career_track_id=v_career_id
  left join public.career_preparatory_rules r on r.career_track_id=v_career_id and r.dimension_id=dr.dimension_id and dr.raw_score < r.threshold_below and r.is_active=true
  left join public.preparatory_paths p on p.id=r.preparatory_path_id
  where dr.attempt_id=p_attempt_id and dr.career_track_id=v_career_id and (dr.meets_minimum=false or dr.raw_score < 65);

  update public.assessment_attempts set overall_score=v_current,result_payload=jsonb_build_object('career_code',p_career_code,'current_fit',v_current,'future_fit',v_future,'readiness_status',v_status,'strengths',v_strengths,'development_gaps',v_gaps) where id=p_attempt_id;

  return jsonb_build_object('career_code',p_career_code,'current_fit',v_current,'future_fit',v_future,'readiness_status',v_status,'summary',v_summary,'strengths',v_strengths,'development_gaps',v_gaps,'dimensions',v_dimensions);
end;
$$;
