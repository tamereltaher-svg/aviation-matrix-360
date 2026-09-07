CREATE SCHEMA IF NOT EXISTS assessment;

CREATE TABLE assessment.accepted_answers (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  answer_value text,
  normalized_value text,
  answer_data_type text,
  case_sensitive boolean DEFAULT false,
  punctuation_sensitive boolean DEFAULT false,
  is_primary boolean DEFAULT false,
  status text DEFAULT 'ACTIVE'::text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.assessment_banks (
  id uuid DEFAULT gen_random_uuid(),
  bank_code text,
  bank_name text,
  track_code text,
  phase_code text,
  framework_code text,
  bank_status text,
  current_version text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  launch_form_equivalents smallint DEFAULT 6
);

CREATE TABLE assessment.competencies (
  id uuid DEFAULT gen_random_uuid(),
  competency_code text,
  skill_code text,
  cefr_level text,
  statement text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  source_phase text,
  source_version text,
  registry_status text DEFAULT 'DRAFT'::text,
  ordinal_in_skill_level integer,
  source_document_id uuid,
  source_row_number integer,
  source_row_sha256 text
);

CREATE TABLE assessment.deployment_gate_runs (
  id uuid DEFAULT gen_random_uuid(),
  gate_scope text,
  bank_id uuid,
  status text DEFAULT 'RUNNING'::text,
  blocker_count integer DEFAULT 0,
  major_count integer DEFAULT 0,
  warning_count integer DEFAULT 0,
  started_at timestamp with time zone DEFAULT now(),
  finished_at timestamp with time zone,
  report_version text DEFAULT 'MC10K-2.0'::text,
  notes text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.difficulty_distribution_targets (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  cefr_level text,
  skill_code text,
  difficulty_band text,
  target_count integer,
  target_share numeric(7,6),
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.form_assembly_attempts (
  id uuid DEFAULT gen_random_uuid(),
  run_id uuid,
  attempt_number integer,
  seed integer,
  status text DEFAULT 'RUNNING'::text,
  assigned_count integer DEFAULT 0,
  expected_count integer DEFAULT 0,
  hard_violation_count integer DEFAULT 0,
  major_finding_count integer DEFAULT 0,
  soft_equivalence_score numeric(18,6),
  started_at timestamp with time zone DEFAULT now(),
  finished_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  validated_plan_sha256 text,
  validated_config_sha256 text,
  validated_at timestamp with time zone
);

CREATE TABLE assessment.form_assembly_runs (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  cefr_level text,
  pool_gate text,
  method_code text DEFAULT 'DETERMINISTIC_MULTI_START_GREEDY_V1'::text,
  requested_attempts integer DEFAULT 24,
  base_seed integer DEFAULT 1,
  selected_attempt_id uuid,
  status text DEFAULT 'RUNNING'::text,
  started_at timestamp with time zone DEFAULT now(),
  finished_at timestamp with time zone,
  report_version text DEFAULT 'MC10I-1.1'::text,
  notes text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.form_blueprint_requirements (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  cefr_level text,
  skill_code text,
  required_item_count integer,
  required_stimulus_families_per_form integer,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.form_finalization_runs (
  id uuid DEFAULT gen_random_uuid(),
  assembly_run_id uuid,
  selected_attempt_id uuid,
  bank_id uuid,
  cefr_level text,
  pool_gate text,
  randomization_seed uuid DEFAULT gen_random_uuid(),
  method_code text DEFAULT 'BALANCED_KEY_POSITION_SHA256_V1'::text,
  status text DEFAULT 'RUNNING'::text,
  option_key_item_count integer DEFAULT 0,
  four_option_item_count integer DEFAULT 0,
  blocker_count integer DEFAULT 0,
  major_count integer DEFAULT 0,
  warning_count integer DEFAULT 0,
  started_at timestamp with time zone DEFAULT now(),
  finished_at timestamp with time zone,
  report_version text DEFAULT 'MC10J-2.0'::text,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  assembly_plan_sha256 text,
  assembly_config_sha256 text,
  finalization_plan_sha256 text,
  finalization_config_sha256 text,
  validated_at timestamp with time zone
);

CREATE TABLE assessment.form_items (
  id uuid DEFAULT gen_random_uuid(),
  form_version_id uuid,
  item_version_id uuid,
  stimulus_version_id uuid,
  section_code text,
  slot_number integer,
  display_order integer,
  option_order_snapshot jsonb,
  max_raw_score_snapshot numeric(8,3),
  scoring_mode_snapshot text,
  is_anchor boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.form_versions (
  id uuid DEFAULT gen_random_uuid(),
  form_id uuid,
  version_major smallint,
  version_minor smallint DEFAULT 0,
  form_status text DEFAULT 'DRAFT_FORM'::text,
  security_level text DEFAULT 'SEC-1'::text,
  blueprint_version text,
  scoring_version text,
  is_current boolean DEFAULT false,
  locked_at timestamp with time zone,
  activated_at timestamp with time zone,
  retired_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  finalization_run_id uuid,
  delivery_snapshot_sha256 text
);

CREATE TABLE assessment.forms (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  form_code text,
  cefr_level text,
  form_family text,
  current_version_id uuid,
  created_at timestamp with time zone DEFAULT now()
);
