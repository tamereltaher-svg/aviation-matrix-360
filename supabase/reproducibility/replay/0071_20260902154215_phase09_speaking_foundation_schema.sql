create table if not exists assessment.speaking_level_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  parts_per_form smallint null check (parts_per_form is null or parts_per_form > 0),
  total_marks numeric(8,2) null check (total_marks is null or total_marks > 0),
  total_time_seconds integer null check (total_time_seconds is null or total_time_seconds > 0),
  launch_form_equivalents smallint not null check (launch_form_equivalents > 0),
  target_bank_prompts integer null check (target_bank_prompts is null or target_bank_prompts > 0),
  rubric_model_code text not null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, cefr_level)
);

create table if not exists assessment.speaking_task_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  part_number smallint not null check (part_number > 0),
  task_family text null,
  interaction_mode text null,
  prompt_count smallint null check (prompt_count is null or prompt_count > 0),
  preparation_seconds integer null check (preparation_seconds is null or preparation_seconds >= 0),
  response_seconds integer null check (response_seconds is null or response_seconds > 0),
  marks numeric(8,2) null check (marks is null or marks > 0),
  interlocutor_role text null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  source_reference text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, cefr_level, part_number)
);

create table if not exists assessment.speaking_rubric_criteria (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  criterion_code text not null,
  criterion_name text not null,
  ordinal smallint not null check (ordinal > 0),
  criterion_definition text not null,
  weight_units numeric(8,4) null,
  weighting_status text not null,
  source_status text not null,
  source_reference text null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, criterion_code),
  unique(bank_id, ordinal)
);

create table if not exists assessment.speaking_lo_construct_map (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  lo_id uuid not null references assessment.learning_outcomes(id) on delete restrict,
  criterion_code text not null,
  mapping_status text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  unique(bank_id, lo_id),
  foreign key (bank_id, criterion_code) references assessment.speaking_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.speaking_item_specs (
  item_version_id uuid primary key references assessment.item_versions(id) on delete restrict,
  part_number smallint not null check (part_number > 0),
  task_family text null,
  interaction_mode text null,
  preparation_seconds integer null check (preparation_seconds is null or preparation_seconds >= 0),
  response_seconds integer null check (response_seconds is null or response_seconds > 0),
  rubric_version text not null,
  response_mode_code text not null default 'SPOKEN_RESPONSE',
  scoring_status text not null default 'HUMAN_SCORING_REQUIRED',
  evidence_status text not null default 'EVIDENCE_POLICY_PENDING',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists assessment.speaking_evidence_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  audio_recording_required boolean null,
  video_recording_required boolean null,
  live_interlocutor_required boolean null,
  second_rater_mode text null,
  retention_rule text null,
  source_status text not null,
  recovery_status text not null,
  version_code text not null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code)
);

create index if not exists idx_speaking_level_policies_bank on assessment.speaking_level_policies(bank_id, cefr_level);
create index if not exists idx_speaking_task_policies_bank on assessment.speaking_task_policies(bank_id, cefr_level, part_number);
create index if not exists idx_speaking_lo_construct_map_bank on assessment.speaking_lo_construct_map(bank_id, criterion_code);
