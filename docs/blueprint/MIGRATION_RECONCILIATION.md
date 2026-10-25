# Aviation Matrix 360 — Production Migration Reconciliation (Gate G1)

**As of 2026-10-25 — factual INVENTORY, not a database rebuild or certification.**

## Confirmed counts

- **119** historical Supabase migrations in the GitHub frozen replay manifest (`supabase/reproducibility/replay-manifest.json`, cutoff `20260903144840`).
- **158** entries in the live Supabase migration ledger; therefore **39** recorded later migrations.
- **2 / 39** post-freeze SQL source files verified on GitHub: `20260917141305` (normalized same text in `main`) and `20261025125459` (byte-identical SQL in the current feature branch).
- **37 / 39** later SQL bodies are not represented by verified committed source files; their original SQL statements are **recoverable from the live Supabase migration history**, but **have not been publicly exported**.
- Current migration statements span **169,215 bytes** in their stored source form. The companion JSON index has a full **SHA-256** and byte count for every recorded migration.
- Six entries are **temporary runtime operations** (extension enable/disable and temporary export helpers). These should be separated from long-lived reproducible schema changes when forming a replay plan.
- 22 statements match a broad SQL mutation keyword scan; 4 include schema-removal terms. These flags are a *review prompt*, not an assertion that rows were inserted or deleted.

## Grouped inventory

| Migration group | Recorded | Verified GitHub source | Requires source review |
| --- | ---: | ---: | ---: |
| temporary runtime history | 6 | 0 | 6 |
| security hardening | 4 | 1 | 3 |
| knowledge and role foundation | 15 | 0 | 15 |
| connected flight | 4 | 0 | 4 |
| student learning engine | 6 | 0 | 6 |
| locale policy | 3 | 0 | 3 |
| master blueprint registry | 1 | 1 | 0 |
| **TOTAL** | **39** | **2** | **37** |

Complete per-migration register, versions, source locators and checksums:
[migration-ledger-2026-10-25.json](migration-ledger-2026-10-25.json)

## Safe reproducibility procedure (NOT executed)

1. **Preserve `main` and existing production**. Keep the current feature PR as draft. No direct pushes, resets or automatic Drizzle schema sync to Supabase.
2. Export migration SQL **only to an access-controlled review environment**, then inspect for secrets, user records, unreviewed DML, temporary operations and sensitive information before committing to a public repository. The SHA-256 index lets reviewers compare recovered statements with the original ledger.
3. Build the chronological migration chain starting from the existing 119-migration frozen replay. Do not overwrite or renumber frozen files. Handle temporary extension toggles/export helper creation/removal carefully.
4. Run **isolated zero-state rebuild** on a temporary project, not on production. Verify actual SQL functions, schema objects, constraints, RLS and grants against live **metadata**, with no candidate/user data export.
5. Validate Edge Function deployment compatibility and front-end build/config separately. A DB schema match alone does not establish an operational deployment.
6. Capture migration hashes, test output and rollback considerations in a PR. Require explicit project-owner sign-off prior to any merge/release.

## Post-merge risk fixed in the review branch only

The original `scripts/post-merge.sh` ran `pnpm --filter db push`. This is dangerous because it can mutate the database as a side effect of merging Git changes.

The feature branch now runs **only** `pnpm install --frozen-lockfile` and prints a confirmation that no DB operations were run. `docs/blueprint/validate_deploy_safety.py` enforces the allowed command list; the GitHub Actions blueprint job invokes this test.

**Important boundary:** the deployed `main` branch is still unchanged and still contains the old hook. This correction is *prepared and tested in a draft PR*, not released. GitHub `main` branch protection was reported as disabled; manual approval and branch policy still need owner action.

## Actual G1 status

- Read-only migration inventory and SHA-256 audit: **completed**.
- Original SQL fully recovered to an approved reviewed source repository: **not yet completed** (37 items).
- Rebuild isolated from production: **not executed**.
- Full production parity and rollback proof: **not verified**.
- Therefore **G1 remains BLOCKED**, not complete.

## No production data change

This audit uses only `SELECT` against Supabase migration metadata, and changes only the *GitHub feature branch*. It does not create migrations, activate student courses, reopen security grants, alter candidate records or touch production configuration.
