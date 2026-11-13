-- Allow a learner's ID to be pseudonymized in the audit log on verified guardian deletion.
-- The signed decision metadata remains, but the deleted learner ID is detached.
alter table fr_edu.registration_decisions
 drop constraint if exists registration_decisions_check;
alter table fr_edu.registration_decisions
 add constraint registration_decisions_target_check
 check ((target_type='account' and account_user_id is not null) or target_type='learner');
