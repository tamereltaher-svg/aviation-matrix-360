# Aviation Matrix 360 — Master Blueprint (Draft v1)

> **Canonical repo:** `tamereltaher-svg/aviation-matrix-360` — **working branch:** `feature/master-blueprint-organization-20261025`. These documents are a draft, not a production release. Changes to `main` require a reviewed pull request. The original frozen `AM-ARCH-1.0` architecture stays intact.

## Start here

| Document | Why it exists |
| --- | --- |
| [Master Blueprint graph](master-blueprint.json) | Machine-readable, versioned nodes/relationships/evidence, with historical state kept separate from runtime verification |
| [Printable interactive map](master-blueprint-print.html) | Grayscale, printer-friendly map selector for independent A4 landscape sheets |
| [Traceability](TRACEABILITY.md) | Connect domains to real repository surfaces, backend areas, and known data objects |
| [Decision & status contract](STATUS_AND_GOVERNANCE.md) | Define what is frozen, draft, verified, planned, or blocked and where decisions belong |
| [Integration gates](INTEGRATION_GATES.md) | Protected order of operations before any changes to candidate paths, scoring, or deployment |
| [Registry SQL](../../supabase/migrations/20261025_master_blueprint_registry_v1.sql) | An **additive private-schema** Supabase projection; no edits to existing architecture tables |
| [Seed SQL](../../supabase/blueprint/seed_master_blueprint_20261025_v1.sql) | Reproducible mapping of this graph into the private database registry |

## The preserved source of truth

- **GitHub main**: canonical approved code and versioned architecture. This branch is a proposed increment until reviewed/merged.
- **Frozen original architecture**: `public.am_platform_architecture_versions`, `am_platform_domains`, `am_platform_modules`, `am_platform_flows`, `am_platform_screens`, `am_platform_roles`. Do **not** overwrite or recreate these records.
- **Supabase live**: one operational database, preserving identity, candidate, learning, question bank, evidence and audit records.
- **Blueprint data**: `master-blueprint.json` is the editable definition; the `am_blueprint` private schema is its versioned, read-only-for-clients projection.

## Existing baseline from live records (2026-10-25)

- **6** registered domains, **46** module records, **22** screen records, **6** lifecycle flows, **9** role records.
- Registered module statuses: **12 existing**, **32 partial**, **2 planned**. These are *registry status*, **not** evidence that each screen runs.
- **3** draft foundation courses, **24** lesson versions, **0** published. Student binding/enrollment: **0**.
- **157** live Supabase migrations; the historical reproducibility manifest documents **119**. **38 later migrations** require reconciliation prior to any rebuild test.
- Master Blueprint V1: **118 mapped nodes**, **47 mapped links**, **58 source references**; all need ongoing verification.

## Governance principles

1. One Person Record; no parallel candidate/user identity.
2. One Evidence Engine; **lesson quiz score ≠ career fit assessment ≠ approved examination evidence**.
3. One Requirements Engine; no employer matches without traceable, authorized evidence.
4. Cross-functional interoperability — the reason every aviation role exists and how information/authority flows between them.
5. The foundational Knowledge Core is taught before specializations; courses cannot publish without qualified human review.
6. English visible now; Arabic content remains retained, hidden, and not selectable.
7. Content files and interfaces may be shown as drafts only; status must never claim “live” simply because a file exists.

## Safety boundaries

- Do not move old files, rename navigation, bypass RLS, broaden old RPC permissions, modify live registration or learning records, change staff auth, or release courses as part of blueprint organization.
- Do not put secrets, user records, unpublished full lesson texts, exam keys, or PII in this public repo.
- Never run `scripts/post-merge.sh` or `pnpm --filter db push` against production without a separate risk assessment and explicit release approval.
- Review the draft PR and test isolated database migrations before promoting this snapshot to `approved` or `published`.

## Current roadmap

**G0 Preserve baseline** → **G1 Reconcile database migrations** → **G2 Resolve legacy assessment APIs** → **G3 Bind student identity** → **G4 Integrate UI** → **G5 Semantically link evidence** → **G6 Approve course content** → **G7 Regression + release sign-off**.

**Ownership:** B Solution / Aviation Matrix project. This documentation is architectural; it makes no claims of a separate Aviation Matrix legal entity.
