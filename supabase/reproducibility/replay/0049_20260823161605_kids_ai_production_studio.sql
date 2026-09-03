create table if not exists public.kids_ai_projects (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  title text,
  brief text,
  selected_character_codes text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','generated','review','approved','published','archived')),
  ai_payload jsonb not null default '{}'::jsonb,
  created_by uuid null references public.staff_accounts(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kids_ai_generations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid null references public.kids_ai_projects(id) on delete cascade,
  mission_id uuid not null references public.kids_missions(id) on delete cascade,
  page_no integer null check (page_no is null or (page_no between 1 and 20)),
  generation_type text not null check (generation_type in ('mission_draft','story_page','scene_prompt','image','revision')),
  model_name text,
  prompt text,
  response_payload jsonb not null default '{}'::jsonb,
  storage_bucket text,
  storage_path text,
  status text not null default 'generated' check (status in ('generated','review','approved','rejected','applied')),
  created_by uuid null references public.staff_accounts(user_id),
  created_at timestamptz not null default now(),
  approved_at timestamptz null
);

create index if not exists kids_ai_projects_mission_idx on public.kids_ai_projects(mission_id, created_at desc);
create index if not exists kids_ai_generations_mission_idx on public.kids_ai_generations(mission_id, page_no, created_at desc);

alter table public.kids_ai_projects enable row level security;
alter table public.kids_ai_generations enable row level security;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('kids-ai-studio','kids-ai-studio',false,20971520,array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

create or replace function public.kids_apply_ai_mission_draft(p_mission_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p jsonb;
  i int;
  sp jsonb;
  ap jsonb;
begin
  p := coalesce(p_payload,'{}'::jsonb);

  update public.kids_missions
     set title = coalesce(nullif(p->>'title',''),title),
         big_question = coalesce(nullif(p->>'big_question',''),big_question),
         learning_goal = coalesce(nullif(p->>'learning_goal',''),learning_goal),
         stamp_name = coalesce(nullif(p->>'stamp_name',''),stamp_name),
         learning_objectives = case when jsonb_typeof(p->'learning_objectives')='array' then array(select jsonb_array_elements_text(p->'learning_objectives')) else learning_objectives end,
         production_status = 'AI Draft Applied',
         updated_at = now()
   where id = p_mission_id;

  update public.kids_mission_blueprints
     set key_concepts = case when jsonb_typeof(p->'key_concepts')='array' then array(select jsonb_array_elements_text(p->'key_concepts')) else key_concepts end,
         vocabulary = case when jsonb_typeof(p->'vocabulary')='array' then array(select jsonb_array_elements_text(p->'vocabulary')) else vocabulary end,
         primary_skill = coalesce(nullif(p->>'primary_skill',''),primary_skill),
         primary_value = coalesce(nullif(p->>'primary_value',''),primary_value),
         aviation_connection = coalesce(nullif(p->>'aviation_connection',''),aviation_connection),
         stamp_name = coalesce(nullif(p->>'stamp_name',''),stamp_name),
         status = 'AI Draft Applied',
         updated_at = now()
   where mission_id = p_mission_id;

  update public.kids_learning_matrix
     set knowledge_goal = coalesce(nullif(p->>'knowledge_goal',''),knowledge_goal),
         primary_skill = coalesce(nullif(p->>'primary_skill',''),primary_skill),
         primary_value = coalesce(nullif(p->>'primary_value',''),primary_value),
         vocabulary_set = case when jsonb_typeof(p->'vocabulary')='array' then array_to_string(array(select jsonb_array_elements_text(p->'vocabulary')), ', ') else vocabulary_set end,
         aviation_link = coalesce(nullif(p->>'aviation_connection',''),aviation_link),
         difficulty = coalesce(nullif(p->>'difficulty',''),difficulty),
         status = 'AI Draft Applied',
         updated_at = now()
   where mission_id = p_mission_id;

  if jsonb_typeof(p->'pages')='array' then
    for i in 0..jsonb_array_length(p->'pages')-1 loop
      sp := p->'pages'->i;
      update public.kids_script_pages
         set scene_title = coalesce(nullif(sp->>'scene_title',''),scene_title),
             narration = coalesce(nullif(sp->>'narration',''),narration),
             dialogue = coalesce(nullif(sp->>'dialogue',''),dialogue),
             learning_purpose = coalesce(nullif(sp->>'learning_purpose',''),learning_purpose),
             character_codes = case when jsonb_typeof(sp->'character_codes')='array' then array(select jsonb_array_elements_text(sp->'character_codes')) else character_codes end,
             production_notes = coalesce(nullif(sp->>'production_notes',''),production_notes),
             status = 'ai_draft',
             updated_at = now()
       where mission_id = p_mission_id and page_no = coalesce((sp->>'page_no')::int,i+1);

      ap := sp->'artwork';
      if ap is not null then
        update public.kids_artwork_pages
           set scene_brief = coalesce(nullif(ap->>'scene_brief',''),scene_brief),
               background_brief = coalesce(nullif(ap->>'background_brief',''),background_brief),
               asset_requirements = coalesce(nullif(ap->>'asset_requirements',''),asset_requirements),
               text_safe_area = coalesce(nullif(ap->>'text_safe_area',''),text_safe_area),
               illustration_notes = coalesce(nullif(ap->>'illustration_notes',''),illustration_notes),
               status = 'ai_draft',
               updated_at = now()
         where mission_id = p_mission_id and page_no = coalesce((sp->>'page_no')::int,i+1);
      end if;
    end loop;
  end if;

  update public.kids_content_tracker
     set blueprint_status='AI Draft', script_status='AI Draft', artwork_status='AI Draft', overall_status='In Production', updated_at=now()
   where mission_id=p_mission_id;

  return jsonb_build_object('ok',true,'mission_id',p_mission_id);
end;
$$;

revoke all on function public.kids_apply_ai_mission_draft(uuid,jsonb) from public, anon, authenticated;
grant execute on function public.kids_apply_ai_mission_draft(uuid,jsonb) to service_role;
