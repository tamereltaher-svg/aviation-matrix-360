
alter table public.am_platform_language_settings
 drop constraint if exists am_platform_language_settings_surface_check;
alter table public.am_platform_language_settings
 add constraint am_platform_language_settings_surface_check
 check(surface in ('platform','student'));
insert into public.am_platform_language_settings (
 surface,default_locale,supported_locales,visible_locales,language_switcher_enabled,
 arabic_translations_retained,presentation_direction,reason
) values (
 'platform','en',array['en','ar']::text[],array['en']::text[],false,true,'ltr',
 'Platform-wide default: English only visible now; Arabic translation data retained and hidden pending a later release decision.'
) on conflict(surface) do update set
 default_locale=excluded.default_locale,
 supported_locales=excluded.supported_locales,
 visible_locales=excluded.visible_locales,
 language_switcher_enabled=excluded.language_switcher_enabled,
 arabic_translations_retained=excluded.arabic_translations_retained,
 presentation_direction=excluded.presentation_direction,
 reason=excluded.reason,updated_at=now();
