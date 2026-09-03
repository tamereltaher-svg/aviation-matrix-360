# Sanitized Migration Replay

Canonical replay source is the ordered production migration history frozen at `20260903144840` (`runtime_gate_remove_temporary_http_extension`), 119 migrations total.

Sanitization rules:
- omit the production `store_admins` seed;
- omit the production `staff_accounts` and corresponding `staff_permissions` seed;
- omit the runtime-fixture cleanup migration body (`20260903133953`) because a zero-data rebuild has no runtime fixtures;
- preserve required reference/catalog seeds and all schema/security DDL;
- preserve the final migration that removes the temporary `http` runtime-test extension;
- never include Auth users, sessions, raw tokens, credentials, service-role secrets, or production contact identifiers.

Replay chunks are Base64-encoded UTF-8 SQL and must be decoded and applied in numeric order with `ON_ERROR_STOP` enabled. `replay-manifest.json` contains the expected SHA-256 of each decoded chunk.

The catalog/security manifests under `supabase/baseline/verification` are the authoritative comparison targets after replay. PASS requires an isolated rebuild from zero; successful export alone is not PASS.
