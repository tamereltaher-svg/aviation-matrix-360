alter table assessment.writing_rubric_criteria
  add column if not exists weight_units numeric(8,4) not null default 1.0000;

create table if not exists assessment.writing_rubric_bands (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  scale_code text not null,
  band_score smallint not null check (band_score between 0 and 5),
  band_label text not null,
  generic_descriptor text not null,
  source_status text not null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, scale_code, band_score)
);

create table if not exists assessment.writing_rubric_level_descriptors (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  criterion_code text not null,
  cefr_level text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  target_descriptor text not null,
  source_status text not null,
  source_reference text null,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, criterion_code, cefr_level),
  foreign key (bank_id, criterion_code) references assessment.writing_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.writing_scoring_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  policy_version text not null,
  raters_required smallint not null check (raters_required >= 1),
  blind_independent_scoring boolean not null,
  criteria_count smallint not null check (criteria_count > 0),
  criterion_band_min smallint not null,
  criterion_band_max smallint not null,
  raw_total_min numeric(8,3) not null,
  raw_total_max numeric(8,3) not null,
  task_score_formula text not null,
  early_rounding_allowed boolean not null,
  final_rounding_stage text not null,
  source_status text not null,
  external_certification_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code, policy_version)
);

create table if not exists assessment.writing_adjudication_rules (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  rule_code text not null,
  trigger_type text not null,
  threshold_numeric numeric(10,3) null,
  rule_text text not null,
  finalization_action text not null,
  is_active boolean not null default true,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, rule_code)
);

create table if not exists assessment.writing_rater_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  requirement_type text not null,
  requirement_text text not null,
  threshold_numeric numeric(10,3) null,
  unit_code text null,
  is_active boolean not null default true,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code)
);

create table if not exists assessment.writing_special_case_rules (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  case_code text not null,
  case_name text not null,
  scoring_rule text not null,
  security_flag_required boolean not null default false,
  version_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, case_code)
);

create index if not exists idx_writing_rubric_level_descriptors_bank_level
  on assessment.writing_rubric_level_descriptors(bank_id, cefr_level, criterion_code);
create index if not exists idx_writing_adjudication_rules_bank
  on assessment.writing_adjudication_rules(bank_id, is_active);
create index if not exists idx_writing_rater_policy_bank
  on assessment.writing_rater_policy(bank_id, is_active);
