alter table public.kids_ai_generations drop constraint if exists kids_ai_generations_status_check;
alter table public.kids_ai_generations add constraint kids_ai_generations_status_check check (status = any (array['generated'::text,'review'::text,'approved'::text,'rejected'::text,'applied'::text,'identity_rejected'::text]));
