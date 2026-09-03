insert into public.staff_permissions (user_id, permission_code, is_allowed)
select sp.user_id, p.permission_code, true
from public.staff_permissions sp
cross join (values
  ('programs.manage'::text),
  ('quotations.manage'::text),
  ('institutions.manage'::text),
  ('meetings.manage'::text)
) as p(permission_code)
where sp.permission_code = 'store.manage'
  and sp.is_allowed = true
on conflict (user_id, permission_code)
do update set is_allowed = excluded.is_allowed;
