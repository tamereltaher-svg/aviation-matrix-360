create table if not exists public.am_evidence_type_registry (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  default_validity_days integer,
  verification_required boolean not null default true,
  status text not null default 'active' check (status in ('active','inactive','archived')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.am_evidence_type_registry(code,name,verification_required) values
('assessment_result','Assessment Result',true),('exam_result','Exam Result',true),('training_completion','Training Completion',true),('certificate','Certificate',true),('document','Document',true),('interview','Interview Evidence',true),('attendance','Attendance Evidence',true),('instructor_feedback','Instructor Feedback',true),('video','Video Evidence',true),('reference','Reference Evidence',true),('system_result','System Result',true)
on conflict (code) do nothing;

create table if not exists public.am_evidence_verifications (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.am_candidate_evidence(id) on delete cascade,
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','expired','revoked')),
  verification_method text,
  verified_by uuid,
  verified_at timestamptz,
  notes text,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_evidence_verifications_evidence_idx on public.am_evidence_verifications(evidence_id,created_at desc);

create table if not exists public.am_candidate_facts (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  fact_code text not null,
  fact_category text,
  value_json jsonb not null,
  source_type text not null default 'manual' check (source_type in ('manual','evidence','assessment','exam','document','system','import')),
  source_evidence_id uuid references public.am_candidate_evidence(id) on delete set null,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','verified','rejected','expired','revoked')),
  valid_from timestamptz,
  valid_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists am_candidate_facts_candidate_code_idx on public.am_candidate_facts(candidate_id,fact_code,created_at desc);

create table if not exists public.am_competency_frameworks (
  id uuid primary key default gen_random_uuid(),
  framework_code text not null unique,
  name text not null,
  description text,
  version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','active','retired','archived')),
  effective_from timestamptz,
  effective_to timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_competencies (
  id uuid primary key default gen_random_uuid(),
  framework_id uuid not null references public.am_competency_frameworks(id) on delete cascade,
  competency_code text not null,
  name text not null,
  description text,
  category text,
  parent_competency_id uuid references public.am_competencies(id) on delete set null,
  scale_min numeric not null default 0,
  scale_max numeric not null default 100,
  sort_order integer not null default 0,
  status text not null default 'active' check (status in ('active','inactive','archived')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(framework_id,competency_code)
);

create table if not exists public.am_candidate_competency_ratings (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  competency_id uuid not null references public.am_competencies(id) on delete cascade,
  rating numeric not null,
  rating_status text not null default 'provisional' check (rating_status in ('provisional','verified','superseded','revoked')),
  source_method text not null default 'manual',
  calculated_at timestamptz not null default now(),
  valid_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_candidate_competency_candidate_idx on public.am_candidate_competency_ratings(candidate_id,competency_id,calculated_at desc);

create table if not exists public.am_competency_evidence_links (
  id uuid primary key default gen_random_uuid(),
  rating_id uuid not null references public.am_candidate_competency_ratings(id) on delete cascade,
  evidence_id uuid not null references public.am_candidate_evidence(id) on delete cascade,
  contribution_weight numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(rating_id,evidence_id)
);

create table if not exists public.am_requirement_evaluation_runs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.am_candidate_records(id) on delete cascade,
  requirement_set_id uuid not null references public.am_requirement_sets(id) on delete cascade,
  campaign_id uuid references public.am_recruitment_campaigns(id) on delete set null,
  candidate_match_id uuid references public.am_candidate_matches(id) on delete set null,
  run_status text not null default 'running' check (run_status in ('running','completed','failed','cancelled')),
  mandatory_met boolean,
  overall_score numeric,
  matched_count integer not null default 0,
  gap_count integer not null default 0,
  manual_review_count integer not null default 0,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  engine_version text not null default 'REQ-1.0',
  input_snapshot jsonb not null default '{}'::jsonb,
  result_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_req_eval_candidate_idx on public.am_requirement_evaluation_runs(candidate_id,created_at desc);

create table if not exists public.am_requirement_evaluation_results (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.am_requirement_evaluation_runs(id) on delete cascade,
  requirement_item_id uuid not null references public.am_requirement_items(id) on delete cascade,
  evaluation_status text not null check (evaluation_status in ('met','gap','manual_review','not_applicable')),
  mandatory boolean not null default false,
  weight numeric,
  actual_value jsonb,
  expected_value jsonb,
  evidence_id uuid references public.am_candidate_evidence(id) on delete set null,
  fact_id uuid references public.am_candidate_facts(id) on delete set null,
  explanation text,
  evaluated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique(run_id,requirement_item_id)
);

create table if not exists public.am_decision_records (
  id uuid primary key default gen_random_uuid(),
  decision_code text not null,
  subject_type text not null,
  subject_id uuid,
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  decision_type text not null,
  decision_value text not null,
  decision_status text not null default 'proposed' check (decision_status in ('proposed','approved','rejected','superseded','revoked','final')),
  decision_source text not null default 'human' check (decision_source in ('human','rule','system','ai','hybrid')),
  rule_version text,
  rationale text,
  decided_by uuid,
  decided_at timestamptz not null default now(),
  input_snapshot jsonb not null default '{}'::jsonb,
  output_snapshot jsonb not null default '{}'::jsonb,
  supersedes_decision_id uuid references public.am_decision_records(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists am_decision_candidate_idx on public.am_decision_records(candidate_id,decided_at desc);

create table if not exists public.am_decision_evidence_links (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null references public.am_decision_records(id) on delete cascade,
  evidence_id uuid not null references public.am_candidate_evidence(id) on delete cascade,
  role text not null default 'supporting' check (role in ('supporting','contradicting','required','context')),
  created_at timestamptz not null default now(),
  unique(decision_id,evidence_id)
);

create table if not exists public.am_workflow_templates (
  id uuid primary key default gen_random_uuid(),
  workflow_code text not null unique,
  name text not null,
  domain_code text,
  description text,
  version_no integer not null default 1,
  status text not null default 'draft' check (status in ('draft','active','retired','archived')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.am_workflow_steps (
  id uuid primary key default gen_random_uuid(),
  workflow_template_id uuid not null references public.am_workflow_templates(id) on delete cascade,
  step_code text not null,
  name text not null,
  step_type text not null default 'task' check (step_type in ('task','review','approval','decision','notification','system')),
  sort_order integer not null default 0,
  required boolean not null default true,
  role_code text,
  sla_hours numeric,
  entry_rule jsonb not null default '{}'::jsonb,
  completion_rule jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  unique(workflow_template_id,step_code)
);

create table if not exists public.am_workflow_instances (
  id uuid primary key default gen_random_uuid(),
  workflow_template_id uuid not null references public.am_workflow_templates(id) on delete restrict,
  subject_type text not null,
  subject_id uuid,
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  status text not null default 'active' check (status in ('active','paused','completed','cancelled','failed')),
  current_step_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.am_workflow_tasks (
  id uuid primary key default gen_random_uuid(),
  workflow_instance_id uuid not null references public.am_workflow_instances(id) on delete cascade,
  workflow_step_id uuid references public.am_workflow_steps(id) on delete set null,
  task_code text not null,
  title text not null,
  assigned_to uuid,
  assigned_role text,
  status text not null default 'pending' check (status in ('pending','in_progress','waiting','completed','cancelled','failed')),
  priority text not null default 'normal' check (priority in ('low','normal','high','critical')),
  due_at timestamptz,
  completed_at timestamptz,
  outcome jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists am_workflow_tasks_instance_idx on public.am_workflow_tasks(workflow_instance_id,status);

create table if not exists public.am_approval_records (
  id uuid primary key default gen_random_uuid(),
  workflow_instance_id uuid references public.am_workflow_instances(id) on delete cascade,
  task_id uuid references public.am_workflow_tasks(id) on delete set null,
  subject_type text not null,
  subject_id uuid,
  approval_type text not null,
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected','cancelled','expired')),
  requested_by uuid,
  requested_at timestamptz not null default now(),
  decided_by uuid,
  decided_at timestamptz,
  comments text,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.am_communications (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  employer_id uuid references public.am_employer_organizations(id) on delete set null,
  campaign_id uuid references public.am_recruitment_campaigns(id) on delete set null,
  channel text not null check (channel in ('email','whatsapp','sms','phone','meeting','interview','notification','portal','other')),
  direction text not null default 'internal' check (direction in ('inbound','outbound','internal')),
  subject text,
  summary text not null,
  communication_status text not null default 'recorded' check (communication_status in ('draft','scheduled','sent','delivered','failed','received','recorded','cancelled')),
  occurred_at timestamptz not null default now(),
  created_by uuid,
  external_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_communications_candidate_idx on public.am_communications(candidate_id,occurred_at desc);

create table if not exists public.am_communication_participants (
  id uuid primary key default gen_random_uuid(),
  communication_id uuid not null references public.am_communications(id) on delete cascade,
  participant_type text not null check (participant_type in ('candidate','guardian','staff','employer_contact','institution','external')),
  participant_id uuid,
  display_name text,
  address text,
  participant_role text,
  created_at timestamptz not null default now()
);

create table if not exists public.am_intelligence_events (
  id uuid primary key default gen_random_uuid(),
  event_code text not null,
  event_type text not null,
  domain_code text,
  candidate_id uuid references public.am_candidate_records(id) on delete set null,
  case_id uuid references public.am_candidate_cases(id) on delete set null,
  subject_type text,
  subject_id uuid,
  source_system text not null default 'aviation_matrix',
  source_table text,
  source_id uuid,
  event_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists am_intelligence_events_candidate_idx on public.am_intelligence_events(candidate_id,event_at desc);

create or replace function public.am_evaluate_candidate_requirements(p_candidate_id uuid,p_requirement_set_id uuid,p_campaign_id uuid default null,p_candidate_match_id uuid default null)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_run uuid;
  r record;
  v_evidence public.am_candidate_evidence%rowtype;
  v_fact public.am_candidate_facts%rowtype;
  v_status text;
  v_actual jsonb;
  v_met int := 0;
  v_gap int := 0;
  v_manual int := 0;
  v_total_weight numeric := 0;
  v_met_weight numeric := 0;
  v_mandatory_met boolean := true;
  v_operator text;
  v_expected_text text;
  v_actual_text text;
begin
  insert into public.am_requirement_evaluation_runs(candidate_id,requirement_set_id,campaign_id,candidate_match_id,input_snapshot)
  values(p_candidate_id,p_requirement_set_id,p_campaign_id,p_candidate_match_id,jsonb_build_object('candidate_id',p_candidate_id,'requirement_set_id',p_requirement_set_id,'campaign_id',p_campaign_id)) returning id into v_run;

  for r in select * from public.am_requirement_items where requirement_set_id=p_requirement_set_id and status='active' order by sort_order,id loop
    v_evidence := null; v_fact := null; v_status := 'manual_review'; v_actual := null; v_operator := coalesce(r.operator,'exists');

    if nullif(r.metadata->>'fact_code','') is not null then
      select * into v_fact from public.am_candidate_facts f
      where f.candidate_id=p_candidate_id and f.fact_code=(r.metadata->>'fact_code')
        and f.verification_status in ('verified','unverified')
        and (f.valid_until is null or f.valid_until>=now())
      order by (f.verification_status='verified') desc,f.created_at desc limit 1;
      if found then
        v_actual := v_fact.value_json;
        v_expected_text := coalesce(r.expected_value->>'value',trim(both '"' from coalesce(r.expected_value::text,'')));
        v_actual_text := coalesce(v_actual->>'value',trim(both '"' from v_actual::text));
        if v_operator in ('exists','present') then v_status:='met';
        elsif v_operator in ('eq','=') then v_status:=case when v_actual_text=v_expected_text then 'met' else 'gap' end;
        elsif v_operator in ('neq','!=') then v_status:=case when v_actual_text<>v_expected_text then 'met' else 'gap' end;
        elsif v_operator in ('gte','>=','lte','<=','gt','>','lt','<') and v_actual_text ~ '^-?[0-9]+([.][0-9]+)?$' and v_expected_text ~ '^-?[0-9]+([.][0-9]+)?$' then
          if v_operator in ('gte','>=') then v_status:=case when v_actual_text::numeric>=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('lte','<=') then v_status:=case when v_actual_text::numeric<=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('gt','>') then v_status:=case when v_actual_text::numeric>v_expected_text::numeric then 'met' else 'gap' end;
          else v_status:=case when v_actual_text::numeric<v_expected_text::numeric then 'met' else 'gap' end; end if;
        else v_status:='manual_review'; end if;
      else
        v_status:=case when r.is_mandatory then 'gap' else 'manual_review' end;
      end if;
    elsif r.evidence_type is not null then
      select * into v_evidence from public.am_candidate_evidence e
      where e.candidate_id=p_candidate_id and e.evidence_type=r.evidence_type
        and e.status in ('verified','accepted','valid','final')
        and (e.valid_until is null or e.valid_until>=now())
      order by e.verified_at desc nulls last,e.issued_at desc nulls last,e.created_at desc limit 1;
      if found then
        v_actual:=jsonb_build_object('evidence_id',v_evidence.id,'score',v_evidence.score,'status',v_evidence.status,'valid_until',v_evidence.valid_until);
        if v_operator in ('exists','present') then v_status:='met';
        elsif v_evidence.score is not null and r.expected_value is not null and coalesce(r.expected_value->>'value','') ~ '^-?[0-9]+([.][0-9]+)?$' then
          v_expected_text:=r.expected_value->>'value';
          if v_operator in ('gte','>=') then v_status:=case when v_evidence.score>=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('lte','<=') then v_status:=case when v_evidence.score<=v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('gt','>') then v_status:=case when v_evidence.score>v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('lt','<') then v_status:=case when v_evidence.score<v_expected_text::numeric then 'met' else 'gap' end;
          elsif v_operator in ('eq','=') then v_status:=case when v_evidence.score=v_expected_text::numeric then 'met' else 'gap' end;
          else v_status:='manual_review'; end if;
        else v_status:='manual_review'; end if;
      else
        v_status:=case when r.is_mandatory then 'gap' else 'manual_review' end;
      end if;
    else
      v_status:='manual_review';
    end if;

    insert into public.am_requirement_evaluation_results(run_id,requirement_item_id,evaluation_status,mandatory,weight,actual_value,expected_value,evidence_id,fact_id,explanation)
    values(v_run,r.id,v_status,r.is_mandatory,coalesce(r.weight,1),v_actual,r.expected_value,v_evidence.id,v_fact.id,
      case v_status when 'met' then 'Requirement satisfied by current candidate fact/evidence.' when 'gap' then 'Requirement not satisfied or required evidence is missing.' else 'Automatic evaluation is insufficient; human review required.' end);

    v_total_weight:=v_total_weight+coalesce(r.weight,1);
    if v_status='met' then v_met:=v_met+1; v_met_weight:=v_met_weight+coalesce(r.weight,1); end if;
    if v_status='gap' then v_gap:=v_gap+1; end if;
    if v_status='manual_review' then v_manual:=v_manual+1; end if;
    if r.is_mandatory and v_status<>'met' then v_mandatory_met:=false; end if;
  end loop;

  update public.am_requirement_evaluation_runs set run_status='completed',mandatory_met=v_mandatory_met,
    overall_score=case when v_total_weight=0 then null else round((v_met_weight/v_total_weight)*100,2) end,
    matched_count=v_met,gap_count=v_gap,manual_review_count=v_manual,completed_at=now(),
    result_snapshot=jsonb_build_object('matched',v_met,'gaps',v_gap,'manual_review',v_manual,'mandatory_met',v_mandatory_met)
  where id=v_run;

  if p_candidate_match_id is not null then
    update public.am_candidate_matches m set match_status=case when v_mandatory_met and v_gap=0 and v_manual=0 then 'qualified' when not v_mandatory_met then 'gap' else 'manual_review' end,
      overall_score=(select overall_score from public.am_requirement_evaluation_runs where id=v_run),mandatory_met=v_mandatory_met,matched_count=v_met,gap_count=v_gap,evaluated_at=now(),
      evaluation_snapshot=jsonb_build_object('requirement_run_id',v_run,'manual_review_count',v_manual)
    where m.id=p_candidate_match_id;
  end if;

  insert into public.am_intelligence_events(event_code,event_type,domain_code,candidate_id,subject_type,subject_id,source_table,source_id,payload)
  values('REQUIREMENT_EVALUATED','requirement_evaluation','AIR',p_candidate_id,'requirement_set',p_requirement_set_id,'am_requirement_evaluation_runs',v_run,jsonb_build_object('matched',v_met,'gaps',v_gap,'manual_review',v_manual,'mandatory_met',v_mandatory_met));
  return v_run;
exception when others then
  if v_run is not null then update public.am_requirement_evaluation_runs set run_status='failed',completed_at=now(),result_snapshot=jsonb_build_object('error',sqlerrm) where id=v_run; end if;
  raise;
end;
$$;
revoke all on function public.am_evaluate_candidate_requirements(uuid,uuid,uuid,uuid) from public,anon,authenticated;

create or replace view public.am_core_intelligence_summary with (security_invoker=true) as
select
 (select count(*) from public.am_evidence_type_registry) evidence_types,
 (select count(*) from public.am_candidate_facts) candidate_facts,
 (select count(*) from public.am_competency_frameworks) competency_frameworks,
 (select count(*) from public.am_competencies) competencies,
 (select count(*) from public.am_candidate_competency_ratings) competency_ratings,
 (select count(*) from public.am_requirement_evaluation_runs) requirement_runs,
 (select count(*) from public.am_decision_records) decisions,
 (select count(*) from public.am_workflow_templates) workflow_templates,
 (select count(*) from public.am_workflow_instances) workflow_instances,
 (select count(*) from public.am_workflow_tasks) workflow_tasks,
 (select count(*) from public.am_approval_records) approvals,
 (select count(*) from public.am_communications) communications,
 (select count(*) from public.am_intelligence_events) intelligence_events;
revoke all on public.am_core_intelligence_summary from anon,authenticated;

alter table public.am_evidence_type_registry enable row level security;
alter table public.am_evidence_verifications enable row level security;
alter table public.am_candidate_facts enable row level security;
alter table public.am_competency_frameworks enable row level security;
alter table public.am_competencies enable row level security;
alter table public.am_candidate_competency_ratings enable row level security;
alter table public.am_competency_evidence_links enable row level security;
alter table public.am_requirement_evaluation_runs enable row level security;
alter table public.am_requirement_evaluation_results enable row level security;
alter table public.am_decision_records enable row level security;
alter table public.am_decision_evidence_links enable row level security;
alter table public.am_workflow_templates enable row level security;
alter table public.am_workflow_steps enable row level security;
alter table public.am_workflow_instances enable row level security;
alter table public.am_workflow_tasks enable row level security;
alter table public.am_approval_records enable row level security;
alter table public.am_communications enable row level security;
alter table public.am_communication_participants enable row level security;
alter table public.am_intelligence_events enable row level security;

update public.am_platform_modules set status='partial' where code in ('PLT-CMP','PLT-WF','PLT-DEC','PLT-COM','AIR-REQ','TAL-EVD');
