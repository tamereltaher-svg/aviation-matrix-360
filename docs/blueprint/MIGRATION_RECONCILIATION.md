# Aviation Matrix 360 — Supabase migration source reconciliation

**Review snapshot: 2026-10-25.** GitHub PR remains DRAFT. Original production database has not been modified by this recovery.

## Exact sources recovered

| Evidence | Count |
| --- | ---: |
| Frozen historical replay baseline, unchanged | **119** |
| Live migration history entries | **158** |
| Post-freeze migration entries | **39** |
| **Newly recovered byte-exact source files** | **36** |
| Already verified GitHub SQL sources | **2** |
| Withheld from public GitHub: historical helper containing production administrator identifiers | **1** |
| **All recorded entries accounted for** | **39 / 39** |
| Rebuild verified on isolated PostgreSQL | **NO** |
| Unpublished foundation content restorable from migrations alone | **NO** |

Every one of the 36 new source files has been compared against the Supabase stored SQL statement using both **exact UTF-8 byte lengths and SHA-256**. Additional Git-object blob SHA-1 comparison independently matched the source contents in the GitHub tree. The two previously tracked sources were verified (one after trailing-newline normalization).

The recovered SQL bodies reside under **[`supabase/recovered-history/`](../../supabase/recovered-history/README.md)**, *not* the executable migration directory. Original recorded version numbers are preserved. No automatic replay hook is permitted to execute them.

## Breakdown

| Area | Recorded | Exact archival | Previously in GitHub | Withheld |
| --- | ---: | ---: | ---: | ---: |
| temporary runtime history | 6 | 5 | 0 | 1 |
| security hardening | 4 | 3 | 1 | 0 |
| knowledge and role foundation | 15 | 15 | 0 | 0 |
| connected flight | 4 | 4 | 0 | 0 |
| student learning engine | 6 | 6 | 0 | 0 |
| locale policy | 3 | 3 | 0 | 0 |
| master blueprint registry | 1 | 0 | 1 | 0 |
| **Total** | **39** | **36** | **2** | **1** |

A version-by-version SHA-256 audit is available in [migration-ledger-2026-10-25.json](migration-ledger-2026-10-25.json). The dependency-free CI validator [validate_migration_ledger.py](validate_migration_ledger.py) checks all recovered byte streams and permanently blocks the identity-bearing migration from the public archive.

## Special handling of the withheld historical helper

The entry identified by version **`20260903171748`** contains embedded identifiers from a historic administrator seed-sanitization operation. Publishing the exact body to a public GitHub repository would unnecessarily disclose real information. Its original SQL **remains recoverable privately** in `supabase_migrations.schema_migrations`; its name, version, SHA-256, source size and withholding reason are recorded without the identifiers.

The helper was transient and a later recorded migration removes it. A clean schema-only replay may be able to skip its create/drop lifecycle together, **but that is a review hypothesis, not a tested or approved omission**. Do not replace it with fictitious SQL and claim an exact reconstruction.

## Additional blocker discovered: curriculum authoring data is outside migration history

Current live database records include:
- **3** draft `am_learning_courses` rows.
- **24** draft `avi_knowledge.lesson_versions`.
- **28** aviation `avi_knowledge.role_profiles`.
- **14** `avi_knowledge.connected_flight_phases`.
- **0** published lessons; **0** student enrollments and attempts.

A targeted scan of all 39 post-freeze statements found **zero direct `INSERT INTO` statements populating any of these four content tables**. The SQL files reconstruct database *structures and rules*, but **cannot independently reproduce these educational records**. They were authored separately. Preserve the unpublished content and eventual quiz answers in a **private, versioned editorial-data backup / seed mechanism**, not in a public GitHub repository. A successful schema rebuild is *not* a complete Aviation Matrix rebuild.

## Replay safety analysis: what has NOT been certified

1. **Historical runtime artifacts.** The archived transient `http` extension toggles include a `DROP EXTENSION ... CASCADE` operation; blindly executing the entire historical series may remove objects in a different database state. Review net effects and dependencies.
2. **Function and RLS semantics.** Privileged helper routines, security gates and student-RPC access rules must be tested in a separate database with least privilege and cross-candidate isolation, not assumed safe from syntactic validity.
3. **Legacy rollout gap.** The original 119 historical replay migrations were produced as a frozen sanitized bundle; 39 later migrations do not automatically imply a working copy of all operational data.
4. **Partial interfaces.** Database functions and structures alone do not deploy React pages, registration Edge Functions, the reviewer app or Kids/Employer workflows.
5. **Deployment hook.** `scripts/post-merge.sh` is safe **only in the Draft PR**. Production `main` still contains a DB push command until reviewed merge.
6. **No runtime branching yet.** Supabase requires a cost confirmation for a new development branch. This confirmation has not been obtained, so **no paid branch was created and no rebuild executed**.

## Exact order for isolated rebuild once an environment is approved

**G1A — Source recovery: completed with 1 intentional private exception.**
Run `python docs/blueprint/validate_migration_ledger.py` in a pinned GitHub checkout. Verify 119 frozen files intact and 39 later ledger entries accounted for; keep sensitive source private.

**G1B — Final-state schema reconstruction: blocked on isolated environment.**
1. Prepare a disposable, isolated Postgres/Supabase test project without any production user records. Obtain user-approved branch cost where applicable.
2. Replay the *original 119* in order, then the later versions in recorded chronology, using a reviewed explicit allowlist for transient operations. No implicit `db push`.
3. Compare table/column/constraint/function definitions, index/foreign-key topology, RLS policies, grants, extensions, triggers and functions against **production metadata**. Record warnings and differences rather than silently changing production.
4. Check each recovered statement’s original SHA-256 before execution; store per-step transaction results and failure logs. Document any necessary skip/translation and why.
5. Run sample anonymous/authenticated permissions and student security checks using synthetic accounts only. Make **no new real candidate accounts**.

**G1C — Content and runtime reproducibility: blocked pending private backup strategy.**
Prepare restricted, versioned snapshots of the **non-personal unpublished authoring data**, with expert review and content provenance; test restore separately. Never dump user profiles, login tokens, exam answers or private candidate data into a public GitHub branch.

**G1D — Release:** keep PR draft until G1B/G1C are demonstrated and project owner approves; then consider merging. A branch-creation cost approval is not a deployment/merge approval.

## Controls already installed
- Draft PR [#4](https://github.com/tamereltaher-svg/aviation-matrix-360/pull/4) includes the original 36 sources, source-index checks, Master Blueprint and 21 printable maps.
- [`validate_deploy_safety.py`](validate_deploy_safety.py) ensures the branch's Replit post-merge hook cannot change the database.
- [`validate_migration_ledger.py`](validate_migration_ledger.py) verifies historical source bytes and the quarantined record.
- CI checks run without Supabase credentials or production DB access.

**Conclusion: 100% of post-freeze migration versions accounted for; 36 newly recovered byte-exact; 1 withheld for legitimate privacy; full isolated rebuild still PENDING.**
