#!/usr/bin/env python3
"""Zero-cost, isolated Supabase migration replay in GitHub Actions.

Reads migration files from this repository only. Sends SQL over stdin to a
disposable Docker container started by 'supabase start' in a separate
temporary project directory. Never connects to production.
"""
from __future__ import annotations

import argparse
import base64
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
BOOTSTRAP = ROOT / "docs/blueprint/free-rebuild-bootstrap.json"

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

def historical_bootstrap():
    """Verify the original pinned pre-RN68 and pre-RN90 recovery dependencies.

    These are existing source files already present in the original GitHub
    reproducibility bootstrap folder. No generated placeholder schemas.
    """
    d = json.loads(BOOTSTRAP.read_text(encoding="utf-8"))
    before_68 = []
    for obj in d["before_rn68"]["files"]:
        source = ROOT / obj["path"]
        raw = source.read_bytes()
        actual_blob = hashlib.sha1(
            b"blob " + str(len(raw)).encode("ascii") + bytes([0]) + raw
        ).hexdigest()
        if actual_blob != obj["blob_sha1"]:
            raise ValueError("Historical dependency source changed: " + obj["path"])
        before_68.append((obj["path"], raw))

    supp = json.loads((ROOT / d["before_rn90"]["manifest"]).read_text(encoding="utf-8"))
    if supp["checkpoint"] != 90:
        raise ValueError("Unexpected reviewer supplement checkpoint")
    before_90 = []
    for entry in supp["objects"]:
        parts = [ (ROOT / path).read_text(encoding="utf-8").strip()
                  for path in entry.get("paths", [entry.get("path")]) ]
        raw = base64.b64decode("".join(parts), validate=True)
        if hashlib.sha256(raw).hexdigest() != entry["decoded_sha256"]:
            raise ValueError("Reviewer historical supplement checksum mismatch: " + entry["name"])
        before_90.append((entry["name"],raw))
    if len(before_68) != 5 or len(before_90) != 4:
        raise ValueError("Wrong number of historical reproducibility supplements")
    pre_images = {}
    for checkpoint in (84, 85):
        items = []
        for obj in d[f"before_rn{checkpoint}"]["files"]:
            raw = (ROOT / obj["path"]).read_bytes()
            actual = hashlib.sha1(
                b"blob " + str(len(raw)).encode("ascii") + bytes([0]) + raw
            ).hexdigest()
            if actual != obj["blob_sha1"]:
                raise ValueError("Historic validator pre-image changed: " + obj["path"])
            items.append((obj["path"], raw))
        if len(items) != 1:
            raise ValueError("Expected one original validator pre-image at RN" + str(checkpoint))
        pre_images[checkpoint] = items
    return before_68, pre_images, before_90

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
    before_68, pre_images, before_90 = historical_bootstrap()
    for label, path, sha in jobs:
        if sha is not None:
            file_with_hash(path, sha)
    print(f"PLAN_OK: 119 frozen + 33 lasting migrations = {len(jobs)} scripts; {len(before_68)} pre-RN68, {len(pre_images[84])+len(pre_images[85])} validator pre-images and {len(before_90)} pre-RN90 pinned supplements; {len(skipped)} historical transients excluded", flush=True)
    if args.check_only:
        return
    db = local_db_container()
    probe = query(db,b"select current_database(), to_regclass('auth.users');\n")
    if "auth.users" not in probe:
        raise RuntimeError("Disposable local database lacks Supabase auth bootstrap")
    print("ISOLATED_DB_OK: Supabase local Docker Postgres available; production is not connected", flush=True)
    now = time.monotonic()
    for idx, (label,path,sha) in enumerate(jobs,1):
        if label.startswith("historical:068:"):
            print("APPLY_RECOVERY: pre-RN68 assessment foundations (5 pinned SQL sources)", flush=True)
            for supplement_name,supplement_sql in before_68:
                try:
                    query(db,supplement_sql,timeout=160)
                except Exception as exc:
                    print("BOOTSTRAP_FAILURE: before historical RN68 " + supplement_name, file=sys.stderr)
                    print("FAILURE_DETAIL: " + str(exc)[:400],file=sys.stderr)
                    raise SystemExit(1)
        for checkpoint in (84, 85):
            if label.startswith(f"historical:{checkpoint:03d}:"):
                print(f"APPLY_RECOVERY: original pinned validator pre-image before RN{checkpoint}",flush=True)
                for supplement_name,supplement_sql in pre_images[checkpoint]:
                    try:
                        query(db,supplement_sql,timeout=160)
                    except Exception as exc:
                        print(f"BOOTSTRAP_FAILURE: before RN{checkpoint} " + supplement_name,file=sys.stderr)
                        print("FAILURE_DETAIL: " + str(exc)[:400],file=sys.stderr)
                        raise SystemExit(1)
        if label.startswith("historical:090:"):
            print("APPLY_RECOVERY: pre-RN90 Phase06 review objects (4 SHA-256-verified sources)",flush=True)
            for supplement_name,supplement_sql in before_90:
                try:
                    query(db,supplement_sql,timeout=160)
                except Exception as exc:
                    print("BOOTSTRAP_FAILURE: before historical RN90 " + supplement_name, file=sys.stderr)
                    print("FAILURE_DETAIL: " + str(exc)[:400],file=sys.stderr)
                    raise SystemExit(1)
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
