# Aviation Matrix 360 — Decisions Register

This register distinguishes earlier **confirmed** commitments from **newly proposed** architectural work. A proposed choice cannot silently replace an agreed one.

| ID | Status | Decision / unresolved question | Source/impact |
| --- | --- | --- | --- |
| D-001 | **LOCKED** | `tamereltaher-svg/aviation-matrix-360` is the canonical project codebase; new work adapts to it | GitHub main retained |
| D-002 | **LOCKED** | One Supabase operational database; don't create a replacement instance | AviationMatrix-Core retained |
| D-003 | **LOCKED** | Preserve frozen original `AM-ARCH-1.0` architecture and its 6 domain / 46 module registry | No update to old module rows |
| D-004 | **LOCKED** | Aviation content starts from the nucleus: why each role exists and how all jobs/systems interact | Knowledge Core + common foundation |
| D-005 | **LOCKED** | Cross-functional and within-specialty interconnectedness is the teaching foundation | Role / systems / economics / safety |
| D-006 | **LOCKED** | Common aviation-industry foundation before specialty-specific learning paths | Three draft foundation courses |
| D-007 | **LOCKED** | English shown by default and is the only visible student/platform language; Arabic retained but hidden | Current Supabase language settings |
| D-008 | **LOCKED** | One Person Record and One Evidence Engine; no duplicate candidate identity | Existing Candidate 360 |
| D-009 | **LOCKED** | Learning quiz, career-fit assessment and approved exam have separate purposes | Scoring and evidence governance |
| D-010 | **LOCKED** | Course publication requires qualified human review; drafts remain invisible as sellable/live courses | Content governance |
| D-011 | **LOCKED** | Do not modify GitHub `main` or merge without explicit project owner review | Draft PR |
| D-012 | **LOCKED** | Keep old website, candidate registration, staff portal and Kids assets until safely migrated | No destructive replacement |
| D-013 | **LOCKED** | Open Day should demonstrate aviation industry interconnectedness, not isolated course promotion | Launch planning |
| D-014 | **APPROVED FOR ORGANIZATION** | Store Master Blueprint metadata as a private, versioned Supabase projection with GitHub as its authoring reference | New `am_blueprint` schema; Draft |
| D-015 | **TO VERIFY** | Identify authoritative deployed public website route (React/Vite vs root index.html) | Deployment audit |
| D-016 | **TO VERIFY** | Resolve root `app.js` legacy RPC calls denied by current DB grants | Compatibility and security audit |
| D-017 | **G1A PASS / G1B PASS / G1C BLOCKED** | 39 later versions accounted for: 36 exact archives, 2 GitHub source matches, 1 sensitive helper withheld. Free isolated Supabase replay executed all 119+33 lasting SQL scripts; 14 structural parity gaps remain in assessment/staging/public; content restore not done. | [Free audit report](FREE_REBUILD_EXECUTION_REPORT.md) and [SHA-256 ledger](migration-ledger-2026-10-25.json) |
| D-018 | **IMPLEMENTED ON DRAFT BRANCH / NOT YET RELEASED** | `scripts/post-merge.sh` no longer pushes DB and has offline CI guard; current `main` still requires reviewed merge | Deploy safety |
| D-019 | **TO VERIFY** | Map Supabase Auth application identity into activated candidate record and student identity | Identity bridge gate |
| D-020 | **PROPOSED** | Integrate student UI into existing academy/candidate experience instead of launching a duplicate portal | Requires design review |
| D-021 | **PROPOSED** | Use English-first grayscale documentation and 21 A4 landscape independent printed diagrams as navigation baseline | This branch, pending review |

**Governance:** A decision moves from TO VERIFY/PROPOSED to LOCKED only after an explicit sign-off; this file should be updated in the same Pull Request as its implementation. Do not call planned features live without tests.
