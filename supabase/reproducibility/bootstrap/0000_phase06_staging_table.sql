CREATE SCHEMA IF NOT EXISTS assessment_staging;

CREATE TABLE assessment_staging.phase06_stimuli_import (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  batch_id uuid NOT NULL,
  row_number integer NOT NULL,
  stimulus_code text NOT NULL,
  cefr_level text NOT NULL,
  stimulus_type text NOT NULL,
  domain_code text,
  source_type text NOT NULL,
  version_major smallint NOT NULL,
  version_minor smallint DEFAULT 0 NOT NULL,
  title text,
  body_text text NOT NULL,
  word_count integer NOT NULL,
  language_variant text DEFAULT 'INTERNATIONAL_STANDARD_ENGLISH'::text NOT NULL,
  provenance_code text NOT NULL,
  external_source_required boolean DEFAULT false NOT NULL,
  approval_status text DEFAULT 'PENDING'::text NOT NULL,
  source_state text NOT NULL,
  computed_row_sha256 text,
  row_status text DEFAULT 'PENDING'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);
