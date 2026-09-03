# Canonical Supabase Baseline

This directory is the sanitized production-derived baseline for `AviationMatrix-Core` captured on 2026-09-03.

Rules:
- Production operational rows, Auth users, staff/application sessions, tokens, secrets and credentials are excluded.
- The temporary `http` extension used for runtime verification is excluded.
- Object definitions are derived from the live PostgreSQL catalogs and live Edge Function sources.
- Security contracts (RLS, policies, relation/function grants and default privileges) are versioned explicitly because Supabase Data API exposure defaults changed in 2026.
- A PASS requires rebuilding a fresh isolated database, applying the baseline, deploying all versioned Edge Functions, and comparing inventory/security contracts against production.

Current production project: `AviationMatrix-Core` (`vsuekfzyebqnhthyvwpf`), PostgreSQL 17.

Do not treat this directory as validated until `verification.json` records `PASS` after a fresh rebuild.
