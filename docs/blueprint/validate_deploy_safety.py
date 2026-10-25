#!/usr/bin/env python3
"""Fail-closed check: Git checkout/merge must not mutate the production database.

This runs offline in pull-request CI without database credentials.
"""
import pathlib
import shlex
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parents[2]
REPLIT = ROOT / ".replit"
HOOK = ROOT / "scripts/post-merge.sh"
ALLOWED_COMMANDS = {
    ("set", "-euo", "pipefail"),
    ("pnpm", "install", "--frozen-lockfile"),
}
ALLOWED_OUTPUT_PREFIX = "printf"

def main():
    configuration = tomllib.loads(REPLIT.read_text(encoding="utf-8"))
    expected = "scripts/post-merge.sh"
    assert configuration.get("postMerge", {}).get("path") == expected, (
        "Unexpected post-merge hook; review database safety before enabling"
    )

    content = HOOK.read_text(encoding="utf-8")
    assert content.startswith("#!/usr/bin/env bash\n"), "Post-merge must be a Bash script"
    commands = []
    for raw in content.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            parts = shlex.split(line)
        except ValueError as exc:
            raise AssertionError("Invalid hook command quoting") from exc
        assert parts, "Unexpected empty command"
        if parts[0] == ALLOWED_OUTPUT_PREFIX:
            assert len(parts) == 3 and parts[1] == "%s\\n", "Only deterministic status prints allowed"
        else:
            assert tuple(parts) in ALLOWED_COMMANDS, (
                f"Unapproved post-merge command: {parts[0]}"
            )
        commands.append(tuple(parts))

    assert ("pnpm", "install", "--frozen-lockfile") in commands, "Frozen dependency restore missing"
    assert ("set", "-euo", "pipefail") in commands, "Fail-closed Bash mode missing"
    assert len(commands) == 4, "Post-merge command set drifted; explicit review required"

    db_manifest = ROOT / "lib/db/package.json"
    assert db_manifest.is_file(), "Database package cannot be found"
    # The DB package retains its manual scripts; this guard checks that
    # Git merge never invokes them implicitly.
    print("PASS: Replit post-merge only restores frozen dependencies and prints status.")
    print("PASS: No automatic database schema/data operation runs after Git merge.")

if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
