-- Install Supabase Cron; schedule only one narrowly scoped French exam expiry job.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;
select cron.schedule('fr-edu-timeout-finalizer-v1','* * * * *',
 $job$select fr_edu.expire_due_attempts(100);$job$);
