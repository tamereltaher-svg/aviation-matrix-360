CREATE TABLE assessment.item_lo_mappings (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  lo_id uuid,
  mapping_role text,
  evidence_role text DEFAULT 'DIR'::text,
  mapping_status text DEFAULT 'MAPPED'::text,
  confirmed_by uuid,
  confirmed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.item_options (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  option_code text,
  option_text text,
  is_correct boolean DEFAULT false,
  canonical_order smallint,
  status text DEFAULT 'ACTIVE'::text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.item_review_actions (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  action_code text,
  qa_gate text,
  reviewer_id uuid,
  review_notes text,
  previous_review_status text,
  new_review_status text,
  previous_approval_status text,
  new_approval_status text,
  previous_lifecycle_status text,
  new_lifecycle_status text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.item_scoring_keys (
  id uuid DEFAULT gen_random_uuid(),
  item_version_id uuid,
  key_payload jsonb,
  key_schema_version text DEFAULT '1.0'::text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.item_versions (
  id uuid DEFAULT gen_random_uuid(),
  item_id uuid,
  version_major smallint,
  version_minor smallint DEFAULT 0,
  stimulus_version_id uuid,
  stem_text text,
  item_type_code text,
  author_difficulty text,
  objective_eligible boolean DEFAULT false,
  scoring_mode text,
  max_raw_score numeric(8,3) DEFAULT 1,
  partial_credit_allowed boolean DEFAULT false,
  human_judgment_required boolean DEFAULT false,
  evidence_role text DEFAULT 'DIR'::text,
  domain_code text,
  construct_code text,
  language_variant text DEFAULT 'INTERNATIONAL_STANDARD_ENGLISH'::text,
  qa_reason text,
  review_status text DEFAULT 'PENDING'::text,
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

CREATE TABLE assessment.items (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  release_id uuid,
  item_code text,
  skill_code text,
  cefr_level text,
  sequence_number integer,
  current_version_id uuid,
  lifecycle_status text DEFAULT 'DRAFT_QA'::text,
  security_level text DEFAULT 'SEC-1'::text,
  exposure_status text DEFAULT 'UNUSED'::text,
  compromise_status boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  source_state text DEFAULT 'SOURCE_RETRIEVAL_REQUIRED'::text,
  hydration_tier text DEFAULT 'IDENTITY_ONLY'::text
);

CREATE TABLE assessment.learning_outcomes (
  id uuid DEFAULT gen_random_uuid(),
  lo_code text,
  competency_id uuid,
  skill_code text,
  cefr_level text,
  statement text,
  assessment_eligible boolean DEFAULT true,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  observable_verb text,
  default_evidence_type text,
  source_phase text,
  source_version text,
  registry_status text DEFAULT 'DRAFT'::text,
  ordinal_in_skill_level integer,
  approval_status text DEFAULT 'PENDING'::text,
  source_document_id uuid,
  source_row_number integer,
  source_row_sha256 text
);

CREATE TABLE assessment.listening_stimulus_audio (
  stimulus_version_id uuid,
  storage_bucket text,
  storage_object_path text,
  mime_type text,
  duration_seconds numeric(9,3),
  speaker_count integer,
  play_policy_code text,
  max_plays integer,
  accent_profile text,
  delivery_notes text,
  audio_status text DEFAULT 'PLANNED'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.lo_capacity_requirements (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  lo_id uuid,
  required_per_form integer,
  created_at timestamp with time zone DEFAULT now(),
  blueprint_version text,
  source_status text DEFAULT 'AUTHORITATIVE_SOURCE_REQUIRED'::text,
  source_reference text,
  updated_at timestamp with time zone DEFAULT now(),
  source_document_id uuid,
  source_row_number integer,
  source_row_sha256 text
);

CREATE TABLE assessment.phase06_expected_item_identities (
  id uuid DEFAULT gen_random_uuid(),
  bank_id uuid,
  release_id uuid,
  item_code text,
  skill_code text,
  cefr_level text,
  sequence_number integer,
  source_expectation text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.phase06_item_import_batches (
  id uuid DEFAULT gen_random_uuid(),
  batch_code text,
  bank_id uuid,
  source_document_id uuid,
  promotion_mode text,
  expected_item_rows integer,
  actual_item_rows integer DEFAULT 0,
  validation_status text DEFAULT 'PENDING'::text,
  blocker_count integer DEFAULT 0,
  warning_count integer DEFAULT 0,
  validated_at timestamp with time zone,
  promoted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE assessment.phase06_item_import_findings (
  id uuid DEFAULT gen_random_uuid(),
  batch_id uuid,
  row_number integer,
  item_code text,
  rule_code text,
  severity text,
  message text,
  status text DEFAULT 'OPEN'::text,
  created_at timestamp with time zone DEFAULT now(),
  resolved_at timestamp with time zone
);
