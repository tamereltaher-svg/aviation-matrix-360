CREATE TABLE assessment.phase06_item_source_documents (
  id uuid DEFAULT gen_random_uuid(),
  source_code text,
  bank_id uuid,
  release_id uuid,
  source_type text,
  source_name text,
  source_reference text,
  source_sha256 text,
  expected_item_rows integer,
  content_scope text,
  source_status text DEFAULT 'PENDING'::text,
  verified_by uuid,
  verified_at timestamp with time zone,
  verification_notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.phase06_reviewers (
  auth_user_id uuid,
  reviewer_email text,
  reviewer_status text DEFAULT 'ACTIVE'::text,
  reviewer_role text DEFAULT 'SME_REVIEWER'::text,
  can_review_lng boolean DEFAULT true,
  can_review_rdg boolean DEFAULT true,
  cefr_scope text[] DEFAULT ARRAY['A1'::text, 'A2'::text, 'B1'::text, 'B2'::text, 'C1'::text, 'C2'::text],
  notes text,
  activated_at timestamp with time zone DEFAULT now(),
  deactivated_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.pilot_cohorts (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  cohort_code text,
  cefr_level text,
  cohort_status text DEFAULT 'PLANNED'::text,
  started_at timestamp with time zone,
  ended_at timestamp with time zone,
  usable_response_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.psychometric_stats (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  pilot_cohort_id uuid,
  sample_size integer,
  p_value numeric(7,6),
  point_biserial numeric(7,6),
  item_total_correlation numeric(7,6),
  median_response_time_ms bigint,
  model_difficulty numeric,
  model_discrimination numeric,
  fit_statistic numeric,
  dif_status text DEFAULT 'NOT_TESTED'::text,
  psychometric_decision text DEFAULT 'PENDING'::text,
  calculated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.qa_defects (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  defect_code text,
  severity text,
  description text,
  status text DEFAULT 'OPEN'::text,
  remediation_action text,
  replacement_item_id uuid,
  opened_at timestamp with time zone DEFAULT now(),
  closed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.qa_reviews (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  qa_gate text,
  review_type text,
  reviewer_id uuid,
  decision text,
  review_notes text,
  reviewed_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_balance_pool_gates (
  code text,
  name text,
  sort_order integer,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_constructs (
  code text,
  skill_code text,
  name text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  description text,
  construct_family text,
  sort_order integer,
  is_phase06_allowed boolean DEFAULT false
);

CREATE TABLE assessment.ref_defect_codes (
  code text,
  name text,
  default_severity text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  qa_gate_code text,
  description text
);

CREATE TABLE assessment.ref_deployment_gate_checks (
  check_code text,
  gate_scope text,
  category text,
  fail_severity text,
  description text,
  sort_order integer,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_domains (
  code text,
  name text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  description text,
  sort_order integer,
  is_phase06_allowed boolean DEFAULT true
);

CREATE TABLE assessment.ref_form_assembly_pool_gates (
  code text,
  can_materialize boolean DEFAULT false,
  notes text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_hydration_tiers (
  code text,
  name text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_item_review_actions (
  action_code text,
  ui_label text,
  mapped_qa_decision text,
  ui_visible boolean DEFAULT true,
  is_terminal boolean DEFAULT false,
  sort_order integer,
  is_active boolean DEFAULT true
);

CREATE TABLE assessment.ref_item_types (
  code text,
  name text,
  objective_capable boolean DEFAULT true,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  response_architecture text,
  phase06_allowed boolean DEFAULT false,
  default_scoring_mode text
);

CREATE TABLE assessment.ref_qa_gates (
  code text,
  name text,
  qa_phase text,
  gate_scope text,
  required_for_pilot boolean DEFAULT false,
  required_for_active boolean DEFAULT false,
  sort_order integer,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_remediation_actions (
  code text,
  name text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_scoring_modes (
  code text,
  name text,
  deterministic boolean DEFAULT true,
  phase06_allowed boolean DEFAULT false,
  requires_options boolean DEFAULT false,
  requires_accepted_answers boolean DEFAULT false,
  requires_structured_key boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_source_expectations (
  code text,
  name text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.ref_source_states (
  code text,
  name text,
  applies_to_identity boolean DEFAULT true,
  applies_to_version boolean DEFAULT true,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.registry_source_documents (
  id uuid DEFAULT gen_random_uuid(),
  source_code text,
  source_type text,
  source_name text,
  source_reference text,
  source_phase text,
  source_version text,
  source_sha256 text,
  source_status text DEFAULT 'PENDING'::text,
  verified_by uuid,
  verified_at timestamp with time zone,
  verification_notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.releases (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  release_code text,
  release_number integer,
  item_count_expected integer,
  release_status text DEFAULT 'CLOSED'::text,
  production_date date,
  notes text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.stimuli (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  stimulus_code text,
  cefr_level text,
  stimulus_type text,
  domain_code text,
  source_type text,
  current_version_id uuid,
  lifecycle_status text DEFAULT 'DRAFT_QA'::text,
  security_level text DEFAULT 'SEC-1'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.stimulus_versions (
  id uuid DEFAULT gen_random_uuid(),
  stimulus_id uuid,
  version_major smallint,
  version_minor smallint DEFAULT 0,
  title text,
  body_text text,
  word_count integer,
  language_variant text DEFAULT 'INTERNATIONAL_STANDARD_ENGLISH'::text,
  provenance_code text,
  external_source_required boolean DEFAULT false,
  change_reason text,
  approval_status text DEFAULT 'PENDING'::text,
  is_current boolean DEFAULT false,
  is_frozen boolean DEFAULT false,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  source_document_id uuid,
  source_row_number integer,
  source_row_sha256 text,
  source_state text DEFAULT 'METADATA_REVIEW_REQUIRED'::text
);
