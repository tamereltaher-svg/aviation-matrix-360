CREATE OR REPLACE FUNCTION assessment.validate_phase06_item_import_batch(p_batch_id uuid)
 RETURNS TABLE(validation_status text, blocker_count integer, warning_count integer)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare b assessment.phase06_item_import_batches%rowtype; src assessment.phase06_item_source_documents%rowtype; v_block integer; v_warn integer;
begin
  select * into b from assessment.phase06_item_import_batches where id=p_batch_id;
  if not found then raise exception 'Unknown Phase06 item import batch %',p_batch_id using errcode='23503'; end if;
  select * into src from assessment.phase06_item_source_documents where id=b.source_document_id;
  delete from assessment.phase06_item_import_findings where batch_id=p_batch_id;
  update assessment.phase06_item_import_batches set validation_status='VALIDATING' where id=p_batch_id;

  if src.source_status<>'VERIFIED' then
    insert into assessment.phase06_item_import_findings(batch_id,rule_code,severity,message) values(p_batch_id,'P06SRC001','BLOCKER','Source document is not VERIFIED');
  end if;
  if src.bank_id<>b.bank_id then
    insert into assessment.phase06_item_import_findings(batch_id,rule_code,severity,message) values(p_batch_id,'P06SRC002','BLOCKER','Source document bank does not match import batch bank');
  end if;
  if b.promotion_mode='IDENTITY_ONLY' and src.content_scope<>'IDENTITY_ONLY' then
    insert into assessment.phase06_item_import_findings(batch_id,rule_code,severity,message) values(p_batch_id,'P06SRC004','WARNING','IDENTITY_ONLY batch points to a source document whose content_scope is not IDENTITY_ONLY');
  end if;
  if b.promotion_mode in ('CONTENT_TO_DRAFT','QA_PATCH') and src.content_scope='IDENTITY_ONLY' then
    insert into assessment.phase06_item_import_findings(batch_id,rule_code,severity,message) values(p_batch_id,'P06SRC005','BLOCKER','Content promotion cannot use an IDENTITY_ONLY source document');
  end if;
  if src.expected_item_rows is not null and src.expected_item_rows <> (select count(*) from assessment_staging.phase06_items_import where batch_id=p_batch_id) then
    insert into assessment.phase06_item_import_findings(batch_id,rule_code,severity,message) values(p_batch_id,'P06SRC006','BLOCKER','Staged item row count does not match source-document expected_item_rows');
  end if;
  if b.expected_item_rows is not null and b.expected_item_rows <> (select count(*) from assessment_staging.phase06_items_import where batch_id=p_batch_id) then
    insert into assessment.phase06_item_import_findings(batch_id,rule_code,severity,message) values(p_batch_id,'P06SRC007','BLOCKER','Staged item row count does not match batch expected_item_rows');
  end if;

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06ID001','BLOCKER','Item identity does not match the frozen Phase06 manifest'
  from assessment_staging.phase06_items_import s
  left join assessment.phase06_expected_item_identities e on e.bank_id=b.bank_id and e.item_code=s.item_code
  left join assessment.releases r on r.id=e.release_id
  where s.batch_id=p_batch_id and (e.id is null or e.skill_code<>s.skill_code or e.cefr_level<>s.cefr_level or e.sequence_number<>s.sequence_number or r.release_code<>s.release_code);

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06SRC008','BLOCKER','Release-scoped source contains an item outside its declared release'
  from assessment_staging.phase06_items_import s
  join assessment.phase06_expected_item_identities e on e.bank_id=b.bank_id and e.item_code=s.item_code
  where s.batch_id=p_batch_id and src.release_id is not null and e.release_id<>src.release_id;

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06SRC003','WARNING','Legacy R01-R08 row is being hydrated; verify this is a recovered original source, not regenerated content'
  from assessment_staging.phase06_items_import s join assessment.phase06_expected_item_identities e on e.bank_id=b.bank_id and e.item_code=s.item_code
  where s.batch_id=p_batch_id and e.source_expectation='LEGACY_SOURCE_GAP' and s.hydration_tier<>'IDENTITY_ONLY';

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,row_number,item_code,'P06CNT001','BLOCKER','Hydrated item is missing one or more mandatory version/scoring fields'
  from assessment_staging.phase06_items_import
  where batch_id=p_batch_id and hydration_tier<>'IDENTITY_ONLY' and (
    version_major is null or version_minor is null or nullif(trim(stem_text),'') is null or nullif(trim(item_type_code),'') is null or
    author_difficulty not in ('D1','D2','D3','D4') or objective_eligible is null or scoring_mode not in ('OPTION_KEY','EXACT_KEY','FINITE_KEYSET','BOOLEAN_KEY','MATCH_KEY','ORDER_KEY') or
    max_raw_score is null or partial_credit_allowed is null or human_judgment_required is null or evidence_role not in ('DIR','SUP','REP','BND','PRD','REC') or
    nullif(trim(language_variant),'') is null or review_status not in ('PENDING','IN_REVIEW','PASS','PASS_WITH_EDIT','REMEDIATE','REJECT') or approval_status not in ('PENDING','APPROVED','REJECTED')
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,row_number,item_code,'P06CNT002','BLOCKER','Hydrated content cannot retain SOURCE_RETRIEVAL_REQUIRED or an invalid source_state/hydration_tier'
  from assessment_staging.phase06_items_import
  where batch_id=p_batch_id and hydration_tier<>'IDENTITY_ONLY' and (
    source_state not in ('SOURCE_EXACT','SOURCE_EXACT_METADATA_NORMALIZED','QA_VERSION_RECONSTRUCTED','METADATA_REVIEW_REQUIRED')
    or hydration_tier not in ('CONTENT_HYDRATED','METADATA_REVIEW','QA_VERIFIED')
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,row_number,item_code,'P06SCR001','BLOCKER','Hydrated Phase06 item violates one-point deterministic objective scoring contract'
  from assessment_staging.phase06_items_import
  where batch_id=p_batch_id and hydration_tier<>'IDENTITY_ONLY' and (
    objective_eligible is distinct from true or human_judgment_required is distinct from false or partial_credit_allowed is distinct from false or max_raw_score<>1
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06SCR005','BLOCKER','item_type_code and scoring_mode are not an active Phase06-compatible pair'
  from assessment_staging.phase06_items_import s
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY'
    and not exists (
      select 1
      from assessment.ref_item_type_scoring_modes x
      join assessment.ref_item_types it on it.code=x.item_type_code and it.is_active and it.phase06_allowed
      join assessment.ref_scoring_modes sm on sm.code=x.scoring_mode_code and sm.is_active and sm.phase06_allowed
      where x.item_type_code=s.item_type_code
        and x.scoring_mode_code=s.scoring_mode
        and x.is_active
        and x.phase06_allowed
    );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06REF001','BLOCKER','Unknown or inactive item_type_code'
  from assessment_staging.phase06_items_import s left join assessment.ref_item_types t on t.code=s.item_type_code and t.is_active
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and t.code is null;
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06REF002','BLOCKER','Unknown domain_code'
  from assessment_staging.phase06_items_import s left join assessment.ref_domains d on d.code=s.domain_code and d.is_active
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and s.domain_code is not null and d.code is null;
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06REF003','BLOCKER','Unknown or wrong-skill construct_code'
  from assessment_staging.phase06_items_import s left join assessment.ref_constructs c on c.code=s.construct_code and c.skill_code=s.skill_code and c.is_active
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and s.construct_code is not null and c.code is null;
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06REF004','BLOCKER','Unknown, inactive or Phase06-disallowed scoring_mode'
  from assessment_staging.phase06_items_import s
  left join assessment.ref_scoring_modes m on m.code=s.scoring_mode and m.is_active and m.phase06_allowed
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and m.code is null;
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06REF005','BLOCKER','Unknown or inactive source_state'
  from assessment_staging.phase06_items_import s
  left join assessment.ref_source_states rs on rs.code=s.source_state and rs.is_active
  where s.batch_id=p_batch_id and rs.code is null;
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06REF006','BLOCKER','Unknown or inactive hydration_tier'
  from assessment_staging.phase06_items_import s
  left join assessment.ref_hydration_tiers rh on rh.code=s.hydration_tier and rh.is_active
  where s.batch_id=p_batch_id and rh.code is null;
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,q.row_number,q.item_code,'P06QA001','BLOCKER','Unknown or inactive QA gate'
  from assessment_staging.phase06_qa_reviews_import q
  left join assessment.ref_qa_gates g on g.code=q.qa_gate and g.is_active
  where q.batch_id=p_batch_id and g.code is null;

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06STM001','BLOCKER','Hydrated Reading item has no resolvable stimulus version'
  from assessment_staging.phase06_items_import s
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and s.skill_code='RDG' and (
    s.stimulus_code is null or s.stimulus_version_major is null or s.stimulus_version_minor is null or not exists (
      select 1 from assessment_staging.phase06_stimuli_import ss where ss.batch_id=p_batch_id and ss.stimulus_code=s.stimulus_code and ss.version_major=s.stimulus_version_major and ss.version_minor=s.stimulus_version_minor
      union all
      select 1 from assessment.stimuli st join assessment.stimulus_versions sv on sv.stimulus_id=st.id
      where st.bank_id=b.bank_id and st.stimulus_code=s.stimulus_code and sv.version_major=s.stimulus_version_major and sv.version_minor=s.stimulus_version_minor
    )
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06STM002','BLOCKER','Reading item stimulus CEFR level does not match item CEFR level'
  from assessment_staging.phase06_items_import s
  join assessment_staging.phase06_stimuli_import ss on ss.batch_id=p_batch_id and ss.stimulus_code=s.stimulus_code and ss.version_major=s.stimulus_version_major and ss.version_minor=s.stimulus_version_minor
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and s.skill_code='RDG' and ss.cefr_level<>s.cefr_level;

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,ss.row_number,null,'P06STM003','BLOCKER','Stimulus source row has invalid/blank required content or reference metadata'
  from assessment_staging.phase06_stimuli_import ss
  where ss.batch_id=p_batch_id and (
    ss.cefr_level not in ('A1','A2','B1','B2','C1','C2') or nullif(trim(ss.stimulus_code),'') is null or nullif(trim(ss.stimulus_type),'') is null or
    nullif(trim(ss.body_text),'') is null or nullif(trim(ss.provenance_code),'') is null or ss.approval_status not in ('PENDING','APPROVED','REJECTED') or
    ss.source_state not in ('SOURCE_EXACT','SOURCE_EXACT_METADATA_NORMALIZED','QA_VERSION_RECONSTRUCTED','METADATA_REVIEW_REQUIRED')
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06SCR002','BLOCKER','OPTION_KEY requires >=2 distinct active options and exactly one correct option'
  from assessment_staging.phase06_items_import s
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and s.scoring_mode='OPTION_KEY' and not exists (
    select 1 from assessment_staging.phase06_item_options_import o where o.batch_id=p_batch_id and o.item_code=s.item_code and o.version_major=s.version_major and o.version_minor=s.version_minor
    group by o.item_code,o.version_major,o.version_minor
    having count(*) filter(where o.status='ACTIVE')>=2
       and count(*) filter(where o.status='ACTIVE' and o.is_correct)=1
       and count(distinct lower(regexp_replace(trim(o.option_text),E'\\s+',' ','g'))) filter(where o.status='ACTIVE')=count(*) filter(where o.status='ACTIVE')
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06SCR003','BLOCKER','EXACT_KEY/FINITE_KEYSET requires at least one active accepted answer'
  from assessment_staging.phase06_items_import s
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and s.scoring_mode in ('EXACT_KEY','FINITE_KEYSET') and not exists (
    select 1 from assessment_staging.phase06_accepted_answers_import a where a.batch_id=p_batch_id and a.item_code=s.item_code and a.version_major=s.version_major and a.version_minor=s.version_minor and a.status='ACTIVE'
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06SCR004','BLOCKER','BOOLEAN/MATCH/ORDER scoring requires a non-empty structured scoring key'
  from assessment_staging.phase06_items_import s
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and s.scoring_mode in ('BOOLEAN_KEY','MATCH_KEY','ORDER_KEY') and not exists (
    select 1 from assessment_staging.phase06_scoring_keys_import k where k.batch_id=p_batch_id and k.item_code=s.item_code and k.version_major=s.version_major and k.version_minor=s.version_minor
      and ((s.scoring_mode='BOOLEAN_KEY' and jsonb_typeof(k.key_payload)='boolean') or (s.scoring_mode in ('MATCH_KEY','ORDER_KEY') and jsonb_typeof(k.key_payload) in ('array','object') and k.key_payload not in ('[]'::jsonb,'{}'::jsonb)))
  );

  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06LO001','BLOCKER','More than one PRIMARY LO mapping in staging'
  from assessment_staging.phase06_items_import s
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and 1 < (
    select count(*) from assessment_staging.phase06_item_lo_mappings_import m where m.batch_id=p_batch_id and m.item_code=s.item_code and m.version_major=s.version_major and m.version_minor=s.version_minor and m.mapping_role='PRIMARY'
  );
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,s.row_number,s.item_code,'P06LO002','WARNING','No PRIMARY LO supplied; item may import as DRAFT but cannot become Pilot-ready'
  from assessment_staging.phase06_items_import s
  where s.batch_id=p_batch_id and s.hydration_tier<>'IDENTITY_ONLY' and 0 = (
    select count(*) from assessment_staging.phase06_item_lo_mappings_import m where m.batch_id=p_batch_id and m.item_code=s.item_code and m.version_major=s.version_major and m.version_minor=s.version_minor and m.mapping_role='PRIMARY'
  );
  insert into assessment.phase06_item_import_findings(batch_id,row_number,item_code,rule_code,severity,message)
  select p_batch_id,m.row_number,m.item_code,'P06LO003','BLOCKER','LO mapping references a missing/non-authoritative or wrong Level/Skill LO'
  from assessment_staging.phase06_item_lo_mappings_import m
  join assessment_staging.phase06_items_import s on s.batch_id=m.batch_id and s.item_code=m.item_code and s.version_major=m.version_major and s.version_minor=m.version_minor
  left join assessment.learning_outcomes lo on lo.lo_code=m.lo_code and lo.registry_status='AUTHORITATIVE' and lo.approval_status='APPROVED' and lo.skill_code=s.skill_code and lo.cefr_level=s.cefr_level
  where m.batch_id=p_batch_id and lo.id is null;

  select count(*) filter(where severity='BLOCKER' and status='OPEN'),count(*) filter(where severity='WARNING' and status='OPEN') into v_block,v_warn
  from assessment.phase06_item_import_findings where batch_id=p_batch_id;
  update assessment.phase06_item_import_batches
  set actual_item_rows=(select count(*) from assessment_staging.phase06_items_import where batch_id=p_batch_id),
      blocker_count=v_block,warning_count=v_warn,validation_status=case when v_block=0 then 'PASS' else 'FAIL' end,validated_at=now()
  where id=p_batch_id;
  update assessment_staging.phase06_items_import set row_status=case when exists(
    select 1 from assessment.phase06_item_import_findings f where f.batch_id=p_batch_id and f.item_code=phase06_items_import.item_code and f.severity='BLOCKER' and f.status='OPEN'
  ) then 'FAIL' else 'PASS' end where batch_id=p_batch_id;
  return query select case when v_block=0 then 'PASS' else 'FAIL' end,v_block,v_warn;
end $function$;
