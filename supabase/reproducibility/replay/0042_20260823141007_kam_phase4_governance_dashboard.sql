create or replace view public.kids_governance_dashboard
with (security_invoker=true) as
with mission_checks as (
  select
    m.id,
    m.code,
    (select count(*) from public.kids_script_pages sp where sp.mission_id=m.id) as script_pages,
    (select count(*) from public.kids_artwork_pages ap where ap.mission_id=m.id) as artwork_pages,
    (m.big_question is not null and btrim(m.big_question)<>'') as has_big_question,
    (m.learning_goal is not null and btrim(m.learning_goal)<>'') as has_learning_goal,
    (m.next_mission_code is not null and btrim(m.next_mission_code)<>'') as has_next_hook
  from public.kids_missions m
), season_checks as (
  select s.id, s.code, count(m.id) as mission_count
  from public.kids_seasons s
  left join public.kids_missions m on m.season_id=s.id
  group by s.id,s.code
), level_checks as (
  select l.id,l.code,count(s.id) as season_count
  from public.kids_levels l
  left join public.kids_seasons s on s.level_id=l.id
  group by l.id,l.code
)
select
  (select count(*) from public.kids_characters) as characters,
  (select count(*) from public.kids_character_appearance_control) as appearance_rules,
  (select count(*) from public.kids_character_integration) as character_integrations,
  (select count(*) from public.kids_governance_rules) as governance_rules,
  (select count(*) from public.kids_content_rulebook) as content_rules,
  (select count(*) from public.kids_aviation_accuracy_master) as aviation_accuracy_terms,
  (select count(*) from public.kids_universe_timeline) as timeline_links,
  (select count(*) from public.kids_ip_master) as ip_assets,
  (select count(*) from public.kids_localization_master) as localization_terms,
  (select count(*) from mission_checks) as missions_total,
  (select count(*) from mission_checks where script_pages=10) as missions_script_10,
  (select count(*) from mission_checks where artwork_pages=10) as missions_artwork_10,
  (select count(*) from mission_checks where has_big_question) as missions_with_big_question,
  (select count(*) from mission_checks where has_learning_goal) as missions_with_learning_goal,
  (select count(*) from mission_checks where has_next_hook) as missions_with_next_hook,
  (select count(*) from season_checks) as seasons_total,
  (select count(*) from season_checks where mission_count=12) as seasons_with_12_missions,
  (select count(*) from level_checks) as levels_total,
  (select count(*) from level_checks where season_count=10) as levels_with_10_seasons;
