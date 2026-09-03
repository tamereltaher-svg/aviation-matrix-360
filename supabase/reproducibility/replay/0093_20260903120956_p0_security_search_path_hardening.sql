ALTER FUNCTION public.normalize_public_mobile(text) SET search_path = pg_catalog, extensions, public;
ALTER FUNCTION public.set_store_updated_at() SET search_path = pg_catalog, public;
ALTER FUNCTION public.kids_touch_updated_at() SET search_path = pg_catalog, public;
ALTER FUNCTION public.kids_get_brand_logo_bundle(text) SET search_path = pg_catalog, public;
ALTER FUNCTION public.am_lifetime_integrity_hash(uuid,uuid,text,jsonb,timestamp with time zone) SET search_path = pg_catalog, extensions, public;
ALTER FUNCTION public.am_block_lifetime_history_mutation() SET search_path = pg_catalog, public;
ALTER FUNCTION public.am_block_registration_event_mutation() SET search_path = pg_catalog, public;
