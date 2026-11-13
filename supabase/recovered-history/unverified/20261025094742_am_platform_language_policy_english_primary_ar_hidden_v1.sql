
create table if not exists public.am_platform_language_settings (
  surface text primary key check (surface in ('student')),
  default_locale text not null default 'en' check (default_locale in ('en','ar')),
  supported_locales text[] not null default array['en','ar']::text[],
  visible_locales text[] not null default array['en']::text[],
  language_switcher_enabled boolean not null default false,
  arabic_translations_retained boolean not null default true,
  presentation_direction text not null default 'ltr' check (presentation_direction in ('ltr','rtl')),
  reason text not null,
  updated_at timestamptz not null default now(),
  check(supported_locales @> array['en','ar']::text[]),
  check(visible_locales <@ supported_locales),
  check(default_locale=any(visible_locales)),
  check(visible_locales<>array[]::text[])
);
comment on table public.am_platform_language_settings is 'Student UI release policy: EN is the only visible locale for now, AR translations retained in original source fields. To expose AR later requires reviewed RTL frontend and explicit change to visible_locales and switcher.';
alter table public.am_platform_language_settings enable row level security;
revoke all on public.am_platform_language_settings from public,anon,authenticated;
grant select on public.am_platform_language_settings to anon,authenticated,service_role;
grant insert,update,delete on public.am_platform_language_settings to service_role;
create policy "Public student language presentation policy"
on public.am_platform_language_settings for select to anon,authenticated
using (surface='student');
insert into public.am_platform_language_settings (
 surface,default_locale,supported_locales,visible_locales,language_switcher_enabled,
 arabic_translations_retained,presentation_direction,reason
) values (
 'student','en',array['en','ar'],array['en'],false,true,'ltr',
 'Approved 2026-10-25: preserve bilingual content internally; English is primary and only publicly visible; hide Arabic and locale switcher until further instruction.'
) on conflict(surface) do update set
 default_locale=excluded.default_locale,
 supported_locales=excluded.supported_locales,
 visible_locales=excluded.visible_locales,
 language_switcher_enabled=excluded.language_switcher_enabled,
 arabic_translations_retained=excluded.arabic_translations_retained,
 presentation_direction=excluded.presentation_direction,
 reason=excluded.reason,updated_at=now();
