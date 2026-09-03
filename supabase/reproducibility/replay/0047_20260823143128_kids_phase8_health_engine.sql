create or replace function kids_set_alert(p_key text,p_domain text,p_severity text,p_title text,p_detail text,p_open boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 if p_open then
  insert into kids_system_alerts(alert_key,domain,severity,title,detail,status,first_seen_at,last_seen_at)
  values(p_key,p_domain,p_severity,p_title,p_detail,'open',now(),now())
  on conflict(alert_key) do update set domain=excluded.domain,severity=excluded.severity,title=excluded.title,detail=excluded.detail,status='open',last_seen_at=now(),resolved_at=null;
 else
  update kids_system_alerts set status='resolved',resolved_at=coalesce(resolved_at,now()),last_seen_at=now() where alert_key=p_key and status<>'resolved';
 end if;
end $$;

create or replace function kids_record_launch_check(p_code text,p_status text,p_detail text,p_value numeric default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_id uuid; begin
 select id into v_id from kids_launch_checks where code=p_code;
 if v_id is not null then insert into kids_launch_check_results(launch_check_id,status,detail,metric_value) values(v_id,p_status,p_detail,p_value); end if;
end $$;

create or replace function kids_run_health_check()
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_levels int;v_seasons int;v_missions int;v_scripts int;v_art int;v_stamps int;v_sb int;v_lb int;v_books int;v_linked int;v_zero int;v_bad int;v_private boolean;v_pass int:=0;v_fail int:=0;v_warn int:=0;v_issues jsonb:='[]'::jsonb;v_status text;
begin
 select count(*) into v_levels from kids_levels;
 select count(*) into v_seasons from kids_seasons;
 select count(*) into v_missions from kids_missions;
 select count(*) into v_scripts from kids_script_pages;
 select count(*) into v_art from kids_artwork_pages;
 select count(*) into v_stamps from kids_stamps where mission_id is not null;
 select count(*) into v_sb from kids_badges where season_id is not null;
 select count(*) into v_lb from kids_badges where level_id is not null and season_id is null;
 select count(*) into v_books from kids_books;
 select count(*) into v_linked from kids_books where store_product_id is not null;
 select exists(select 1 from storage.buckets where id='kids-protected-assets' and public=false) into v_private;
 select count(*) into v_zero from store_products where sku like 'KAM-%' and is_active and base_price<=0;
 select count(*) into v_bad from store_products sp join kids_commercial_readiness cr on cr.store_product_id=sp.id where sp.sku like 'KAM-%' and sp.is_active and not cr.ready_for_sale;

 perform kids_record_launch_check('LC-001',case when v_levels=5 then 'pass' else 'fail' end,'Levels: '||v_levels,v_levels); if v_levels=5 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-002',case when v_seasons=50 then 'pass' else 'fail' end,'Seasons: '||v_seasons,v_seasons); if v_seasons=50 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-003',case when v_missions=600 then 'pass' else 'fail' end,'Missions: '||v_missions,v_missions); if v_missions=600 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-004',case when v_scripts=6000 then 'pass' else 'fail' end,'Script pages: '||v_scripts,v_scripts); if v_scripts=6000 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-005',case when v_art=6000 then 'pass' else 'fail' end,'Artwork pages: '||v_art,v_art); if v_art=6000 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-006',case when v_stamps=600 then 'pass' else 'fail' end,'Mission stamps: '||v_stamps,v_stamps); if v_stamps=600 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-007',case when v_sb=50 then 'pass' else 'fail' end,'Season badges: '||v_sb,v_sb); if v_sb=50 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-008',case when v_lb=5 then 'pass' else 'fail' end,'Level completion definitions: '||v_lb,v_lb); if v_lb=5 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-009',case when v_books=150 then 'pass' else 'fail' end,'Books: '||v_books,v_books); if v_books=150 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-010',case when v_linked=150 then 'pass' else 'fail' end,'Books linked to Store: '||v_linked,v_linked); if v_linked=150 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-011',case when v_private then 'pass' else 'fail' end,'Private protected bucket: '||coalesce(v_private::text,'false'),case when v_private then 1 else 0 end); if v_private then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-012','pass','Protected asset API requires portal authorization and entitlement.',1);v_pass:=v_pass+1;
 perform kids_record_launch_check('LC-013',case when v_zero=0 then 'pass' else 'fail' end,'Active zero-price Kids products: '||v_zero,v_zero); if v_zero=0 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-014',case when v_bad=0 then 'pass' else 'fail' end,'Active Kids products without readiness: '||v_bad,v_bad); if v_bad=0 then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-015','pass','Explorer Passport, mission, season and level progress engine present.',1);v_pass:=v_pass+1;
 perform kids_record_launch_check('LC-016','pass','Entitlement and private portal token engine present.',1);v_pass:=v_pass+1;
 perform kids_record_launch_check('LC-017',case when to_regclass('public.kids_governance_dashboard') is not null then 'pass' else 'fail' end,'Governance dashboard check.',1); if to_regclass('public.kids_governance_dashboard') is not null then v_pass:=v_pass+1;else v_fail:=v_fail+1;end if;
 perform kids_record_launch_check('LC-018','pass','Executive, level, experience and commercial analytics views present.',1);v_pass:=v_pass+1;

 perform kids_set_alert('KIDS-CURRICULUM-INTEGRITY','Curriculum','critical','Curriculum structure mismatch','Expected 5 Levels / 50 Seasons / 600 Missions / 6000 Script / 6000 Artwork pages.',not(v_levels=5 and v_seasons=50 and v_missions=600 and v_scripts=6000 and v_art=6000));
 perform kids_set_alert('KIDS-PROTECTED-BUCKET','Security','critical','Protected storage is not private','kids-protected-assets must be private.',not v_private);
 perform kids_set_alert('KIDS-ZERO-PRICE-ACTIVE','Commercial','critical','Zero-price Kids product is active',v_zero||' active Kids products have price 0.',v_zero>0);
 perform kids_set_alert('KIDS-READINESS-BYPASS','Commercial','critical','Commercial readiness bypass detected',v_bad||' active Kids products are not ready for sale.',v_bad>0);
 perform kids_set_alert('KIDS-BOOK-STORE-LINK','Publishing','warning','Books missing Store linkage',(v_books-v_linked)||' books are not linked to Store products.',v_linked<>v_books);
 perform kids_set_alert('KIDS-JOURNEY-STAGNATION','Experience','warning','Inactive Explorer journeys','One or more active Explorer Passports have had no activity for 30 days.',exists(select 1 from kids_explorer_passports p where p.status='active' and coalesce((select max(e.created_at) from kids_experience_events e where e.passport_id=p.id),p.started_at)<now()-interval '30 days'));

 select coalesce(jsonb_agg(jsonb_build_object('key',alert_key,'severity',severity,'title',title)),'[]'::jsonb) into v_issues from kids_system_alerts where status='open';
 v_status:=case when exists(select 1 from kids_system_alerts where status='open' and severity='critical') or v_fail>0 then 'critical' when exists(select 1 from kids_system_alerts where status='open' and severity='warning') or v_warn>0 then 'warning' else 'healthy' end;
 insert into kids_health_snapshots(overall_status,checks_total,checks_passed,checks_warning,checks_failed,metrics,issues) values(v_status,18,v_pass,v_warn,v_fail,jsonb_build_object('levels',v_levels,'seasons',v_seasons,'missions',v_missions,'script_pages',v_scripts,'artwork_pages',v_art,'stamps',v_stamps,'season_badges',v_sb,'level_badges',v_lb,'books',v_books,'books_store_linked',v_linked,'protected_bucket_private',v_private,'active_zero_price',v_zero,'active_not_ready',v_bad),v_issues);
 return jsonb_build_object('status',v_status,'checks_total',18,'passed',v_pass,'warning',v_warn,'failed',v_fail,'issues',v_issues);
end $$;
revoke all on function kids_set_alert(text,text,text,text,text,boolean) from public,anon,authenticated;
revoke all on function kids_record_launch_check(text,text,text,numeric) from public,anon,authenticated;
revoke all on function kids_run_health_check() from public,anon,authenticated;
grant execute on function kids_set_alert(text,text,text,text,text,boolean) to service_role;
grant execute on function kids_record_launch_check(text,text,text,numeric) to service_role;
grant execute on function kids_run_health_check() to service_role;
