#!/usr/bin/env bash
# Aviation Matrix 360 — safe Replit post-merge hook.
# Allowed: restore frozen workspace dependencies only.
# Database schema or data migrations require a separately reviewed change plan,
# an isolated rebuild test, explicit project-owner approval, and a manual rollout.
# NEVER mutate a Supabase database as a side effect of Git pull / merge.
set -euo pipefail

pnpm install --frozen-lockfile

printf '%s\n' 'Aviation Matrix: dependencies restored; database schema and data were NOT modified.'
printf '%s\n' 'Database migrations are manual, separately reviewed operations.'
