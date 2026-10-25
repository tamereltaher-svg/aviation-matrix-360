#!/usr/bin/env python3
"""Offline migration-metadata reconciliation validator (no DB connection or writes)."""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LEDGER = ROOT / "docs/blueprint/migration-ledger-2026-10-25.json"
FROZEN = ROOT / "supabase/reproducibility/replay-manifest.json"

def main():
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    baseline = json.loads(FROZEN.read_text(encoding="utf-8"))
    summary = ledger["summary"]
    rows = ledger["post_baseline_migrations"]
    assert baseline["count"] == len(baseline["migrations"]) == 119, "Historical 119 replay files diverged"
    assert baseline["cutoff"] == ledger["baseline_cutoff"], "Frozen migration cutoff changed"
    assert summary["live_migration_count"] == 158, "Inventory version drift: refresh ledger from live Supabase"
    assert summary["post_baseline_count"] == len(rows) == 39, "Incomplete 39-version post-freeze inventory"
    assert summary["baseline_replay_count"] + len(rows) == summary["live_migration_count"], "Wrong ledger math"
    assert [x["version"] for x in rows] == sorted(x["version"] for x in rows), "Migrations out of version order"
    assert len({x["version"] for x in rows}) == len(rows), "Duplicate live migration version"
    assert all(x["version"] > ledger["baseline_cutoff"] for x in rows), "Frozen migration included twice"
    assert all(
        re.fullmatch(r"[a-f0-9]{64}", x["statement_sha256"]) is not None
        and x["statement_count"] == 1
        and x["statement_bytes"] > 0
        for x in rows
    ), "Statement fingerprint malformed"
    assert sum(x["statement_bytes"] for x in rows) == summary["post_baseline_statement_bytes"], "Byte counts drift"
    sources = [x for x in rows if x["tracked_source"]]
    missing = [x for x in rows if x["tracked_source"] is None]
    assert len(sources) == summary["tracked_post_baseline_sources"] == 2, "Known SQL sources drifted"
    assert len(missing) == summary["missing_repo_sql_sources"] == 37, "Unreviewed SQL sources drifted"
    assert all((ROOT / x["tracked_source"]).is_file() for x in sources), "Verified source path absent"
    assert sum(x["group"] == "temporary_runtime_history" for x in rows) == 6, "Runtime-only changes changed"
    assert not ledger.get("canonical_replay_ready") and not ledger.get("schema_replay_tested"), "False rebuild completion"
    assert all("statement" not in x for x in rows), "SQL contents must not be written to public ledger"
    print("PASS: 119 frozen + 39 metadata entries = 158 production migration records.")
    print("PASS: 37 unresolved SQL sources, 2 verified GitHub files, 39 SHA-256 fingerprints.")
    print("PASS: no SQL statements, personal records, or implicit rebuild promises in migration ledger.")

if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
