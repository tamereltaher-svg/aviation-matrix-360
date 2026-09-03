create or replace function assessment.item_version_scoring_valid(p_item_version_id uuid)
returns boolean
language plpgsql
stable
set search_path=''
as $function$
declare
  v_item_type text;
  v_mode text;
  v_objective boolean;
  v_human boolean;
  v_partial boolean;
  v_score numeric;
  v_option_count integer;
  v_correct_count integer;
  v_distinct_option_count integer;
  v_answer_count integer;
  v_key jsonb;
begin
  select iv.item_type_code, iv.scoring_mode, iv.objective_eligible,
         iv.human_judgment_required, iv.partial_credit_allowed, iv.max_raw_score
    into v_item_type, v_mode, v_objective, v_human, v_partial, v_score
  from assessment.item_versions iv
  where iv.id = p_item_version_id;

  if v_item_type is null or v_score is null or v_score <= 0 then return false; end if;

  if v_mode = 'ANALYTIC_RUBRIC' then
    if v_item_type not in ('ER-WRT','OR-SPK') then return false; end if;
    if v_objective or not v_human or not v_partial then return false; end if;
    if exists(select 1 from assessment.item_options io where io.item_version_id=p_item_version_id) then return false; end if;
    if exists(select 1 from assessment.accepted_answers aa where aa.item_version_id=p_item_version_id) then return false; end if;
    if exists(select 1 from assessment.item_scoring_keys sk where sk.item_version_id=p_item_version_id) then return false; end if;
    return true;
  end if;

  if not v_objective or v_human or v_partial or v_score <> 1 then return false; end if;

  if v_item_type = 'SR-MCQ' and v_mode <> 'OPTION_KEY' then return false; end if;
  if v_item_type = 'SR-TF' and v_mode not in ('BOOLEAN_KEY','OPTION_KEY') then return false; end if;
  if v_item_type = 'SR-MATCH' and v_mode <> 'MATCH_KEY' then return false; end if;
  if v_item_type = 'SR-SEQ' and v_mode <> 'ORDER_KEY' then return false; end if;
  if v_item_type in ('CR-GAP','CR-SA','CR-EDIT') and v_mode not in ('EXACT_KEY','FINITE_KEYSET') then return false; end if;

  if v_mode = 'OPTION_KEY' then
    select count(*),
           count(*) filter (where io.is_correct),
           count(distinct lower(regexp_replace(trim(io.option_text), '[[:space:]]+', ' ', 'g')))
      into v_option_count, v_correct_count, v_distinct_option_count
    from assessment.item_options io
    where io.item_version_id = p_item_version_id and io.status = 'ACTIVE';

    if v_option_count < 2 or v_correct_count <> 1 or v_distinct_option_count <> v_option_count then return false; end if;
  elsif v_mode in ('EXACT_KEY','FINITE_KEYSET') then
    select count(*) into v_answer_count
    from assessment.accepted_answers aa
    where aa.item_version_id = p_item_version_id and aa.status = 'ACTIVE';
    if v_answer_count < 1 then return false; end if;
  elsif v_mode in ('BOOLEAN_KEY','MATCH_KEY','ORDER_KEY') then
    select sk.key_payload into v_key
    from assessment.item_scoring_keys sk
    where sk.item_version_id = p_item_version_id;
    if v_key is null then return false; end if;
    if v_mode = 'BOOLEAN_KEY' and jsonb_typeof(v_key) <> 'boolean' then return false; end if;
    if v_mode in ('MATCH_KEY','ORDER_KEY') and (jsonb_typeof(v_key) not in ('array','object') or v_key in ('[]'::jsonb,'{}'::jsonb)) then return false; end if;
  else
    return false;
  end if;

  return true;
end $function$;

create or replace function assessment.assert_item_version_scoring_integrity(p_item_version_id uuid)
returns void
language plpgsql
stable
set search_path=''
as $function$
begin
  if not assessment.item_version_scoring_valid(p_item_version_id) then
    raise exception 'Item version % does not satisfy governed scoring integrity', p_item_version_id using errcode='23514';
  end if;
end $function$;
