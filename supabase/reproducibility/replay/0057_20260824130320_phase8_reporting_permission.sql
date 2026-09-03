insert into public.staff_permissions(user_id,permission_code,is_allowed)
select user_id,'platform.reporting',true from public.staff_permissions where permission_code='store.manage' and is_allowed=true
on conflict (user_id,permission_code) do update set is_allowed=true;
