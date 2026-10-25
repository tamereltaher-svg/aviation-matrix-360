# Aviation Matrix 360 — Safe Integration Gates and Test Plan

This is the **required sequence**, not a claim of completion. Draft Master Blueprint registry data may exist before the production gates pass.

| Gate | State at 2026-10-25 | Deliverable | Pass evidence |
| --- | --- | --- | --- |
| **G0** Snapshot/preserve baseline | In progress — draft branch hook now safe; main remains unchanged | Main commit pinned; post-merge DB push removed in branch; no old data writes | Git SHA; CI release guard; manual merge and backup still required |
| **G1** Migration reconciliation | PARTIAL — G1A source recovery PASS; G1B isolated 152-script replay PASS; G1C structure parity FAIL (14 differences) | Reconcile **158 live** vs **119 historical replay** migrations (**39** post-freeze: **36** exact recovered SQL files, **2** previously tracked, **1** private sensitive helper withheld), verify isolated rebuild | [Migration ledger](migration-ledger-2026-10-25.json) and [reconciliation plan](MIGRATION_RECONCILIATION.md); [free test evidence](FREE_REBUILD_EXECUTION_REPORT.md): all SQL executed; 14 structural gaps remain (assessment/staging/public) |
| **G2** Registration and assessment API compatibility | Blocked | Old direct browser RPCs refactored into supported secure Edge/API workflow | Anonymous access denied, legitimate candidate registration/assessment E2E pass |
| **G3** Identity continuity | Blocked | Supabase Auth user verified against canonical activated Candidate Record | Cannot impersonate a second candidate; invalid user and inactive candidate denied |
| **G4** Learning experience integration | Not started | Integrate English-first, Arabic-hidden learning within existing repo surfaces | React/legacy regression, nav, responsive UI, only published catalog displayed |
| **G5** Evidence and scoring separation | Not started | Define mapping from learning quizzes to existing evidence engine | Lesson quiz cannot become exam result/credential; immutable attempt history tested |
| **G6** Human release approval | Blocked | Qualified expert reviews for all foundation lessons, role history, safety and simulation assumptions | Review signatures/evidence and release gates clear; no draft published |
| **G7** Staging deployment and approval | Not started | Staging deploy and regression; reviewed PR | Backup, rollback, security checks, approved merges and release go/no-go |

## Mandatory tests per surface

- **Registration:** direct Data API insert denied; application flow successful through controlled API; rate limit, OTP, duplicate detection, activation preserved.
- **Assessment:** no frontend `service_role`, no restored public direct RPC grants, existing recorded outcome unchanged; invalid answer, retry and timeouts tested.
- **Candidate 360:** one candidate identity; no cross-candidate data leakage; existing lifetime timeline and evidence unchanged.
- **Student:** catalog only published/approved courses; draft hidden; verified binding; enrollment and lesson unlock server-side, no answer keys in client; attempt immutability.
- **Staff and Kids:** `am_staff_token` not interchangeable with Supabase Auth; authorized staff only; Kids guardian entitlement unchanged; no unauthorized content exposure.
- **Editorial:** instructor/reviewer role checks, restricted question bank, approvals and moderation preserved.
- **SQL:** isolate from production; reproducible ordered migrations and tested replays; never automatically `drizzle-kit push` to production.
- **Frontend:** desktop and mobile; all old route links; `Academy` and candidate paths use same canonical platform, with no broken redirects.
- **Language:** student and platform always English-only visible until explicit later decision; Arabic translations retained at rest.

## Known current blockers

1. Last GitHub `main` commit 2026-09-17; live migration ledger now contains 158 total entries (39 after the original 119 freeze), 29 post-September-17 including the private blueprint schema. 36/39 additional SQL bodies now have exact SHA-256-verified archived GitHub files; two already had committed source; one historical helper with production administrator identifiers is withheld from public GitHub. Isolated SQL replay now completed (152/152); structural parity is NOT certified because 14 count gaps remain.
2. Historical `am_platform_screens` row `SCR-TAL-C360` points at `candidate_360.html` while `candidate_360_dashboard.html` exists in repo. Runtime route not yet confirmed.
3. `app.js` calls legacy RPCs which are currently not executable by `anon`/`authenticated`; do not weaken server permissions.
4. `scripts/post-merge.sh` still runs a DB push on `main`, but **the draft branch removes it** and a CI test guards against regression. No safety fix is deployed until this PR is approved and merged.
5. Three draft courses with 24 lessons still cannot be released.

## Rollback and operation

GitHub: feature branch isolated; revert PR / do not merge if tests fail. Supabase: this blueprint work uses a **new private namespace only** and no destructive operations, enrollment changes or exposed client policies. If further production DDL is needed, schedule and review migration+backup separately. Never drop original architecture or copy real user data into public files.
