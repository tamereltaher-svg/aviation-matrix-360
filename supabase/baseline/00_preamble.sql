-- Canonical Supabase baseline captured from production on 2026-09-03.
-- Sanitized: excludes production rows, users, sessions, credentials and temporary http extension.

create schema if not exists assessment;
create schema if not exists assessment_staging;

create extension if not exists pg_stat_statements with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists supabase_vault with schema vault;
create extension if not exists "uuid-ossp" with schema extensions;

create sequence public.am_application_number_seq as bigint increment by 1 minvalue 1 maxvalue 9223372036854775807 start with 1 no cycle;
create sequence public.am_batch_number_seq as bigint increment by 1 minvalue 1 maxvalue 9223372036854775807 start with 1 no cycle;
create sequence public.am_candidate_number_seq as bigint increment by 1 minvalue 1 maxvalue 9223372036854775807 start with 1001 no cycle;
create sequence public.am_quotation_number_seq as bigint increment by 1 minvalue 1 maxvalue 9223372036854775807 start with 1 no cycle;
create sequence public.am_request_number_seq as bigint increment by 1 minvalue 1 maxvalue 9223372036854775807 start with 1 no cycle;
create sequence public.application_number_seq as bigint increment by 1 minvalue 1 maxvalue 9223372036854775807 start with 1 no cycle;
