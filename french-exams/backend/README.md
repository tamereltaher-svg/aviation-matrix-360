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
