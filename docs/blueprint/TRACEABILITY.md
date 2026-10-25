# Aviation Matrix 360 — Verified Traceability Matrix (Draft)

**Status vocabulary:** “present in GitHub / registered in Supabase” is *not* “tested, deployed or ready”. Historical module status is copied from the original frozen registry without promotion. The only live-data reads used to author this document were structural metadata and aggregate counts.

## 1. Six original domains and their known code surfaces

| Domain | Registered modules | Primary staff hub | Known surfaces (paths verified in GitHub) |
| --- | ---: | --- | --- |
| **BUS — Business Operations** | 5 | [`business_hub.html`](../../business_hub.html) | [`business_hub.html`](../../business_hub.html); [`store_admin.html`](../../store_admin.html); [`aviation_store_live.html`](../../aviation_store_live.html); [`supabase/functions/staff-admin-api/index.ts`](../../supabase/functions/staff-admin-api/index.ts) |
| **KIDS — Kids Aviation** | 9 | [`kids_hub.html`](../../kids_hub.html) | [`kids_hub.html`](../../kids_hub.html); [`kids_experience.html`](../../kids_experience.html); [`kids_control_tower.html`](../../kids_control_tower.html); [`supabase/functions/kids-experience-api/index.ts`](../../supabase/functions/kids-experience-api/index.ts) |
| **TALENT — Talent Intelligence** | 8 | [`talent_hub.html`](../../talent_hub.html) | [`talent_hub.html`](../../talent_hub.html); [`candidate_360_dashboard.html`](../../candidate_360_dashboard.html); [`candidate_lifetime_record.html`](../../candidate_lifetime_record.html); [`registration_onboarding.html`](../../registration_onboarding.html); [`supabase/functions/registration-public-api/index.ts`](../../supabase/functions/registration-public-api/index.ts) |
| **LEARN — Learning & Assessment** | 7 | [`learning_hub.html`](../../learning_hub.html) | [`learning_hub.html`](../../learning_hub.html); [`exam_transcript.html`](../../exam_transcript.html); [`artifacts/aviation-matrix-360/src/pages/academy.tsx`](../../artifacts/aviation-matrix-360/src/pages/academy.tsx); [`apps/phase06-reviewer/app/review/page.tsx`](../../apps/phase06-reviewer/app/review/page.tsx) |
| **AIR — Airline & Employer** | 7 | [`airline_hub.html`](../../airline_hub.html) | [`airline_hub.html`](../../airline_hub.html); [`employer_dashboard.html`](../../employer_dashboard.html); [`airline_readiness.html`](../../airline_readiness.html); [`airline_employer_architecture_phase6.html`](../../airline_employer_architecture_phase6.html) |
| **PLAT — Platform & Governance** | 10 | [`platform_hub.html`](../../platform_hub.html) | [`platform_hub.html`](../../platform_hub.html); [`portal.html`](../../portal.html); [`management_dashboard.html`](../../management_dashboard.html); [`supabase/functions/platform-reporting-api/index.ts`](../../supabase/functions/platform-reporting-api/index.ts) |

## 2. All 46 original architectural modules

The **status** column is a value recorded in the existing `public.am_platform_modules` registry, not a runtime certification. The **entrypoint** column is a domain hub, not a claim that this specific module is fully implemented.

| Domain | Module code | Name | Original DB status | Domain entrypoint |
| --- | --- | --- | --- | --- |
| BUS | `BUS-INST` | Institutions & Relationships | **existing** | [business_hub.html](../../business_hub.html) |
| BUS | `BUS-PRC` | Pricing & Commercial Rules | **partial** | [business_hub.html](../../business_hub.html) |
| BUS | `BUS-PROD` | Products & Store | **existing** | [business_hub.html](../../business_hub.html) |
| BUS | `BUS-PROG` | Programs | **existing** | [business_hub.html](../../business_hub.html) |
| BUS | `BUS-REQ` | Requests & Quotations | **existing** | [business_hub.html](../../business_hub.html) |
| KIDS | `KID-ACT` | Creative Activities | **partial** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-AI` | AI Production Studio | **existing** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-BOOK` | Books & Publishing | **existing** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-COM` | Kids Products & Store | **existing** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-EXP` | Kids Public Experience | **existing** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-JRN` | Journey & Missions | **existing** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-MEDIA` | Stories & Media | **partial** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-RWD` | Rewards & Passport | **existing** | [kids_hub.html](../../kids_hub.html) |
| KIDS | `KID-UNI` | Characters & Universe | **existing** | [kids_hub.html](../../kids_hub.html) |
| TALENT | `TAL-APP` | Applicant & Application | **partial** | [talent_hub.html](../../talent_hub.html) |
| TALENT | `TAL-CAN` | Candidate 360 Profile | **partial** | [talent_hub.html](../../talent_hub.html) |
| TALENT | `TAL-DOC` | Document & Credential Vault | **planned** | [talent_hub.html](../../talent_hub.html) |
| TALENT | `TAL-DOS` | Candidate Dossier | **partial** | [talent_hub.html](../../talent_hub.html) |
| TALENT | `TAL-EVD` | Evidence Portfolio | **partial** | [talent_hub.html](../../talent_hub.html) |
| TALENT | `TAL-FIT` | Career Fit & Development | **partial** | [talent_hub.html](../../talent_hub.html) |
| TALENT | `TAL-PER` | Person & Identity | **partial** | [talent_hub.html](../../talent_hub.html) |
| TALENT | `TAL-TIM` | Candidate Timeline | **planned** | [talent_hub.html](../../talent_hub.html) |
| LEARN | `LRN-ASM` | Assessment Builder | **partial** | [learning_hub.html](../../learning_hub.html) |
| LEARN | `LRN-CRD` | Certificates & Credentials | **partial** | [learning_hub.html](../../learning_hub.html) |
| LEARN | `LRN-CRS` | Courses & Learning Paths | **partial** | [learning_hub.html](../../learning_hub.html) |
| LEARN | `LRN-CUR` | Curriculum Architecture | **partial** | [learning_hub.html](../../learning_hub.html) |
| LEARN | `LRN-EXM` | Exam Builder & Sessions | **partial** | [learning_hub.html](../../learning_hub.html) |
| LEARN | `LRN-QB` | Question Bank | **partial** | [learning_hub.html](../../learning_hub.html) |
| LEARN | `LRN-SCR` | Scoring & Results | **partial** | [learning_hub.html](../../learning_hub.html) |
| AIR | `AIR-CMP` | Recruitment Campaigns | **partial** | [airline_hub.html](../../airline_hub.html) |
| AIR | `AIR-HIR` | Hiring Outcomes | **partial** | [airline_hub.html](../../airline_hub.html) |
| AIR | `AIR-MAT` | Candidate Matching | **partial** | [airline_hub.html](../../airline_hub.html) |
| AIR | `AIR-ORG` | Airline & Employer Profiles | **partial** | [airline_hub.html](../../airline_hub.html) |
| AIR | `AIR-REQ` | Requirements Engine | **partial** | [airline_hub.html](../../airline_hub.html) |
| AIR | `AIR-ROLE` | Job Roles | **partial** | [airline_hub.html](../../airline_hub.html) |
| AIR | `AIR-SHL` | Shortlists & Interviews | **partial** | [airline_hub.html](../../airline_hub.html) |
| PLAT | `PLT-AI` | AI Governance & Configuration | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-AUD` | Audit & Event Bus | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-CMP` | Competency Framework | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-COM` | Communications Timeline | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-DEC` | Decision History | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-HLT` | System Health & Control Tower | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-IAM` | Identity & Access | **existing** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-REF` | Master Reference Data | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-RPT` | Reporting & Export Layer | **partial** | [platform_hub.html](../../platform_hub.html) |
| PLAT | `PLT-WF` | Workflow & Approvals | **partial** | [platform_hub.html](../../platform_hub.html) |

## 3. Screen hints recorded in Supabase — verification

The registered `am_platform_screens.route_hint` is **not** proof of a valid deployed route. The following is explicitly a code-presence check:

| Screen code | Registered route hint | File exists in GitHub main? | Interpretation |
| --- | --- | --- | --- |
| `SCR-AIR-CMP` | `airline_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-AIR-MAT` | `airline_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-AIR-REQ` | `airline_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-BUS-PROD` | `store_admin.html` | **Yes** | Source exists; runtime unverified |
| `SCR-BUS-PROG` | `store_admin.html` | **Yes** | Source exists; runtime unverified |
| `SCR-BUS-REQ` | `store_admin.html` | **Yes** | Source exists; runtime unverified |
| `SCR-KID-AI` | `kids_ai_studio.html` | **Yes** | Source exists; runtime unverified |
| `SCR-KID-BADGES` | `kids_badges.html` | **Yes** | Source exists; runtime unverified |
| `SCR-KID-JRN` | `kids_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-KID-MAP` | `kids_mission_map.html` | **Yes** | Source exists; runtime unverified |
| `SCR-KID-PASS` | `kids_passports_admin.html` | **Yes** | Source exists; runtime unverified |
| `SCR-KID-PASSPORT` | `kids_experience.html` | **Yes** | Source exists; runtime unverified |
| `SCR-KID-WORLD` | `kids_world.html` | **Yes** | Source exists; runtime unverified |
| `SCR-LRN-EXM` | `learning_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-LRN-QB` | `learning_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-LRN-RESULT` | `learning_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-PLT-HLT` | `platform_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-PLT-IAM` | `platform_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-PLT-RPT` | `platform_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-TAL-APP` | `talent_hub.html` | **Yes** | Source exists; runtime unverified |
| `SCR-TAL-C360` | `candidate_360.html` | **No** | Likely intended `candidate_360_dashboard.html`; validate before any update |
| `SCR-TAL-DOS` | `candidate_dossier.html` | **Yes** | Source exists; runtime unverified |

## 4. Role and interface boundaries

| Persona | Entry / security | Authoritative identity |
| --- | --- | --- |
| Visitor / Candidate | `index.html` + `app.js`, `registration_request.html`, `registration_onboarding.html` | Supabase Auth and existing person/candidate records; onboarding tokens are a separate limited-purpose flow |
| Staff / Admin | `portal.html` → domain hub → tool | Independent staff session and staff permission registry; never treated as student credentials |
| Instructor / reviewer | `apps/phase06-reviewer` for the Phase06 editorial-review tool | Reviewer registry plus validated Supabase Auth; other instructor portal workflows not confirmed |
| Employer | `airline_hub.html`, `employer_dashboard.html` | Employer registration, campaign, matching and sharing require authorization validation |
| Kids / guardian | `kids_experience.html`, `kids_parents.html` | Guardian/minor entitlements must remain isolated from public browsing |

## 5. Architectural flows that exist in the original database

**Candidate Lifecycle:** Registration → Screening → Applicant → Assessment → Candidate Activation → Enrollment → Learning → Exams → Evidence → Requirements → Matching → Outcome

**Kids Explorer Lifecycle:** Passport → Level → Season → Mission → Stamp → Badge → Certificate → Content/Product Experience

**Assessment & Exam Lifecycle:** Blueprint → Question Bank → Version → Eligibility → Session/Attempt → Integrity → Scoring → Result → Evidence → Credential/Retake

**Airline Recruitment Lifecycle:** Employer → Role → Requirements → Campaign → Matching → Review → Shortlist → Interview → Offer/Hiring Outcome

**Candidate Dossier Lifecycle:** Identity → Entry Profile → Assessment → Development → Training → Exams → Credentials → Requirements → Readiness → Controlled Release

**Requirement Evaluation Lifecycle:** Requirement → Evidence Lookup → Rule Evaluation → Gap → Decision → Trace → Re-evaluate

## 6. Live database source areas (no PII)

- Original frozen architecture: `public.am_platform_architecture_versions`, `am_platform_domains`, `am_platform_modules`, `am_platform_flows`, `am_platform_screens`, `am_platform_roles`.
- Candidate identity and continuity: `public.am_persons`, `am_candidate_records`, `am_candidate_current_state`, `am_registration_applications`, `am_application_auth_bindings`.
- Professional assessment and traceability: `am_candidate_assessment_journeys`, `am_candidate_stage_attempts`, `am_candidate_evidence`, `am_candidate_lifetime_events`.
- Learning and student engine: `am_learning_curricula`, `am_learning_paths`, `am_learning_courses`, `am_candidate_learning_enrollments`, `am_student_auth_bindings`, `am_student_lesson_progress`, `am_student_lesson_attempts`.
- Governed content: `avi_knowledge` schema including `lesson_versions`, `role_profiles`, `connected_flight_phases`, `sources`.
- Standalone historical build freeze: `supabase/reproducibility/replay-manifest.json` documents **119** past migrations, vs **157** currently in production (38 post-freeze).

## 7. High-risk mismatches (all unresolved)

1. `app.js` calls the legacy `public_start_assessment` / `public_submit_assessment_answer` / `public_finish_assessment` and `public_register_application` RPCs. Current production denies `anon/authenticated` EXECUTE. Correct through secure Edge API compatibility, not grants.
2. `scripts/post-merge.sh` executes `pnpm --filter db push`; prohibit production invocation pending reproducibility investigation.
3. The React/Vite corporate site and root candidate HTML shell both exist. Actual production route selection is **unverified**.
4. Learner activation is not complete merely when an application OTP is verified; verify a trusted `auth_user_id → candidate_id` binding and candidate activation state.
5. Original portal language includes English/French/Russian in `app.js`; the agreed current platform/student UI is **English visible only**, Arabic translations retained in storage. Treat cross-surface language consistency as a future integration gate (do not delete other content in code in this phase).

## 8. Traceability method

Each real implementation change should update the node/edge graph, add a GitHub file/DB object evidence locator, record last verified state and a regression-test reference, and pass the relevant gate in [INTEGRATION_GATES.md](INTEGRATION_GATES.md). **Never infer implementation solely from the name of a file, table, or screen.**
