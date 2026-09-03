create table if not exists assessment.speaking_rubric_bands (
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

create table if not exists assessment.speaking_rubric_level_descriptors (
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
  foreign key (bank_id, criterion_code) references assessment.speaking_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.speaking_part_criterion_weights (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  part_number smallint not null check (part_number between 1 and 3),
  criterion_code text not null,
  weight_fraction numeric(8,5) not null check (weight_fraction >= 0 and weight_fraction <= 1),
  version_code text not null,
  source_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, part_number, criterion_code),
  foreign key (bank_id, criterion_code) references assessment.speaking_rubric_criteria(bank_id, criterion_code) on delete restrict
);

create table if not exists assessment.speaking_scoring_policy (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references assessment.assessment_banks(id) on delete restrict,
  policy_code text not null,
  policy_version text not null,
  raters_required smallint not null check (raters_required >= 1),
  blind_independent_scoring boolean not null,
  interlocutor_scores boolean not null,
  criteria_count smallint not null,
  criterion_band_min smallint not null,
  criterion_band_max smallint not null,
  total_marks numeric(8,2) not null,
  score_formula text not null,
  early_rounding_allowed boolean not null,
  final_rounding_stage text not null,
  source_status text not null,
  external_certification_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bank_id, policy_code, policy_version)
);

create table if not exists assessment.speaking_adjudication_rules (
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

create table if not exists assessment.speaking_rater_policy (
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

create index if not exists idx_speaking_rubric_level_desc_bank_level on assessment.speaking_rubric_level_descriptors(bank_id, cefr_level, criterion_code);
create index if not exists idx_speaking_part_weights_bank_part on assessment.speaking_part_criterion_weights(bank_id, part_number);
create index if not exists idx_speaking_rater_policy_bank on assessment.speaking_rater_policy(bank_id, is_active);
