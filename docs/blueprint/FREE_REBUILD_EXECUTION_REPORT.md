# Aviation Matrix 360 — Free Local Database Rebuild: Execution Evidence

**Date:** 2026-10-25. **Environment:** GitHub Actions standard `ubuntu-24.04` runner in the **public** canonical repository, running **temporary local Supabase Docker Postgres**. This test never connected to the production Supabase database. No paid Supabase branch was created; GitHub public standard runners are free.

**Verified workflow execution:** https://github.com/tamereltaher-svg/aviation-matrix-360/actions/runs/40207166353

## Gate-level outcome

| Gate | Result | Evidence |
| --- | --- | --- |
| Source recovery and provenance (G1A) | **PASS** | Original 119 recorded, 36 exact recovered SHA-256 matches, 2 already tracked, 1 historical identity-containing helper withheld |
| Disposable local Supabase startup | **PASS** | CLI started local Docker PostgreSQL; `auth.users` detected; no remote token |
| Recorded SQL replay (G1B) | **PASS** | All **119 frozen + 33 lasting post-freeze SQL scripts = 152 of 152** executed without SQL error |
| Application schema smoke test (G1B) | **PASS** | `am_platform_modules`, `avi_knowledge.lesson_versions`, `am_student_auth_bindings`, `am_blueprint.nodes` exist |
| Structural count comparison (G1C) | **FAIL — 14 measurable gaps** | Matched 5 schemas × 8 structural metrics against live production metadata; details below |
| Full application / educational-data restoration | **NOT TESTED / NOT CLAIMED** | Actual lesson/course/role/flight authorship rows are not in migration history |
| Releasing to `main` | **NOT DONE** | PR #4 remains Draft |

## Verified discrepancies

The same `pg_catalog` query was used to count five application schemas in production and in the isolated rebuild. The differences below are **production minus local**. Counts that do not appear in this table matched exactly.

| Schema | Object type | Local rebuilt | Production | Missing |
| --- | --- | ---: | ---: | ---: |
| `assessment` | Tables | 81 | 115 | **34** |
| `assessment` | Views | 6 | 8 | **2** |
| `assessment` | Indexes | 167 | 289 | **122** |
| `assessment` | RLS-enabled tables | 81 | 115 | **34** |
| `assessment` | Functions | 23 | 132 | **109** |
| `assessment` | Constraints | 275 | 751 | **476** |
| `assessment` | Non-internal triggers | 0 | 44 | **44** |
| `assessment_staging` | Tables | 1 | 12 | **11** |
| `assessment_staging` | Indexes | 0 | 42 | **42** |
| `assessment_staging` | RLS-enabled tables | 1 | 12 | **11** |
| `assessment_staging` | Functions | 0 | 6 | **6** |
| `assessment_staging` | Constraints | 0 | 74 | **74** |
| `assessment_staging` | Non-internal triggers | 0 | 10 | **10** |
| `public` | Functions | 63 | 69 | **6** |

**Important:** Counts show missing *numbers*, not object-by-object differences; avoid concluding specific object names or root causes without a named catalog diff. There may also be substitutions that cancel in aggregate. The `avi_knowledge` and `am_blueprint` counts all matched the current snapshot; this does not prove semantic equivalence of all functions or editorial row content.

## Historical sources and exact replay caveats

- The first trial reached historical RN67 before discovering original Phase06 assessment foundations omitted from the 119-file replay. Existing `0000_phase06_foundation_tables_01..03`, staging schema and key constraints were restored from pinned GitHub source before RN68.
- A later trial reached RN83 before hitting two missing historical Phase06 validator definitions. Original pinned pre-fix source files were injected before RN84/RN85.
- The pre-RN90 reviewer supplement was already preserved and SHA-256 verified in the original repo. **Three original function SQL blobs lacked a semicolon separating the closing `$function$` from `REVOKE` statements**. The local driver inserted the single missing separator **in memory only** after validating the original SHA-256, with the original b64 files unchanged.
- Six historical temporary extension/helper actions were intentionally not included in the 152-script lasting-schema replay; the missing temporary helper has real administrator identifiers and remains private in production's migration ledger.
- All 152 chosen recorded SQL statements executed, but **this is a reconstructed replay with explicitly documented historical supplements**, not proof that the 119 frozen files were independently sufficient.

## Scope of accuracy and security

- **No additional hosted Supabase project, no production migrations, no publication of education content, no `main` merge.**
- Standard GitHub Actions public repository runner documentation:
  https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- No production credentials or user rows were transferred to GitHub Actions. A brand-new Docker DB was started and removed afterward.
- The existing `AviationMatrix-Core` Supabase project remains the operational source of truth. Its original records, user identity and permissions were not modified by this test.
- Tests ran against Supabase local Postgres image version **17.11.0.006**, versus production Postgres **17.6.1.155**. The observed missing table and trigger counts cannot be assumed to arise from a PostgreSQL version discrepancy.

## Next free, safe step — targeted assessment recovery

1. Generate a **read-only named-object inventory** for `assessment`, `assessment_staging` and `public` from production's `pg_catalog`; do not read users, question answers, tokens or unpublished content.
2. Compare the named inventory to what the reconstructed local DB contains, not just the aggregate counts.
3. Retrieve missing DDL definitions through approved **schema metadata methods only**; review for hardcoded identities, access-control regressions and security-definer risks.
4. Archive reconstructed historical **schema-only** assessment/staging supplements with checksums; keep private any SQL that contains personal identifiers or unreleased exam/question content.
5. Re-run the **same free GitHub Actions local rebuild** and compare all five schemas again. Do not merge until 40/40 structural metrics, ownership/grant checks and the separate content restoration requirements are addressed.
6. Keep the course-authoring content restore on a different, restricted path; a schema-only dump cannot replace the 3 draft courses, 24 drafts lessons, 28 role profiles or 14 flight phases.

**Final G1 result for this iteration:** **G1A PASS, G1B PASS, G1C BLOCKED**, full project recoverability **NOT YET VERIFIED**. This is a validated partial rebuild at zero additional service cost.
