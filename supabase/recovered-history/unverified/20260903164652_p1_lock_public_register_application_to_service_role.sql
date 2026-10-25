revoke execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) from public;
revoke execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) from anon;
revoke execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) from authenticated;
grant execute on function public.public_register_application(text,text,text,date,text,text,text,text,boolean) to service_role;