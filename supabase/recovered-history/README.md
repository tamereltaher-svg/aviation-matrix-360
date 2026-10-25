# Aviation Matrix 360 — Archived Supabase Migration Source Recovery

**Archive status:** exact SQL source recovery, NOT permission to replay in production. Never execute this directory automatically, and never use an unreviewed release pipeline to apply these files.

## Snapshot — 2026-10-25
- 119 frozen baseline replay SQL files, unchanged.
- 39 further migration records in live production (158 total).
- **36/39** post-freeze SQL bodies recovered into this archive **byte-exact** to their stored statements in the live `supabase_migrations.schema_migrations` ledger.
- 2 others are already represented by verified GitHub SQL files:
  - `supabase/migrations/20260917_p1_close_final_public_data_api_bypasses.sql` — same after newline normalization.
  - `supabase/migrations/20261025_master_blueprint_registry_v1.sql` — byte-exact.
- **One historical temporary export-helper migration deliberately withheld from this public repository** (`20260903171748_temporary_reproducibility_export_rpc`) because its SQL body embeds identifiable production staff information. Its checksum and version remain in the metadata ledger, and the original statement remains in the private Supabase migration history. It is **not needed as a durable final-schema object**: a later tracked migration explicitly drops the helper. Skipping the pair in a clean replay requires a tested plan, not guesswork.

## Directories
- `transient/` — historical temporary extension enables/disables and removal of temporary helper. **Do not replay blindly**, particularly extensions with `CASCADE` behavior.
- `unverified/` — original schema and guard SQL as stored in Supabase, **not reviewed, ordered into the canonical deploy chain, or tested on an isolated database yet**.

## Assurance and precise verification
Every recovered file is verified using its **UTF-8 exact byte length and SHA-256** against `docs/blueprint/migration-ledger-2026-10-25.json`. GitHub Actions runs the dependency-free `docs/blueprint/validate_migration_ledger.py` validator and checks:
1. all 36 archived SQL sources are exact and uniquely versioned;
2. all 39 historical records are accounted for;
3. the original 119-migration freeze is unchanged;
4. the withheld helper cannot be accidentally committed under its expected archive name;
5. no archived files match high-confidence tokens/emails/identity patterns;
6. no false claim of completed end-to-end replay is recorded.

## IMPORTANT: SQL schema archive does not recreate curriculum content
A zero-data schema rebuild will **not** re-create the existing private educational rows. Current database counts: 3 draft courses, 24 draft lesson versions, 28 role profiles and 14 connected-flight phases. The 39 recovered/post-freeze migration bodies contain **zero `INSERT INTO` statements populating those four content tables**. This educational content was authored separately in production and requires a separately authorized **private, non-PII editorial-data preservation and restoration strategy**, without publishing unpublished lesson bodies or answer keys in this public repository.

## Required next steps before a rebuild can be certified
1. Review all 36 recovered bodies in a non-public/controlled review process for security-definer exposure, RLS policies, dependencies, transient extension history and non-idempotent statements.
2. Produce a chronological, dependency-reviewed **replay plan**. Do not drop or renumber the original 119-migration baseline.
3. Use **an isolated database**. The official Supabase development branch currently requires **explicit hourly-cost approval**; the request has not been confirmed and no branch was created.
4. Replay only the approved plan, compare schema, permissions/functions/RLS, check operational Edge Function deployment separately.
5. Restore approved non-personal curriculum content only through a separately reviewed private process. Never copy candidates, users, student grades or protected unpublished question data into public GitHub.
6. Record reproducibility evidence and rollback; obtain owner sign-off before using a release branch or deploying to `main`.

## Source and authority
`tamereltaher-svg/aviation-matrix-360` is the canonical GitHub codebase. The production `AviationMatrix-Core` Supabase instance remains the canonical operational database. This archive is a subordinate historical source register, not a second source of truth and not an instruction to mutate any database.
