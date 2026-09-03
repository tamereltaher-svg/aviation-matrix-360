# Sanitized Migration Replay

Canonical replay source is the ordered production migration history frozen at `20260903141455` (`p1_harden_direct_public_application_registration`).

Sanitization rules:
- omit production `store_admins` seed;
- omit production `staff_accounts` and corresponding `staff_permissions` seed;
- omit the runtime-fixture cleanup migration body (`20260903133953`) because a zero-data rebuild has no runtime fixtures;
- preserve reference/catalog seeds and all schema/security DDL;
- never include Auth users, sessions, raw tokens, credentials, service-role secrets, or production contact identifiers.

The catalog/security manifests under `supabase/baseline/verification` are the authoritative comparison targets after replay.
