# Aviation Matrix 360 — Status, Ownership & Decision Contract

## Immutable baseline

Original frozen `AM-ARCH-1.0` is the existing architecture in public Supabase tables; its **6 domains / 46 modules / 6 flows / 9 roles / 22 screens** remain untouched. GitHub is the canonical **approved code / architecture-document** repository. Unmerged branches are proposals. Supabase is the live operational database and holds the existing architecture registry. The `am_blueprint` private schema is a **versioned projection** of GitHub documentation and does not become a second authoring interface.

## Two separate statuses for every component

- **Historical registry status:** `existing`, `partial`, `planned` (or other legacy status). This is inherited from `am_platform_modules`; do **not** promote it on evidence of a filename.
- **Verified evidence status:** `confirmed_database` (object/row exists), `file_present` (path exists), `route_verified` (running route reached), `auth_verified` (authorization tested), `end_to_end_passed` (journey tested), `release_approved` (human-approved production release), `pending_validation`, `risk`. These are independent milestones. Failure at a deeper level does not erase the historical registry entry.

## Content / exam distinctions

- **Knowledge Core**: explanatory aviation knowledge, evidence-backed role origins, airline economics and cross-functional flight logic.
- **Learning path / lesson quiz**: student learning comprehension and progression, not airline hiring eligibility.
- **Professional assessment**: competency and career-fit evidence; no hidden pass/fail promotion of learning quiz scores.
- **Formal exam / credential**: separate assessment blueprint, release approval, scoring integrity, human governance and lawful credential issuance.
- **Open Day**: interconnectedness of airline functions and the full aviation industry, not a launch claim that draft courses are live.

## Data responsibility

| Material | Canonical authority | Allowed copies |
| --- | --- | --- |
| App code, process definitions, architecture graph, review gates | GitHub reviewed `main` | Feature branch drafts + packaged print exports |
| Frozen module registry `AM-ARCH-1.0` | Current Supabase original `am_platform_*` tables | Read-only GitHub snapshot and referenced nodes |
| Real candidates, registrations, payment, scores | Current Supabase production database | Protected backup only, **never public GitHub** |
| Blueprint registry cross-links | GitHub `master-blueprint.json` | Versioned, private-schema DB projection; no direct client editing |
| Credentials and validated evidence | Existing controlled server process | Approved candidate record only |

## Publication and approval

Blueprint states: `draft` → `in_review` → `approved` → `published`; approval cannot be asserted by creating an HTML page, seed script or GitHub PR. Courses and student rules remain disabled until qualified instructor/SME review. English is the only visible student/platform language. Arabic is retained but hidden and cannot be selected.

## Change-control checklist

1. Define new need, exact owner/domain and connected interfaces before implementation.
2. Find existing equivalent; avoid duplicate identities, assessments, students, statuses, database and screens.
3. Change only a reviewed feature branch; no direct writes to `main`.
4. Record source-of-truth paths, database objects, authorization boundary and test evidence in graph references.
5. New schema must have explicit least privilege, RLS where applicable and an isolated reproducibility test.
6. Any change affecting production data, identity, exam scoring or user-visible publication needs specific release authorization.
7. Review pull request; only then publish snapshot or merge code.

## Integration decisions confirmed in discussion

- Primary repo: `tamereltaher-svg/aviation-matrix-360`.
- Reuse current Supabase project; no second production Supabase.
- Preserve existing React website and older HTML candidate/staff surfaces until route/deployment audit decides final integration boundary.
- Knowledge Core is a common foundation for every aviation specialty, beginning with aviation origins, role evolution and a connected flight.
- Save Arabic translations while hiding them now.
- Existing application and employment requirements engine are separate from open educational content.
- Never perform an unreviewed merge or overwrite historical project decisions.

## Items still requiring explicit design review

- Exact hosting/production route ownership of React/Vite vs root HTML shell.
- Compatibility repair for revoked legacy assessment RPC calls.
- Auth user-to-candidate binding activation and retries.
- Learning quiz to candidate evidence mapping policy.
- Where controlled course editorial access lives, without exposing private review queues.
- Migration baseline reconciliation including post-frozen versions.
