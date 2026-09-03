-- P0 security repair: least privilege grants + RPC hardening + Phase06 reviewer scope enforcement

-- 1) Exact exposed public tables: keep RLS, reduce Data API grants to intended use.
REVOKE ALL PRIVILEGES ON TABLE public.staff_accounts FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.staff_accounts FROM authenticated;
GRANT SELECT ON TABLE public.staff_accounts TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.staff_permissions FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.staff_permissions FROM authenticated;
GRANT SELECT ON TABLE public.staff_permissions TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.store_admins FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_admins FROM authenticated;
GRANT SELECT ON TABLE public.store_admins TO authenticated;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_products FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_product_variants FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_product_images FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_personalization_options FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.store_product_audiences FROM anon, authenticated;
GRANT SELECT ON TABLE public.store_products, public.store_product_variants, public.store_product_images, public.store_personalization_options, public.store_product_audiences TO anon, authenticated;

-- 2) Staff helper functions do not need to bypass RLS. Make them invoker-rights and Auth-only.
ALTER FUNCTION public.has_staff_permission(text) SECURITY INVOKER;
ALTER FUNCTION public.is_active_staff() SECURITY INVOKER;
ALTER FUNCTION public.is_store_admin() SECURITY INVOKER;

REVOKE ALL PRIVILEGES ON FUNCTION public.has_staff_permission(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.is_active_staff() FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.is_store_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_staff_permission(text), public.is_active_staff(), public.is_store_admin() TO authenticated, service_role;

-- 3) Retain legacy no-token assessment RPCs for server compatibility, but remove direct public execution.
REVOKE ALL PRIVILEGES ON FUNCTION public.start_public_career_assessment(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.submit_public_assessment_answer(uuid,uuid,uuid,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.finish_public_career_assessment(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.start_public_career_assessment(uuid,text), public.submit_public_assessment_answer(uuid,uuid,uuid,integer), public.finish_public_career_assessment(uuid,text) TO service_role;

-- Auth-bound resume RPCs should not be callable as anon.
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_application_auth(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_assessment_auth(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.public_resume_application_auth(text), public.public_resume_assessment_auth(text) TO authenticated, service_role;

-- Make intentional public application/assessment RPC exposure explicit instead of inheriting PUBLIC execute.
REVOKE ALL PRIVILEGES ON FUNCTION public.public_register_application(text,text,text,date,text,text,text,text,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_application(text,text,date) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_resume_assessment(text,text,date) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_start_assessment(text,text,date,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.public_finish_assessment(uuid,uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.public_register_application(text,text,text,date,text,text,text,text,boolean), public.register_public_aviation_lead(text,text,text,date,text,text,text,text,boolean), public.public_resume_application(text,text,date), public.public_resume_assessment(text,text,date), public.public_start_assessment(text,text,date,text), public.public_submit_assessment_answer(uuid,uuid,uuid,uuid,integer), public.public_finish_assessment(uuid,uuid,text) TO anon, authenticated, service_role;

-- 4) Phase06 reviewer scope must be enforced for every read/navigation/write path.
CREATE OR REPLACE FUNCTION assessment.is_phase06_reviewer_for_item(
  p_auth_user_id uuid,
  p_item_version_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM assessment.phase06_reviewer_queue_console q
    WHERE q.item_version_id = p_item_version_id
      AND assessment.is_phase06_reviewer(p_auth_user_id, q.cefr_level, q.skill_code)
  );
$$;

CREATE OR REPLACE FUNCTION assessment.get_phase06_review_queue_scoped(
  p_reviewer_id uuid,
  p_cefr_level text DEFAULT NULL,
  p_skill_code text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_release_code text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit,50),1),200);
  v_offset integer := greatest(coalesce(p_offset,0),0);
  v_result jsonb;
BEGIN
  IF p_reviewer_id IS NULL OR NOT assessment.is_phase06_reviewer(p_reviewer_id,NULL,NULL) THEN
    RAISE EXCEPTION 'REVIEWER_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;
  IF p_cefr_level IS NOT NULL AND p_cefr_level NOT IN ('A1','A2','B1','B2','C1','C2') THEN
    RAISE EXCEPTION 'Unsupported CEFR level %', p_cefr_level USING ERRCODE='23514';
  END IF;
  IF p_skill_code IS NOT NULL AND p_skill_code NOT IN ('LNG','RDG') THEN
    RAISE EXCEPTION 'Unsupported skill_code %', p_skill_code USING ERRCODE='23514';
  END IF;

  WITH scoped AS MATERIALIZED (
    SELECT q.*
    FROM assessment.phase06_reviewer_queue_console q
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code)
      AND (p_cefr_level IS NULL OR q.cefr_level=p_cefr_level)
      AND (p_skill_code IS NULL OR q.skill_code=p_skill_code)
      AND (p_status IS NULL OR q.pre_pilot_review_status=p_status)
      AND (p_release_code IS NULL OR q.release_code=p_release_code)
  ), page_rows AS (
    SELECT * FROM scoped q
    ORDER BY q.queue_priority,q.cefr_sort_order,q.skill_sort_order,q.sequence_number,q.item_code
    LIMIT v_limit OFFSET v_offset
  )
  SELECT jsonb_build_object(
    'total',(SELECT count(*) FROM scoped),
    'limit',v_limit,
    'offset',v_offset,
    'rows',coalesce((SELECT jsonb_agg(to_jsonb(p) - 'gate_matrix' ORDER BY p.queue_priority,p.cefr_sort_order,p.skill_sort_order,p.sequence_number,p.item_code) FROM page_rows p),'[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION assessment.get_phase06_review_progress_scoped(
  p_reviewer_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE v_result jsonb;
BEGIN
  IF p_reviewer_id IS NULL OR NOT assessment.is_phase06_reviewer(p_reviewer_id,NULL,NULL) THEN
    RAISE EXCEPTION 'REVIEWER_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  WITH scoped AS MATERIALIZED (
    SELECT q.*
    FROM assessment.phase06_reviewer_queue_console q
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code)
  ), overall AS (
    SELECT
      count(*)::integer AS total_items,
      count(*) FILTER (WHERE pre_pilot_review_status='NOT_STARTED')::integer AS not_started,
      count(*) FILTER (WHERE pre_pilot_review_status='IN_REVIEW')::integer AS in_review,
      count(*) FILTER (WHERE pre_pilot_review_status='ACTION_REQUIRED')::integer AS action_required,
      count(*) FILTER (WHERE pre_pilot_review_status='REJECTED')::integer AS rejected,
      count(*) FILTER (WHERE pre_pilot_review_status IN ('COMPLETE','COMPLETE_WITH_EDIT'))::integer AS review_complete,
      count(*) FILTER (WHERE primary_lo_mapping_status='HUMAN_CONFIRMED')::integer AS lo_human_confirmed,
      count(*) FILTER (WHERE approval_status='APPROVED')::integer AS approved_versions
    FROM scoped
  ), dims AS (
    SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY
      CASE p.cefr_level WHEN 'A1' THEN 1 WHEN 'A2' THEN 2 WHEN 'B1' THEN 3 WHEN 'B2' THEN 4 WHEN 'C1' THEN 5 WHEN 'C2' THEN 6 ELSE 99 END,
      p.skill_code),'[]'::jsonb) AS rows
    FROM assessment.phase06_review_progress_console p
    WHERE assessment.is_phase06_reviewer(p_reviewer_id,p.cefr_level,p.skill_code)
  )
  SELECT jsonb_build_object('overall',to_jsonb(o),'by_level_skill',d.rows)
  INTO v_result
  FROM overall o CROSS JOIN dims d;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION assessment.get_phase06_review_neighbor_scoped(
  p_reviewer_id uuid,
  p_item_version_id uuid,
  p_direction text DEFAULT 'NEXT',
  p_status text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_dir text := upper(trim(coalesce(p_direction,'NEXT')));
  v_current record;
  v_target record;
BEGIN
  IF v_dir NOT IN ('NEXT','PREVIOUS') THEN
    RAISE EXCEPTION 'Direction must be NEXT or PREVIOUS' USING ERRCODE='23514';
  END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('NOT_STARTED','IN_REVIEW','ACTION_REQUIRED','REJECTED','COMPLETE_WITH_EDIT','COMPLETE') THEN
    RAISE EXCEPTION 'Unsupported review status %', p_status USING ERRCODE='23514';
  END IF;

  SELECT q.* INTO v_current
  FROM assessment.phase06_reviewer_queue_console q
  WHERE q.item_version_id=p_item_version_id
    AND assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'REVIEW_SCOPE_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  SELECT q.* INTO v_target
  FROM assessment.phase06_reviewer_queue_console q
  WHERE assessment.is_phase06_reviewer(p_reviewer_id,q.cefr_level,q.skill_code)
    AND (p_status IS NULL OR q.pre_pilot_review_status=p_status)
    AND (
      (v_dir='NEXT' AND (q.cefr_sort_order,q.skill_sort_order,q.sequence_number,q.item_code) > (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
      OR
      (v_dir='PREVIOUS' AND (q.cefr_sort_order,q.skill_sort_order,q.sequence_number,q.item_code) < (v_current.cefr_sort_order,v_current.skill_sort_order,v_current.sequence_number,v_current.item_code))
    )
  ORDER BY
    CASE WHEN v_dir='NEXT' THEN q.cefr_sort_order END ASC,
    CASE WHEN v_dir='NEXT' THEN q.skill_sort_order END ASC,
    CASE WHEN v_dir='NEXT' THEN q.sequence_number END ASC,
    CASE WHEN v_dir='NEXT' THEN q.item_code END ASC,
    CASE WHEN v_dir='PREVIOUS' THEN q.cefr_sort_order END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN q.skill_sort_order END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN q.sequence_number END DESC,
    CASE WHEN v_dir='PREVIOUS' THEN q.item_code END DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('direction',v_dir,'item_version_id',NULL,'item_code',NULL,'boundary_reached',true);
  END IF;
  RETURN jsonb_build_object(
    'direction',v_dir,'item_version_id',v_target.item_version_id,'item_code',v_target.item_code,
    'cefr_level',v_target.cefr_level,'skill_code',v_target.skill_code,'sequence_number',v_target.sequence_number,
    'pre_pilot_review_status',v_target.pre_pilot_review_status,'boundary_reached',false
  );
END;
$$;

-- Defense in depth: the write RPC itself rejects out-of-scope reviewer/item pairs.
CREATE OR REPLACE FUNCTION assessment.submit_phase06_review_action(
  p_item_version_id uuid,
  p_action_code text,
  p_reviewer_id uuid,
  p_qa_gate text,
  p_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $$
DECLARE
  v_action_id uuid;
  v_item jsonb;
  v_cefr_level text;
  v_skill_code text;
BEGIN
  IF p_reviewer_id IS NULL THEN
    RAISE EXCEPTION 'Reviewer identity is required' USING ERRCODE='23514';
  END IF;

  SELECT q.cefr_level,q.skill_code
  INTO v_cefr_level,v_skill_code
  FROM assessment.phase06_reviewer_queue_console q
  WHERE q.item_version_id=p_item_version_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item version % is not in ENG-GENERAL-P06 reviewer workspace',p_item_version_id USING ERRCODE='23503';
  END IF;
  IF NOT assessment.is_phase06_reviewer(p_reviewer_id,v_cefr_level,v_skill_code) THEN
    RAISE EXCEPTION 'REVIEW_SCOPE_NOT_AUTHORIZED' USING ERRCODE='42501';
  END IF;

  v_action_id := assessment.record_item_review_action(p_item_version_id,p_action_code,p_reviewer_id,p_notes,p_qa_gate);
  SELECT assessment.get_phase06_review_item(p_item_version_id) INTO v_item;
  RETURN jsonb_build_object('action_id',v_action_id,'item',v_item);
END;
$$;

-- Service-role-only public wrappers for Edge Functions.
CREATE OR REPLACE FUNCTION public.phase06_is_reviewer_for_item(p_auth_user_id uuid,p_item_version_id uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.is_phase06_reviewer_for_item(p_auth_user_id,p_item_version_id); $$;

CREATE OR REPLACE FUNCTION public.phase06_get_review_queue_scoped(
  p_reviewer_id uuid,p_cefr_level text DEFAULT NULL,p_skill_code text DEFAULT NULL,p_status text DEFAULT NULL,p_release_code text DEFAULT NULL,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0
) RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.get_phase06_review_queue_scoped(p_reviewer_id,p_cefr_level,p_skill_code,p_status,p_release_code,p_limit,p_offset); $$;

CREATE OR REPLACE FUNCTION public.phase06_get_review_progress_scoped(p_reviewer_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.get_phase06_review_progress_scoped(p_reviewer_id); $$;

CREATE OR REPLACE FUNCTION public.phase06_get_review_neighbor_scoped(p_reviewer_id uuid,p_item_version_id uuid,p_direction text DEFAULT 'NEXT',p_status text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT assessment.get_phase06_review_neighbor_scoped(p_reviewer_id,p_item_version_id,p_direction,p_status); $$;

REVOKE ALL PRIVILEGES ON FUNCTION assessment.is_phase06_reviewer_for_item(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_queue_scoped(uuid,text,text,text,text,integer,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_progress_scoped(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION assessment.is_phase06_reviewer_for_item(uuid,uuid), assessment.get_phase06_review_queue_scoped(uuid,text,text,text,text,integer,integer), assessment.get_phase06_review_progress_scoped(uuid), assessment.get_phase06_review_neighbor_scoped(uuid,uuid,text,text) TO service_role;

REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_is_reviewer_for_item(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_get_review_queue_scoped(uuid,text,text,text,text,integer,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_get_review_progress_scoped(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.phase06_get_review_neighbor_scoped(uuid,uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.phase06_is_reviewer_for_item(uuid,uuid), public.phase06_get_review_queue_scoped(uuid,text,text,text,text,integer,integer), public.phase06_get_review_progress_scoped(uuid), public.phase06_get_review_neighbor_scoped(uuid,uuid,text,text) TO service_role;
