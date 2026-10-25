#!/usr/bin/env python3
"""Offline, exact source recovery integrity check. Never connects to production."""
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LEDGER = ROOT / "docs/blueprint/migration-ledger-2026-10-25.json"
FROZEN = ROOT / "supabase/reproducibility/replay-manifest.json"
ARCHIVE = ROOT / "supabase/recovered-history"

# Reject accidental publication of credentials/real identifiers in archived SQL.
SENSITIVE = [
    re.compile(rb"sb_secret_[A-Za-z0-9_-]+|sk_live_[A-Za-z0-9_-]+|ghp_[A-Za-z0-9_-]+"),
    re.compile(rb"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(rb"\beyJ[A-Za-z0-9_-]{30,}\b"),
    re.compile(rb"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    re.compile(rb"(?<![0-9])[0-9]{14}(?![0-9])"),
]

def require(ok, message):
    if not ok:
        raise AssertionError(message)

def main():
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    baseline = json.loads(FROZEN.read_text(encoding="utf-8"))
    rows = ledger["post_baseline_migrations"]
    summary = ledger["summary"]
    require(baseline["count"] == len(baseline["migrations"]) == 119, "Historical replay baseline changed")
    require(baseline["cutoff"] == ledger["baseline_cutoff"], "Historical cutoff drift")
    require(summary["live_migration_count"] == 158, "Recorded migration count changed; refresh inventory")
    require(summary["baseline_replay_count"] + len(rows) == 158 and len(rows) == 39,
            "Expected historical 119 + post-baseline 39")
    require([r["version"] for r in rows] == sorted(r["version"] for r in rows),
            "Migration order changed")
    require(len({r["version"] for r in rows}) == 39, "Duplicate version")
    require(all(r["version"] > ledger["baseline_cutoff"] for r in rows),
            "Frozen version included in recovery")
    require(all(re.fullmatch(r"[0-9a-f]{64}", r["statement_sha256"]) for r in rows),
            "Bad SQL SHA-256")
    require(all(r["statement_count"] == 1 and r["statement_bytes"] > 0 for r in rows),
            "Expected one stored SQL statement per version")
    require(sum(r["statement_bytes"] for r in rows) == summary["post_baseline_statement_bytes"],
            "SQL size inventory drift")

    exact_archived, existing_matched, withheld = 0, 0, 0
    expected_paths = set()
    for r in rows:
        path_value = r.get("tracked_source")
        if r["version"] == "20260903171748":
            require(path_value is None and r.get("requires_private_manual_review", False),
                    "Temporary exporter with personal identifiers must never enter public GitHub")
            require(r["public_source_class"] == "withheld_sensitive_historical_admin_identifiers",
                    "Missing quarantine marker for sensitive export function")
            withheld += 1
            continue

        require(path_value, "Unaccounted-for migration source")
        path = ROOT / path_value
        require(path.is_file() and path.is_relative_to(ROOT), "Tracked SQL path missing or outside root")
        data = path.read_bytes()
        require(all(p.search(data) is None for p in SENSITIVE), "Possible identifier/secret in " + path.name)

        if r["public_source_class"] == "archival_not_auto_executable":
            require(path.is_relative_to(ARCHIVE), "Recovered SQL outside non-executable archive")
            target = "transient" if r["group"] == "temporary_runtime_history" else "unverified"
            require(path.parent.name == target, "Transient/unverified source misclassified")
            require(path.name == f"{r['version']}_{r['name']}.sql", "Version-to-filename mismatch")
            require(len(data) == r["statement_bytes"], "SQL byte length changed: " + path.name)
            require(hashlib.sha256(data).hexdigest() == r["statement_sha256"],
                    "SQL does not match Supabase ledger: " + path.name)
            require(not r.get("replay_approved", True), "Recovered historical SQL cannot be auto-approved")
            exact_archived += 1
        elif r["version"] == "20260917141305":
            # Existing GitHub file has a trailing newline not present in stored SQL.
            normalized = data.replace(b"\r\n", b"\n").rstrip(b"\r\n")
            require(hashlib.sha256(normalized).hexdigest() == r["normalized_sql_sha256"],
                    "Existing hardening migration does not match normalized production SQL")
            existing_matched += 1
        elif r["version"] == "20261025125459":
            require(hashlib.sha256(data).hexdigest() == r["statement_sha256"],
                    "Existing Blueprint migration differs from production")
            existing_matched += 1
        else:
            raise AssertionError("Unexpected migration category for " + r["version"])
        expected_paths.add(path.resolve())

    actual_archived = {p.resolve() for p in ARCHIVE.rglob("*.sql")}
    require(actual_archived == {p for p in expected_paths if p.is_relative_to(ARCHIVE.resolve())},
            "Extra or untracked SQL found in recovery archive")
    require(exact_archived == summary["exact_archived_recovered_sources"] == 36, "36 exact recovery count drift")
    require(existing_matched == 2 and withheld == 1, "Missing existing or quarantined migration")
    require(summary["tracked_post_baseline_sources"] == 38 and
            summary["missing_repo_sql_sources"] == 1 and
            summary["intentionally_withheld_sensitive_sources"] == 1,
            "Inventory status does not match recovered sources")
    require(ledger["canonical_replay_ready"] is False and ledger["schema_replay_tested"] is False,
            "Cannot claim complete rebuild before isolated replay")

    print("PASS: 119 frozen + 39 later = 158 recorded Supabase migrations.")
    print("PASS: 36 archived SQL files match production byte-length and SHA-256 exactly.")
    print("PASS: 2 previously committed SQL files match production (one normalized).")
    print("PASS: 1 historical identity-bearing temporary exporter is excluded from public GitHub.")
    print("PASS: no unindexed archive SQL, no public-PII pattern, no false replay certification.")

if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("FAIL:", error, file=sys.stderr)
        raise SystemExit(1)
