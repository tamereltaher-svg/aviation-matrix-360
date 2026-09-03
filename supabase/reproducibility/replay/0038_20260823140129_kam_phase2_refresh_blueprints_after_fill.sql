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
    regexp_split_to_array(trim(regexp_replace(regexp_replace(replace(s.base_title,'-',''),'[0-9]+','','g'),'[^A-Za-z]+',' ','g')),'\s+')::text[] as concepts,
    ((s.season_no+s.mission_no-2)%8)+1 as skill_ix,
    (((substring(s.level_code from 2))::int+s.mission_no-2)%8)+1 as value_ix
  from src s
)
insert into public.kids_mission_blueprints(mission_id,key_concepts,vocabulary,primary_skill,primary_value,aviation_connection,stamp_name,next_mission_code,status)
select p.mission_id,p.concepts,p.concepts,sv.skills[p.skill_ix],sv.vals[p.value_ix],'Airport / Aircraft / Flight / People / Travel',p.stamp_name,p.next_mission_code,'Not Started'
from prepared p cross join skill_values sv
on conflict (mission_id) do update set key_concepts=excluded.key_concepts,vocabulary=excluded.vocabulary,primary_skill=excluded.primary_skill,primary_value=excluded.primary_value,aviation_connection=excluded.aviation_connection,stamp_name=excluded.stamp_name,next_mission_code=excluded.next_mission_code,status=excluded.status,updated_at=now();

with constants as (
  select ARRAY['Observation','Communication','Problem Solving']::text[] skills,
         ARRAY['Curiosity','Responsibility','Teamwork','Safety']::text[] vals
), src as (
  select m.id as mission_id,substring(split_part(m.code,'-',2) from 2)::int season_no,substring(split_part(m.code,'-',3) from 2)::int mission_no from public.kids_missions m
), prepared as (
  select s.*,case s.season_no when 1 then 'preparing to travel' when 2 then 'welcome to the airport' when 3 then 'getting ready to fly' when 4 then 'meet the aviation team' when 5 then 'inside the aircraft' when 6 then 'my first flight' when 7 then 'around the world' when 8 then 'amazing places' when 9 then 'weather and travel' when 10 then 'aviation explorer graduation' end as theme from src s
)
insert into public.kids_learning_matrix(mission_id,knowledge_goal,primary_skill,primary_value,vocabulary_set,aviation_link,difficulty,status,review_notes)
select p.mission_id,'Understand ' || p.theme || ' concept ' || p.mission_no,c.skills[((p.mission_no-1)%3)+1],c.vals[((p.mission_no-1)%4)+1],'5 words max','Airport / Travel / Flight','Age Appropriate','Planned',''
from prepared p cross join constants c
on conflict (mission_id) do update set knowledge_goal=excluded.knowledge_goal,primary_skill=excluded.primary_skill,primary_value=excluded.primary_value,vocabulary_set=excluded.vocabulary_set,aviation_link=excluded.aviation_link,difficulty=excluded.difficulty,status=excluded.status,review_notes=excluded.review_notes,updated_at=now();
