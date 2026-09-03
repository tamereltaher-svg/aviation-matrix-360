create table if not exists assessment.writing_level_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null,
  tasks_per_form smallint not null check (tasks_per_form > 0),
  total_marks smallint not null check (total_marks > 0),
  time_minutes smallint null check (time_minutes is null or time_minutes > 0),
  launch_form_equivalents smallint not null check (launch_form_equivalents > 0),
  target_bank_prompts integer not null check (target_bank_prompts > 0),
  rubric_model_code text not null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, cefr_level)
);

create table if not exists assessment.writing_task_policies (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  cefr_level text not null,
  task_number smallint not null check (task_number in (1,2)),
  marks smallint not null check (marks > 0),
  word_min integer null check (word_min is null or word_min >= 0),
  word_max integer null check (word_max is null or word_max >= 0),
  task_family text null,
  task_description text null,
  blueprint_version text not null,
  source_status text not null,
  recovery_status text not null,
  source_reference text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (word_min is null or word_max is null or word_max >= word_min),
  unique(bank_id, cefr_level, task_number)
);

create table if not exists assessment.writing_rubric_criteria (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  criterion_code text not null,
  criterion_name text not null,
  ordinal smallint not null check (ordinal > 0),
  criterion_definition text null,
  weighting_status text not null,
  blueprint_version text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, criterion_code),
  unique(bank_id, ordinal)
);

create table if not exists assessment.writing_item_specs (
  item_version_id uuid primary key references assessment.item_versions(id) on delete restrict,
  task_number smallint not null check (task_number in (1,2)),
  word_min integer null check (word_min is null or word_min >= 0),
  word_max integer null check (word_max is null or word_max >= 0),
  rubric_version text not null,
  response_mode_code text not null default 'EXTENDED_WRITING',
  scoring_status text not null default 'HUMAN_SCORING_REQUIRED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (word_min is null or word_max is null or word_max >= word_min)
);

create index if not exists idx_writing_level_policies_bank on assessment.writing_level_policies(bank_id, cefr_level);
create index if not exists idx_writing_task_policies_bank on assessment.writing_task_policies(bank_id, cefr_level, task_number);
create index if not exists idx_writing_rubric_criteria_bank on assessment.writing_rubric_criteria(bank_id, ordinal);
