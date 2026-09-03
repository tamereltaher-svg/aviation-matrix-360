with constants as (
  select ARRAY['Observation','Communication','Problem Solving']::text[] skills,
         ARRAY['Curiosity','Responsibility','Teamwork','Safety']::text[] vals
), src as (
  select m.id as mission_id,
         substring(split_part(m.code,'-',2) from 2)::int season_no,
         substring(split_part(m.code,'-',3) from 2)::int mission_no
  from public.kids_missions m
), prepared as (
  select s.*,
    case s.season_no
      when 1 then 'preparing to travel'
      when 2 then 'welcome to the airport'
      when 3 then 'getting ready to fly'
      when 4 then 'meet the aviation team'
      when 5 then 'inside the aircraft'
      when 6 then 'my first flight'
      when 7 then 'around the world'
      when 8 then 'amazing places'
      when 9 then 'weather and travel'
      when 10 then 'aviation explorer graduation'
    end as theme
  from src s
)
insert into public.kids_learning_matrix(mission_id,knowledge_goal,primary_skill,primary_value,vocabulary_set,aviation_link,difficulty,status,review_notes)
select p.mission_id,
       'Understand ' || p.theme || ' concept ' || p.mission_no,
       c.skills[((p.mission_no-1)%3)+1],
       c.vals[((p.mission_no-1)%4)+1],
       '5 words max','Airport / Travel / Flight','Age Appropriate','Planned',''
from prepared p cross join constants c
on conflict (mission_id) do update set
 knowledge_goal=excluded.knowledge_goal,primary_skill=excluded.primary_skill,primary_value=excluded.primary_value,
 vocabulary_set=excluded.vocabulary_set,aviation_link=excluded.aviation_link,difficulty=excluded.difficulty,
 status=excluded.status,review_notes=excluded.review_notes,updated_at=now();
