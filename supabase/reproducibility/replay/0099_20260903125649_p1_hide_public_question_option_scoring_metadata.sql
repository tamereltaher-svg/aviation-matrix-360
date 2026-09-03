revoke select on table public.question_options from anon, authenticated;
grant select (id, question_id, option_code, option_text, sequence_no) on table public.question_options to anon, authenticated;

-- Preserve full server-side access explicitly.
grant select on table public.question_options to service_role;
