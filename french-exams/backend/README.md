# French Learning & Assessment — Central Backend (v1)

**Status:** DATABASE CORE DEPLOYED / STUDENT APP INTEGRATION NOT YET ENABLED  
**Date:** 2026-11-13  
**Supabase project:** `AviationMatrix-Core` (`vsuekfzyebqnhthyvwpf`)  
**Dedicated schema:** `fr_edu` — isolated from the existing Aviation Matrix tables and entirely separate from Aviation-Catering.

## Scope implemented

The core includes **20 tables** organized by domain:

| Domain | Tables |
|---|---|
| Curriculum | `stages`, `grades`, `topics`, `grade_topics`, `units`, `unit_grades` |
| Content & answer keys | `lexemes`, `questions`, `question_options`, `question_keys` |
| Assessment | `assessments`, `assessment_pool`, `assessment_questions`, `assessment_grades`, `attempts`, `responses` |
| Student access & governance | `profiles`, `user_roles`, `guardian_consents`, `audit_events` |

**Seeded:** 4 stages, 14 grades (KG1, KG2; 1–6 primary; 1–3 preparatory; 1–3 secondary), 7 topic headings (6 active demo topics + grammar review), 76 vocabulary entries, 20 assessment definitions (18 single-topic modes, 1 general mixed, 1 grammar), 36 question-pool rules, 5 grammar prompts with options and protected answer keys.

**Not yet approved or populated:** grade-to-topic or grade-to-assessment mappings. A single question or assessment can be mapped to *multiple* grades when reviewed and approved.

The grammar question *« Hier, vous … les devoirs »* is retained as a question requiring human review. It has no automatic scoring key. Three attempts are enforced structurally per user and assessment by `attempt_number in (1,2,3)` plus a unique constraint on (`student_user_id`, `assessment_code`, `attempt_number`).

## Security model

- The `fr_edu` schema is not exposed by the project’s default public Data API.
- Explicit **REVOKE** for `anon` and `authenticated` on schema and tables.
- Row Level Security enabled on all 20 tables. No end-user policies intentionally: this is **deny by default** while authenticated API endpoints are not built.
- Backend service role is the only intended actor. Never place a secret/service-role key in GitHub Pages, a web page or a mobile app.
- Correct answers stay in server-only `question_keys` and `lexemes`.
- Teacher/admin authorization is represented by `user_roles`, not by editable `user_metadata`.
- Guardian consent has a dedicated table; privacy/guardian workflows remain **not implemented**. No students, guardians, or roles have been provisioned by this migration.

## Published demonstration remains separate

Website: https://tamereltaher-svg.github.io/aviation-matrix-360/  
The existing GitHub Pages exams still use browser-local state and manual WhatsApp result sharing. **They are NOT connected to Supabase**, so no claim of centralized cloud attempt enforcement or verified scoring should be made. Old local scores have not been imported, verified, or overwritten.

## What remains before activating cloud scoring

1. Verify content and assign grade mappings with qualified educators. Preserve the distinction between a vocabulary theme and a curriculum grade.
2. Review and correct grammar item 5 (and any ambiguous content) before publishing it as automatically gradable.
3. Implement authenticated, server-side endpoints for start attempt, question delivery, submit answers, scoring and teacher reports. Never expose answer keys.
4. Implement age-appropriate user identity, privacy notice, parental/guardian consent where required, role assignment, and retention policy.
5. End-to-end QA: simultaneous attempt creation, device switching, restarts, duplicate submissions, spoofed IDs, tampered answers, 3-attempt ceiling, and accurate review-needed states.
6. Activate client integration only after a gated test; keep the existing public demo available throughout.

## Database reproducibility

- `fr_edu_isolated_core_initial.sql` — isolated schema, RLS, 76-word/20-exam seed data.
- `fr_edu_foreign_key_indexes.sql` — FK performance indexes.
- Both were executed successfully on the **AviationMatrix-Core** Supabase project and verified using read-only counts/privilege queries.
- Supabase security advisory `rls_enabled_no_policy` is expected on these private, deny-all tables, not an indication of public exposure. The unused-index advisory is expected until the app receives real traffic.

## Change control

- This is a separately namespaced backend foundation, **not a merge with the Aviation Matrix assessment engine**.
- No grade classification is approved yet.
- No database-backed live student application has been activated.
- Any subsequent decision to expose the private schema or modify data handling is a separate security and governance change.


## Cloud pilot extension — 2026-11-13

The guardian-managed pilot has been deployed with these additional resources:

- Migration: `fr_edu_guardian_teacher_pilot_linking.sql`.
- Edge Function: `french-education-pilot` (version 2, ACTIVE).
- Public test UI: `https://tamereltaher-svg.github.io/aviation-matrix-360/cloud-beta.html` — separated from the public demo.
- Edge source: `french-education-pilot/index.ts` (pinned `npm:postgres@3.4.5`).

**Security boundary:** Edge Function `verify_jwt=false` is intentional because the function explicitly checks the bearer user access token with the Supabase Auth `/auth/v1/user` endpoint on every POST action. Requests without valid confirmed Supabase Auth identity receive 401. Teacher reports require `fr_edu.user_roles` teacher/admin role and a guardian-granted `teacher_learner_access` row; authentication alone never authorizes teacher access. All SQL uses bound parameters.

**Guardian and learners:** Adults authenticate with email/password. Minor profiles are aliases, attached to a guardian account, with explicit consent version/timestamp. The guardian can revoke a teacher's access or permanently delete their learner profile and attempts. The teacher access code is not sufficient by itself: the guardian must grant access.

**Server grading:** The API generates and stores question selections in a transaction, then computes grades from private `lexemes`. It never sends the correct answer key for writing/letter items to the browser. The database enforces uniqueness on user/assessment/attempt number and limits attempts to 1–3. The general exam uses 18 question-pool slots. The pending-review grammar exam is deliberately excluded from the cloud pilot.

**Verification performed:** Supabase reports 23 RLS-enabled tables in `fr_edu`, 19 pilot assessment definitions, 1 assessment blocked pending review, zero live learner records/attempts, no direct anonymous/authenticated access to the private tables. Edge Function deployment is ACTIVE; GitHub Pages publish job returned success.

**Important remaining gates before production:**

1. No verified teacher/admin account has yet been assigned to `fr_edu.user_roles`. Teacher dashboard requires approval by the application administrator using a verified auth user ID; it has no self-service elevation.
2. A real adult authenticated end-to-end test was not possible without credentials; therefore actual remote start/submit/login and database connectivity via the Edge Function remain **unverified**. Deployed/ACTIVE does not establish full functionality.
3. The Supabase Auth email confirmation redirect URL may need to be allowlisted in Auth settings for this GitHub Pages URL. Do not change other Aviation Matrix auth settings without reviewing existing flows.
4. Policy governing minors' data processing, guardian verification, exact retention/deletion periods and institutional data controller responsibilities needs final approval. Keep this adult-supervised pilot in non-production until completed.
5. Public HTML quizzes continue to use localStorage independently. No backfill of old local results or automatic live roll-out has been performed.
6. Before full launch, test 3-attempt concurrency, session expiration, tampered user IDs, consent revocation, teacher access assignment/revocation, report access isolation and actual grading accuracy.
