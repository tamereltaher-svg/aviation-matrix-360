-- Aviation Matrix 360 — additive private Master Blueprint registry v1
-- Source of truth for blueprint content: GitHub docs/blueprint/master-blueprint.json
-- Snapshot-only projection. Never replace existing frozen AM-ARCH-1.0 architecture.
-- No production candidate, staff, payment, lesson, exam, or credential rows are changed.
-- Not exposed through Supabase Data API. No grants to anon/authenticated.
CREATE SCHEMA IF NOT EXISTS am_blueprint;
REVOKE ALL ON SCHEMA am_blueprint FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA am_blueprint TO service_role;

CREATE TABLE IF NOT EXISTS am_blueprint.snapshots (
  version_code text PRIMARY KEY,
  architecture_version_code text NOT NULL REFERENCES public.am_platform_architecture_versions(version_code) ON DELETE RESTRICT,
  repository text NOT NULL,
  source_branch text NOT NULL,
  source_baseline_sha text NOT NULL,
  manifest_path text NOT NULL,
  manifest_blob_sha text NOT NULL,
  review_state text NOT NULL DEFAULT 'draft' CHECK (review_state IN ('draft','in_review','approved','published','retired')),
  immutable_source boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT am_blueprint_repo_locked CHECK (repository = 'tamereltaher-svg/aviation-matrix-360')
);

CREATE TABLE IF NOT EXISTS am_blueprint.nodes (
  snapshot_code text NOT NULL REFERENCES am_blueprint.snapshots(version_code) ON DELETE RESTRICT,
  node_key text NOT NULL,
  parent_key text,
  kind text NOT NULL,
  title text NOT NULL,
  domain_code text,
  original_module_id uuid REFERENCES public.am_platform_modules(id) ON DELETE RESTRICT,
  baseline_status text,
  verification text NOT NULL DEFAULT 'unverified',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (snapshot_code, node_key),
  CONSTRAINT am_blueprint_parent_fk FOREIGN KEY (snapshot_code,parent_key)
    REFERENCES am_blueprint.nodes(snapshot_code,node_key) DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT am_blueprint_node_key_safe CHECK (length(node_key) BETWEEN 3 AND 160),
  CONSTRAINT am_blueprint_node_title_safe CHECK (length(title) BETWEEN 1 AND 350)
);

CREATE TABLE IF NOT EXISTS am_blueprint.edges (
  snapshot_code text NOT NULL REFERENCES am_blueprint.snapshots(version_code) ON DELETE RESTRICT,
  edge_key text NOT NULL,
  from_node_key text NOT NULL,
  to_node_key text NOT NULL,
  relationship text NOT NULL,
  verification text NOT NULL DEFAULT 'design_relationship',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (snapshot_code,edge_key),
  CONSTRAINT am_blueprint_edges_from_fk FOREIGN KEY (snapshot_code,from_node_key) 
    REFERENCES am_blueprint.nodes(snapshot_code,node_key) ON DELETE RESTRICT,
  CONSTRAINT am_blueprint_edges_to_fk FOREIGN KEY (snapshot_code,to_node_key)
    REFERENCES am_blueprint.nodes(snapshot_code,node_key) ON DELETE RESTRICT,
  CONSTRAINT am_blueprint_edges_distinct_nodes CHECK (from_node_key <> to_node_key)
);

CREATE TABLE IF NOT EXISTS am_blueprint.evidence (
  snapshot_code text NOT NULL REFERENCES am_blueprint.snapshots(version_code) ON DELETE RESTRICT,
  evidence_key text NOT NULL,
  node_key text NOT NULL,
  source_kind text NOT NULL,
  locator text NOT NULL,
  verification text NOT NULL DEFAULT 'unverified',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (snapshot_code,evidence_key),
  CONSTRAINT am_blueprint_evidence_node_fk FOREIGN KEY (snapshot_code,node_key)
    REFERENCES am_blueprint.nodes(snapshot_code,node_key) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS am_blueprint_nodes_parent_idx ON am_blueprint.nodes(snapshot_code,parent_key);
CREATE INDEX IF NOT EXISTS am_blueprint_nodes_module_idx ON am_blueprint.nodes(original_module_id) WHERE original_module_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS am_blueprint_nodes_domain_kind_idx ON am_blueprint.nodes(snapshot_code,domain_code,kind);
CREATE INDEX IF NOT EXISTS am_blueprint_edges_from_idx ON am_blueprint.edges(snapshot_code,from_node_key);
CREATE INDEX IF NOT EXISTS am_blueprint_edges_to_idx ON am_blueprint.edges(snapshot_code,to_node_key);
CREATE INDEX IF NOT EXISTS am_blueprint_evidence_node_idx ON am_blueprint.evidence(snapshot_code,node_key);

ALTER TABLE am_blueprint.snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE am_blueprint.nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE am_blueprint.edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE am_blueprint.evidence ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA am_blueprint FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA am_blueprint TO service_role;

COMMENT ON SCHEMA am_blueprint IS 'Private, versioned architecture graph projection from canonical GitHub Master Blueprint; no direct browser access.';
COMMENT ON TABLE am_blueprint.snapshots IS 'One revision linked to the frozen canonical public.am_platform_architecture_versions; draft until human approval.';
COMMENT ON TABLE am_blueprint.nodes IS 'Snapshot graph indexes; original_module_id references existing canonical am_platform_modules where applicable.';
COMMENT ON TABLE am_blueprint.edges IS 'Typed relationships between registered blueprint node keys.';
COMMENT ON TABLE am_blueprint.evidence IS 'Traceability evidence paths; reference location only, never user data or secrets.';
