
create function avi_knowledge.add_new_role_axis_cells()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
begin
 insert into avi_knowledge.role_axis_coverage(role_id,axis_code)
 select p.id,new.code from avi_knowledge.role_profiles p on conflict do nothing;
 return new;
end $$;
revoke all on function avi_knowledge.add_new_role_axis_cells() from public,anon,authenticated;
create trigger trg_new_role_axis_cells after insert on avi_knowledge.role_axes
for each row execute function avi_knowledge.add_new_role_axis_cells();

create function avi_knowledge.add_new_role_profile_cells()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
begin
 insert into avi_knowledge.role_axis_coverage(role_id,axis_code)
 select new.id,a.code from avi_knowledge.role_axes a on conflict do nothing;
 return new;
end $$;
revoke all on function avi_knowledge.add_new_role_profile_cells() from public,anon,authenticated;
create trigger trg_new_role_profile_cells after insert on avi_knowledge.role_profiles
for each row execute function avi_knowledge.add_new_role_profile_cells();

create function avi_knowledge.sync_role_axis_evidence()
returns trigger language plpgsql security invoker set search_path=pg_catalog,avi_knowledge as $$
declare rid uuid; ax text;
begin
  if tg_op='DELETE' then rid:=old.role_id;ax:=old.axis_code;
  else rid:=new.role_id;ax:=new.axis_code;end if;
  insert into avi_knowledge.role_axis_coverage(role_id,axis_code,coverage_status,scope_note,scope_reviewed_at)
  values(rid,ax,
     case when exists(select 1 from avi_knowledge.role_axis_evidence e where e.role_id=rid and e.axis_code=ax and e.review_status in ('source_checked','expert_approved'))
          then 'source_checked' else 'research_gap' end,
     'Auto-derived from linked evidence; independent subject expert review remains necessary',now())
  on conflict(role_id,axis_code) do update set
    coverage_status=case
       when exists(select 1 from avi_knowledge.role_axis_evidence e where e.role_id=rid and e.axis_code=ax and e.review_status in ('source_checked','expert_approved'))
       then case when avi_knowledge.role_axis_coverage.coverage_status='expert_approved' then 'expert_approved' else 'source_checked' end
       else 'research_gap' end,
    scope_note='Auto-synchronized with source-backed evidence; independent review remains necessary',
    scope_reviewed_at=now();
  if tg_op='UPDATE' and (old.role_id<>new.role_id or old.axis_code<>new.axis_code) then
    rid:=old.role_id;ax:=old.axis_code;
    update avi_knowledge.role_axis_coverage set coverage_status=case
      when exists(select 1 from avi_knowledge.role_axis_evidence e where e.role_id=rid and e.axis_code=ax and e.review_status in ('source_checked','expert_approved'))
      then 'source_checked' else 'research_gap' end,
      scope_reviewed_at=now()
    where role_id=rid and axis_code=ax;
  end if;
  if tg_op='DELETE' then return old; end if;return new;
end $$;
revoke all on function avi_knowledge.sync_role_axis_evidence() from public,anon,authenticated;
create trigger trg_sync_role_axis_evidence
after insert or update or delete on avi_knowledge.role_axis_evidence
for each row execute function avi_knowledge.sync_role_axis_evidence();
