with skill_values as (
  select ARRAY['Decision Making','Problem Solving','Map Reading','Safety Awareness','Sequencing','Comparison','Observation','Communication']::text[] skills,
         ARRAY['Respect','Teamwork','Safety','Confidence','Global Awareness','Patience','Curiosity','Responsibility']::text[] vals
), src as (
  select m.id as mission_id,m.code,m.stamp_name,m.next_mission_code,
         split_part(m.code,'-',1) level_code,
         substring(split_part(m.code,'-',2) from 2)::int season_no,
         substring(split_part(m.code,'-',3) from 2)::int mission_no,
         b.title as base_title
  from public.kids_missions m
  join public.kids_missions b on b.code=regexp_replace(m.code,'^L[1-5]-','L1-')
), prepared as (
  select s.*,
    regexp_split_to_array(
      trim(regexp_replace(regexp_replace(replace(s.base_title,'-',''),'[0-9]+','','g'),'[^A-Za-z]+',' ','g')),
      '\s+'
    )::text[] as concepts,
    ((s.season_no+s.mission_no-2)%8)+1 as skill_ix,
    (((substring(s.level_code from 2))::int+s.mission_no-2)%8)+1 as value_ix
  from src s
)
insert into public.kids_mission_blueprints(mission_id,key_concepts,vocabulary,primary_skill,primary_value,aviation_connection,stamp_name,next_mission_code,status)
select p.mission_id,p.concepts,p.concepts,sv.skills[p.skill_ix],sv.vals[p.value_ix],
       'Airport / Aircraft / Flight / People / Travel',p.stamp_name,p.next_mission_code,'Not Started'
from prepared p cross join skill_values sv
on conflict (mission_id) do update set
 key_concepts=excluded.key_concepts,vocabulary=excluded.vocabulary,primary_skill=excluded.primary_skill,
 primary_value=excluded.primary_value,aviation_connection=excluded.aviation_connection,stamp_name=excluded.stamp_name,
 next_mission_code=excluded.next_mission_code,status=excluded.status,updated_at=now();
