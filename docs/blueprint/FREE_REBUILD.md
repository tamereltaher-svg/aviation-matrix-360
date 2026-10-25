# Aviation Matrix 360 — Zero-Cost Isolated Database Rebuild

**Owner constraint: zero paid services.** Do **not** create a paid Supabase development branch, additional hosted Supabase project, cloud VM or commercial CI subscription. The user explicitly declined any incremental cost.

## Architecture of the free test

1. **Source repository:** the existing PUBLIC `tamereltaher-svg/aviation-matrix-360` GitHub repository and its separate review branch.
2. **Runner:** a standard GitHub-hosted `ubuntu-24.04` Actions runner. GitHub documents standard runner execution on **public repositories as free**. No new account, invoice, or third-party service required.
3. **Temporary database:** Supabase CLI spins up disposable local Docker containers on that runner. Its Postgres is isolated from the live `AviationMatrix-Core` project.
4. **Migrations:** replay 119 sanitized historical migrations, followed by 33 structural/security post-freeze statements. There are 39 later recorded entries: 33 durable and 6 historical temporary operations excluded from the replay plan for review; this difference must be verified against the final schema.
5. **Security:** no `SUPABASE_ACCESS_TOKEN`, production URL, service role key, candidate data, role accounts or passwords in the workflow. CI has `contents: read`. The driver only uses `docker exec` against the local `supabase_db_*` instance. Never uses `db push`, `db reset --linked`, `apply_migration` or production credentials.
6. **Cleanup:** the hosted runner and containers are temporary. The workflow stops the local Supabase instance and exits.

GitHub documentation confirming the zero-cost standard public runner:
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.github.com/en/actions/concepts/billing-and-usage

Supabase's official local development instructions:
- https://supabase.com/docs/guides/local-development

## Running the free test

- GitHub workflow: [`.github/workflows/free-isolated-rebuild.yml`](../../.github/workflows/free-isolated-rebuild.yml)
- Local replay driver: [`run_free_local_rebuild.py`](run_free_local_rebuild.py)
- Source archive and exceptional withheld historical identity helper: [Recovered-history README](../../supabase/recovered-history/README.md)
- Frozen migration baseline: [`replay-manifest.json`](../../supabase/reproducibility/replay-manifest.json)
- Post-freeze checksums: [`migration-ledger-2026-10-25.json`](migration-ledger-2026-10-25.json)

The workflow triggers only for changes to the replay and test files on the **feature branch** (and manual dispatch if permitted). No scheduled runs, no auto-merge and no production deploy.

For source integrity only, the free local Python check is:
```bash
python docs/blueprint/validate_migration_ledger.py
python docs/blueprint/run_free_local_rebuild.py --check-only
```

To execute a local replay, start Supabase CLI using a separate empty working directory (NOT the repository's production-connected project configuration) and then run:
```bash
python docs/blueprint/run_free_local_rebuild.py --replay
```

This `--replay` command REQUIRES exactly one `supabase_db_*` **Docker** container; it never accepts a remote database URL. Existing production migration/seed files remain untouched.

## Gate definitions

- **G1A — Provenance:** SHA-256 file sources matching the live ledger, complete version inventory, sensitive helper withheld. This has passed for all 39 entries (36 recovered, 2 existing, 1 withheld).
- **G1B — Isolated schema replay:** the new free workflow must finish all 119+33 steps and verify the actual database objects. A **failing run** is a finding, not proof of parity.
- **G1C — Full schema parity:** compare generated tables, RLS, functions, triggers, indexes and constraints against production metadata; no privileged grant broadening. Even if G1B passes, G1C is a separate certification.
- **G1D — Content restoration:** live student learning data (3 draft courses, 24 draft lessons, 28 role profiles, 14 flight phases) was authored separately and is **not seeded by migration history**; a private, reviewed content-backup strategy is required before declaring a completely restorable platform.
- **G1E — Human release sign-off:** GitHub PR remains DRAFT until reviewed. Never move reconstructed SQL straight into auto-executable `supabase/migrations/` as part of this test.

**Report claims strictly:** the workflow's status is the test result; no claim that full Aviation Matrix was rebuilt until schema, private authoring content, Edge Functions, auth and application routes were demonstrated independently.
