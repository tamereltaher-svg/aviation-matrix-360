with targets as (
  select * from (values
    ('L3','How ',' Works','How does this work in aviation?','Explain the basic process behind: '),
    ('L4','Professional Decision: ','','What decision would an aviation professional make?','Apply safety and operational thinking to: '),
    ('L5','Career Path: ','','Which aviation career uses this knowledge?','')
  ) as t(level_code,title_prefix,title_suffix,big_question,goal_prefix)
), base as (
  select m.*, split_part(m.code,'-',2) season_no, split_part(m.code,'-',3) mission_no_code
  from public.kids_missions m
  where m.code like 'L1-S%-M%'
), generated as (
  select
    t.level_code,
    t.level_code || '-' || b.season_no || '-' || b.mission_no_code as code,
    t.level_code || '-' || b.season_no as season_code,
    b.mission_no,
    case when t.level_code='L3' then t.title_prefix || b.title || t.title_suffix
         else t.title_prefix || b.title end as title,
    t.big_question as big_question,
    case when t.level_code='L5' then 'Connect this topic to career skills and aviation pathways.'
         else t.goal_prefix || lower(left(b.learning_goal,1)) || substr(b.learning_goal,2) end as learning_goal,
    b.stamp_name,
    case
      when b.code='L1-S10-M12' and t.level_code='L3' then 'L4-S1-M1'
      when b.code='L1-S10-M12' and t.level_code='L4' then 'L5-S1-M1'
      when b.code='L1-S10-M12' and t.level_code='L5' then 'PROGRAM-COMPLETE'
      else regexp_replace(b.next_mission_code,'^L1-',t.level_code || '-')
    end as next_mission_code,
    b.production_status,
    b.sort_order
  from base b cross join targets t
)
insert into public.kids_missions(season_id,code,mission_no,name,title,description,big_question,learning_goal,learning_objectives,stamp_name,next_mission_code,production_status,sort_order,is_active)
select s.id,g.code,g.mission_no,g.title,g.title,g.learning_goal,g.big_question,g.learning_goal,ARRAY[g.learning_goal]::text[],g.stamp_name,g.next_mission_code,g.production_status,g.sort_order,true
from generated g join public.kids_seasons s on s.code=g.season_code
on conflict (code) do update set
 season_id=excluded.season_id, mission_no=excluded.mission_no, name=excluded.name, title=excluded.title,
 description=excluded.description,big_question=excluded.big_question,learning_goal=excluded.learning_goal,
 learning_objectives=excluded.learning_objectives,stamp_name=excluded.stamp_name,next_mission_code=excluded.next_mission_code,
 production_status=excluded.production_status,sort_order=excluded.sort_order,is_active=true,updated_at=now();
