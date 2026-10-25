#!/usr/bin/env python3
"""Zero-cost, isolated Supabase migration replay in GitHub Actions.

Reads migration files from this repository only. Sends SQL over stdin to a
disposable Docker container started by 'supabase start' in a separate
temporary project directory. Never connects to production.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASELINE = ROOT / "supabase/reproducibility/replay-manifest.json"
LEDGER = ROOT / "docs/blueprint/migration-ledger-2026-10-25.json"

def file_with_hash(relative_path: str, expected_sha: str) -> bytes:
    path = ROOT / relative_path
    if not path.resolve().is_relative_to(ROOT.resolve()):
        raise ValueError("File path escapes checked-out repository")
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != expected_sha:
        raise ValueError(f"SHA-256 mismatch: {relative_path}")
    return data

def plan():
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    if baseline["count"] != 119 or len(baseline["migrations"]) != 119:
        raise ValueError("Frozen historical baseline is incomplete")
    if ledger["summary"]["live_migration_count"] != 158 or len(ledger["post_baseline_migrations"]) != 39:
        raise ValueError("Reconciliation ledger does not match validated version snapshot")
    jobs = []
    for x in baseline["migrations"]:
        jobs.append((f"historical:{x['rn']:03d}:{x['version']}", x["path"], x["sha256"]))
    skipped = []
    for x in ledger["post_baseline_migrations"]:
        if x["group"] == "temporary_runtime_history":
            # All 6 are temporary extension or export-helper operations,
            # not durable target schema. Whether this omission is safe is
            # precisely what the isolated rebuild must establish.
            skipped.append((x["version"], x["name"], "temporary_runtime_history"))
            continue
        if not x.get("tracked_source"):
            raise ValueError(f"Missing private migration source outside transient lifecycle: {x['version']}")
        if x["version"] == "20260917141305":
            # Committed main file has a trailing newline not in production.
            # For this one source verify the documented normalized hash.
            path = ROOT / x["tracked_source"]
            raw = path.read_bytes()
            norm = raw.replace(b"\r\n", b"\n").rstrip(b"\r\n")
            if hashlib.sha256(norm).hexdigest() != x["normalized_sql_sha256"]:
                raise ValueError("Normalized hash differs from the production security migration")
            jobs.append((f"later:{x['version']}", x["tracked_source"], None))
        else:
            jobs.append((f"later:{x['version']}", x["tracked_source"], x["statement_sha256"]))
    if len(jobs) != 119 + 33 or len(skipped) != 6:
        raise ValueError(f"Unexpected replay scope: {len(jobs)} files, {len(skipped)} transients")
    return jobs, skipped

def local_db_container() -> str:
    r = subprocess.run(
        ["docker","ps","--format","{{.Names}}"],
        capture_output=True, text=True, check=True, timeout=20,
    )
    # Supabase CLI creates a dockerized local Postgres server with this prefix.
    dbs = [n for n in r.stdout.splitlines() if n.startswith("supabase_db_")]
    if len(dbs) != 1:
        raise RuntimeError(f"Expected one temporary local Supabase DB, found {len(dbs)}")
    return dbs[0]

def query(db_container: str, payload: bytes, timeout=120):
    cmd = ["docker","exec","-i",db_container,"psql",
           "-X","-q","-U","postgres","-d","postgres",
           "-v","ON_ERROR_STOP=1","-v","VERBOSITY=terse"]
    result = subprocess.run(cmd, input=payload, capture_output=True, timeout=timeout)
    if result.returncode != 0:
        reason = result.stderr.decode("utf-8","replace").strip()
        reason = re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "<redacted>", reason)
        reason = re.sub(r"\b[0-9]{14}\b", "<redacted-number>", reason)
        # Only a concise failure diagnostic; never upload production SQL or users.
        raise RuntimeError(reason.splitlines()[0][:400] if reason else "psql returned nonzero status")
    return result.stdout.decode("utf-8","replace").strip()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only",action="store_true",help="verify all source hashes without starting Postgres")
    parser.add_argument("--replay",action="store_true",help="execute ONLY against locally started ephemeral Docker Supabase")
    args = parser.parse_args()
    if args.check_only == args.replay:
        parser.error("Choose exactly one of --check-only or --replay")
    jobs, skipped = plan()
    for label, path, sha in jobs:
        if sha is not None:
            file_with_hash(path, sha)
    print(f"PLAN_OK: 119 frozen + 33 lasting migrations = {len(jobs)} scripts, {len(skipped)} excluded temporary operations", flush=True)
    if args.check_only:
        return
    db = local_db_container()
    probe = query(db,b"select current_database(), to_regclass('auth.users');\n")
    if "auth.users" not in probe:
        raise RuntimeError("Disposable local database lacks Supabase auth bootstrap")
    print("ISOLATED_DB_OK: Supabase local Docker Postgres available; production is not connected", flush=True)
    now = time.monotonic()
    for idx, (label,path,sha) in enumerate(jobs,1):
        script = file_with_hash(path,sha) if sha else (ROOT/path).read_bytes()
        try:
            query(db,script,timeout=160)
        except Exception as exc:
            print(f"FIRST_REPLAY_FAILURE: {idx}/{len(jobs)} {label} {path}", file=sys.stderr,flush=True)
            print(f"FAILURE_DETAIL: {str(exc)[:400]}",file=sys.stderr,flush=True)
            raise SystemExit(1)
        if idx == 119 or idx % 10 == 0:
            print(f"APPLIED: {idx}/{len(jobs)} migrations; current={label}", flush=True)
    check = query(db,b"""
select
 (to_regclass('public.am_platform_modules') is not null)::text || ',' ||
 (to_regclass('avi_knowledge.lesson_versions') is not null)::text || ',' ||
 (to_regclass('public.am_student_auth_bindings') is not null)::text || ',' ||
 (to_regclass('am_blueprint.nodes') is not null)::text as contract;
""")
    if "t,t,t,t" not in check:
        raise RuntimeError("Schema parity smoke checks failed: required objects absent")
    print("PASS: all 119 historical and 33 lasting post-freeze SQL scripts were replayed in disposable local Supabase",flush=True)
    print("PASS: key schema families exist; data/content parity and production release remain separately unverified",flush=True)
    print(f"NOTE: elapsed local test seconds = {round(time.monotonic()-now)}",flush=True)

if __name__=="__main__":
    try:
        main()
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"REBUILD_BLOCKED: {str(exc)[:440]}",file=sys.stderr)
        sys.exit(1)
