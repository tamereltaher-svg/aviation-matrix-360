# Supabase Reproducibility Baseline

Canonical production freeze for Command 2 fresh rebuild verification.

- Production project: AviationMatrix-Core
- Canonical migration cutoff: 20260903144840
- Canonical migration count: 119
- Later migrations 20260903150758 and 20260903150959 are temporary HTTP enable/disable operations and are excluded from the canonical baseline.
- Production-bound identity seeds are intentionally omitted from replay:
  - 20260822113953: store_admins seed
  - 20260822122643: staff_accounts/staff_permissions seed
- No production staff/store-admin identity is permitted in the isolated rebuild.
- Replay files under `replay/` must be executed in numeric order.

Expected frozen structural contract before isolated rebuild comparison:
- tables: 343
- views: 30
- functions: 195
- constraints: 1737
- indexes: 814
- triggers: 66
- policies: 38
- RLS-enabled tables: 343

Command 2 may pass only after a zero-state isolated rebuild, Edge Function deployment, full contract comparison, temporary project pause, and successful restoration of Exit-Platform to ACTIVE_HEALTHY.
